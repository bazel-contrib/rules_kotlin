# Copyright 2026 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Checks the real Kover processor without replacing the JVM or stub processors."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("//kotlin:android.bzl", "kt_android_local_test")
load("//kotlin:jvm.bzl", "kt_jvm_test")

_TOOLCHAIN = "//src/test/starlark/android_local_test:kover_toolchain"

def _test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    actions = analysistest.target_actions(env)
    executable = target[DefaultInfo].files_to_run.executable
    launcher = [a for a in actions if executable in a.outputs.to_list()][0]
    subs = launcher.substitutions
    enabled = ctx.attr.enabled
    asserts.equals(env, "com.google.testing.junit.runner.BazelTestRunner", subs["%java_start_class%"])
    asserts.equals(env, "", subs["%set_jacoco_main_class%"])
    asserts.equals(env, "", subs["%set_jacoco_metadata%"])
    asserts.equals(env, enabled, "-javaagent:" in subs["%jvm_flags%"])
    asserts.equals(env, enabled, "-Xbootclasspath/a:" in subs["%jvm_flags%"])
    asserts.true(env, "-Duser.flag=retained" in subs["%jvm_flags%"])
    if ctx.attr.android:
        asserts.true(env, "-Djava.security.manager=allow" in subs["%jvm_flags%"])
    compile = [a for a in actions if a.mnemonic == "KotlinCompile"][0]
    args = compile.argv
    asserts.equals(env, "false", args[args.index("--instrument_coverage") + 1])
    asserts.false(env, any(["jacoco" in f.basename.lower() for f in target[JavaInfo].transitive_runtime_jars.to_list()]))
    runfiles = target[DefaultInfo].default_runfiles.files.to_list()
    files = [f for f in runfiles if f.basename.endswith(("-kover.args.txt", "-kover_metadata.txt", "kover-jvm-agent-0.8.3.jar"))]
    asserts.equals(env, 3 if enabled else 0, len(files))
    if enabled:
        agent_args = [a for a in actions if any([f.basename.endswith("-kover.args.txt") for f in a.outputs.to_list()])][0]
        asserts.true(env, "report.file=" in agent_args.content)
        for f in files:
            if not f.basename.endswith("-kover_metadata.txt"):
                asserts.true(env, f.short_path in subs["%jvm_flags%"])
    return analysistest.end(env)

_enabled_test = analysistest.make(
    _test_impl,
    config_settings = {
        "//command_line_option:collect_code_coverage": True,
        "//command_line_option:extra_toolchains": [_TOOLCHAIN],
        "//command_line_option:instrumentation_filter": "//src/test/starlark/android_local_test",
        "//command_line_option:instrument_test_targets": True,
    },
    attrs = {"enabled": attr.bool(default = True), "android": attr.bool(default = True)},
)
_disabled_test = analysistest.make(
    _test_impl,
    config_settings = {
        "//command_line_option:collect_code_coverage": False,
        "//command_line_option:extra_toolchains": [_TOOLCHAIN],
    },
    attrs = {"enabled": attr.bool(default = False), "android": attr.bool(default = True)},
)

def kover_pipeline_test_suite(name):
    """Tests Kover under coverage and the normal runner when coverage is disabled.

    Args:
        name: Name of the test suite.
    """
    subject = name + "_subject"
    kt_android_local_test(
        name = subject,
        srcs = ["ExampleTest.kt"],
        custom_package = "com.example",
        test_class = "com.example.ExampleTest",
        jvm_flags = ["-Duser.flag=retained"],
        tags = ["manual"],
    )
    _enabled_test(name = name + "_enabled", target_under_test = ":" + subject)
    _disabled_test(name = name + "_disabled", target_under_test = ":" + subject)
    kt_jvm_test(
        name = subject + "_jvm",
        srcs = ["ExampleTest.kt"],
        test_class = "com.example.ExampleTest",
        jvm_flags = ["-Duser.flag=retained"],
        tags = ["manual"],
    )

    # The JVM launcher uses a native executable on Windows, not substitutions.
    jvm_compatibility = select({
        "@platforms//os:windows": ["@platforms//:incompatible"],
        "//conditions:default": [],
    })
    _enabled_test(target_compatible_with = jvm_compatibility, name = name + "_jvm_enabled", target_under_test = ":" + subject + "_jvm", android = False)
    _disabled_test(target_compatible_with = jvm_compatibility, name = name + "_jvm_disabled", target_under_test = ":" + subject + "_jvm", android = False)
    native.test_suite(name = name, tests = [name + suffix for suffix in ["_enabled", "_disabled", "_jvm_enabled", "_jvm_disabled"]])
