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
"""Analysis tests and a make_rule prototype for custom coverage runtimes."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_android//rules:java.bzl", "java")
load("@rules_android//rules:processing_pipeline.bzl", "ProviderInfo", "processing_pipeline")
load("@rules_android//rules/android_local_test:impl.bzl", "finalize")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")

# buildifier: disable=bzl-visibility
load("//kotlin/internal/jvm:kt_android_local_test.bzl", "make_rule")

# buildifier: disable=bzl-visibility
load("//kotlin/internal/jvm:kt_android_local_test_impl.bzl", "PROCESSORS")

def _custom_coverage(ctx, **sub_ctxs):
    if not ctx.configuration.coverage_enabled:
        return PROCESSORS["CoverageProcessor"](ctx, **sub_ctxs)

    # Analysis-only stand-ins: a real integration obtains the agent from its
    # toolchain and writes the coverage tool's configuration here.
    agent = ctx.actions.declare_file(ctx.label.name + "_agent.jar")
    args = ctx.actions.declare_file(ctx.label.name + "_agent.args")
    ctx.actions.write(agent, "")
    ctx.actions.write(args, "")
    return ProviderInfo(
        name = "coverage_ctx",
        value = struct(
            deps = [],
            java_start_class = ctx.attr.main_class,
            coverage_start_class = None,
            additional_jvm_flags = [
                "-javaagent:%s=file:%s" % (agent.short_path, args.short_path),
                "-Dpipeline.flag=" + ctx.attr.pipeline_flag,
            ],
        ),
        runfiles = ctx.runfiles(files = [agent, args]),
    )

_CUSTOM_PIPELINE = processing_pipeline.make_processing_pipeline(
    processors = processing_pipeline.replace(PROCESSORS, CoverageProcessor = _custom_coverage),
    finalize = finalize,
)

def _custom_impl(ctx):
    java_package = java.resolve_package_from_label(ctx.label, ctx.attr.custom_package)
    return processing_pipeline.run(ctx, java_package, _CUSTOM_PIPELINE)

_custom_android_local_test = make_rule(
    implementation = _custom_impl,
    attrs = {"pipeline_flag": attr.string(default = "retained")},
)
_default_android_local_test = make_rule()

def _coverage_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    asserts.true(env, any([a.mnemonic == "KotlinCompile" for a in analysistest.target_actions(env)]))
    executable = target[DefaultInfo].files_to_run.executable
    actions = [a for a in analysistest.target_actions(env) if executable in a.outputs.to_list()]
    asserts.equals(env, 1, len(actions))
    subs = actions[0].substitutions
    jacoco = ctx.attr.mode == "jacoco"
    agent = ctx.attr.mode == "agent"

    asserts.equals(env, "com.google.testing.coverage.JacocoCoverageRunner" if jacoco else "com.example.CustomRunner", subs["%java_start_class%"])
    asserts.equals(env, jacoco, bool(subs["%set_jacoco_metadata%"]))
    asserts.equals(env, "export JACOCO_MAIN_CLASS=com.example.CustomRunner" if jacoco else "", subs["%set_jacoco_main_class%"])
    asserts.equals(env, jacoco, bool(subs["%set_jacoco_java_runfiles_root%"]))
    asserts.equals(env, agent, "-javaagent:" in subs["%jvm_flags%"])
    asserts.equals(env, agent, "-Dpipeline.flag=retained" in subs["%jvm_flags%"])
    asserts.true(env, "-Dbazel.test_suite=com.example.ExampleTest" in subs["%jvm_flags%"])
    asserts.true(env, "-Drobolectric.offline=true" in subs["%jvm_flags%"])
    asserts.true(env, "-Duser.flag=retained" in subs["%jvm_flags%"])

    runtime_jars = target[JavaInfo].transitive_runtime_jars.to_list()
    asserts.equals(env, jacoco, any(["jacoco" in f.basename.lower() for f in runtime_jars]))
    runfiles = target[DefaultInfo].default_runfiles.files.to_list()
    agent_files = [f for f in runfiles if f.basename.endswith(("_agent.jar", "_agent.args"))]
    asserts.equals(env, 2 if agent else 0, len(agent_files))
    for f in agent_files:
        asserts.true(env, f.short_path in subs["%jvm_flags%"])
    asserts.true(env, any([f.basename == target.label.name + "_deploy.jar" for f in runfiles]))
    if jacoco:
        asserts.true(env, target.label.name + "_deploy.jar" in subs["%set_jacoco_metadata%"])
    return analysistest.end(env)

_coverage_test = analysistest.make(
    _coverage_test_impl,
    config_settings = {"//command_line_option:collect_code_coverage": True},
    attrs = {"mode": attr.string()},
)
_no_coverage_test = analysistest.make(
    _coverage_test_impl,
    config_settings = {"//command_line_option:collect_code_coverage": False},
    attrs = {"mode": attr.string(default = "off")},
)

def coverage_test_suite(name):
    """Checks default JaCoCo, custom agent, and coverage-disabled launchers.

    Args:
      name: Name of the test suite.
    """
    tests = []
    for variant, test_rule in [("default", _default_android_local_test), ("custom", _custom_android_local_test)]:
        subject = name + "_" + variant + "_subject"
        test_rule(
            name = subject,
            srcs = ["ExampleTest.kt"],
            custom_package = "com.example",
            main_class = "com.example.CustomRunner",
            test_class = "com.example.ExampleTest",
            jvm_flags = ["-Duser.flag=retained"],
            tags = ["manual"],
        )
        _coverage_test(
            name = name + "_" + variant,
            target_under_test = ":" + subject,
            mode = "jacoco" if variant == "default" else "agent",
        )
        _no_coverage_test(
            name = name + "_" + variant + "_off",
            target_under_test = ":" + subject,
        )
        tests.extend([":" + name + "_" + variant, ":" + name + "_" + variant + "_off"])
    native.test_suite(name = name, tests = tests)
