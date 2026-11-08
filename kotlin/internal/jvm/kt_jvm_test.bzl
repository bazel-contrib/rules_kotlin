# Copyright 2018 The Bazel Authors. All rights reserved.
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
"""kt_jvm_test rule and implementation."""

load("//kotlin/internal:defs.bzl", _TOOLCHAIN_TYPE = "TOOLCHAIN_TYPE")
load("//kotlin/internal/jvm:attrs.bzl", _attrs = "attrs")
load(
    "//kotlin/internal/jvm:common.bzl",
    _expand_env = "expand_env",
    _infer_test_class = "infer_test_class",
    _make_providers = "make_providers",
    _process_deps = "process_deps",
    _write_launcher_action = "write_launcher_action",
)
load("//kotlin/internal/jvm:compile.bzl", _compile = "compile")
load(
    "//kotlin/internal/jvm:kover.bzl",
    _create_kover_agent_files = "create_kover_agent_files",
    _create_kover_lcov_launcher = "create_kover_lcov_launcher",
    _get_kover_agent_file = "get_kover_agent_file",
    _get_kover_jvm_flags = "get_kover_jvm_flags",
    _is_kover_enabled = "is_kover_enabled",
)
load(
    "//kotlin/internal/jvm:rule.bzl",
    _COMMON_OUTPUTS = "COMMON_OUTPUTS",
    _COMMON_TOOLCHAINS = "COMMON_TOOLCHAINS",
    _RUNNABLE_COMMON_TOOLCHAINS = "RUNNABLE_COMMON_TOOLCHAINS",
)
load("//kotlin/internal/utils:utils.bzl", _utils = "utils")
load("//src/main/starlark/core/compile:common.bzl", "is_windows")
load(
    "//src/main/starlark/core/pipeline:pipeline.bzl",
    _ProviderInfo = "ProviderInfo",
    _processing_pipeline = "processing_pipeline",
)

_ATTRS = _utils.add_dicts(_attrs.runnable_common_attr, {
    "env": attr.string_dict(
        doc = "Specifies additional environment variables to set when the target is executed by bazel test. Subject to $(location) and \"Make variable\" substitution.",
        default = {},
    ),
    "env_inherit": attr.string_list(
        doc = "Environment variables to inherit from the external environment.",
    ),
    "main_class": attr.string(default = "com.google.testing.junit.runner.BazelTestRunner"),
    "test_class": attr.string(
        doc = "The Java class to be loaded by the test runner.",
        default = "",
    ),
    "_bazel_test_runner": attr.label(
        default = Label("@bazel_tools//tools/jdk:TestRunner_deploy.jar"),
        allow_files = True,
    ),
    "_kover_lcov_template": attr.label(
        default = Label("//kotlin/internal/jvm:kover_lcov.sh.tpl"),
        allow_single_file = True,
    ),
    "_lcov_merger": attr.label(
        default = Label("@bazel_tools//tools/test/CoverageOutputGenerator/java/com/google/devtools/coverageoutputgenerator:Main"),
    ),
})

def _process_test_compile(context):
    """Run the JVM compile engine for the test with rule_kind "kt_jvm_test"."""
    ctx = context.ctx
    return _ProviderInfo(
        name = "JvmCompileProcessor",
        value = _compile.kt_jvm_produce_jar_actions(ctx, "kt_jvm_test"),
        runfiles = None,
    )

def _process_test_launcher(context):
    """Build the coverage-instrumented test launcher and collect its runfiles."""
    ctx = context.ctx
    providers = context.outputs["JvmCompileProcessor"]

    coverage_runfiles = depset()
    coverage_inputs = []
    coverage_jvm_flags = []
    child = None

    if ctx.configuration.coverage_enabled:
        if _is_kover_enabled(ctx) and ctx.toolchains[_TOOLCHAIN_TYPE].experimental_kover_cli:
            if is_windows(ctx):
                fail("Kover LCOV reporting currently requires a Unix JVM test launcher")
            child, coverage_runfiles = _create_kover_lcov_launcher(ctx, providers)
        elif _is_kover_enabled(ctx):
            kover_agent_file = _get_kover_agent_file(ctx)
            kover_args_file, coverage_runfiles = _create_kover_agent_files(
                ctx,
                ctx.attr.deps + ctx.attr.associates,
            )
            flags = _get_kover_jvm_flags(kover_agent_file, kover_args_file)

            # add Kover agent jvm_flag, inputs and outputs
            coverage_jvm_flags = flags
            coverage_inputs = [depset([kover_agent_file])]
        else:
            jacocorunner = ctx.toolchains[_TOOLCHAIN_TYPE].jacocorunner
            coverage_runfiles = jacocorunner.files

    test_class = _infer_test_class(ctx)

    jvm_flags = []
    if hasattr(ctx.fragments.java, "default_jvm_opts"):
        jvm_flags = ctx.fragments.java.default_jvm_opts

    jvm_flags.extend(coverage_jvm_flags + ctx.attr.jvm_flags)

    runtime_jars = depset(
        ctx.files._bazel_test_runner,
        transitive = [providers.java.transitive_runtime_jars] + coverage_inputs,
    )

    launcher_result = _write_launcher_action(
        ctx,
        runtime_jars,
        main_class = ctx.attr.main_class,
        jvm_flags = [
            "-ea",
            "-Dbazel.test_suite=%s" % test_class,
        ] + jvm_flags,
        is_test = True,
        unix_executable = child,
    )

    # Get java runtime files from toolchain for runfiles (needed for Windows launcher)
    java_runtime = ctx.toolchains["@bazel_tools//tools/jdk:runtime_toolchain_type"].java_runtime

    return _ProviderInfo(
        name = "TestLauncherProcessor",
        value = struct(
            executable = launcher_result.executable,
            transitive_files = depset(
                order = "default",
                transitive = [runtime_jars, coverage_runfiles, depset(launcher_result.coverage_metadata), java_runtime.files],
            ),
        ),
        runfiles = None,
    )

def finalize(context):
    """Assemble the kt_jvm_test providers: DefaultInfo with the launcher plus TestEnvironment."""
    ctx = context.ctx
    launcher = context.outputs["TestLauncherProcessor"]
    return _make_providers(
        ctx,
        context.outputs["JvmCompileProcessor"],
        context.outputs["DepsProcessor"],
        launcher.transitive_files,
        launcher.executable,
        # adds common test variables, including TEST_WORKSPACE.
        testing.TestEnvironment(environment = _expand_env(ctx), inherited_environment = ctx.attr.env_inherit),
    )

PROCESSORS = dict(
    DepsProcessor = _process_deps,
    JvmCompileProcessor = _process_test_compile,
    TestLauncherProcessor = _process_test_launcher,
)

_PROCESSING_PIPELINE = _processing_pipeline.make_processing_pipeline(
    processors = PROCESSORS,
    finalize = finalize,
)

def kt_jvm_test_impl(ctx):
    """Implements the kt_jvm_test rule for JUnit tests.

    Args:
        ctx: the rule context providing the test sources, deps, and test runner.

    Returns:
        The list of providers producing the runnable JUnit test.
    """
    return _processing_pipeline.run(
        ctx = ctx,
        java_package = None,
        pipeline = _PROCESSING_PIPELINE,
    )

kt_jvm_test = rule(
    doc = """\
Setup a simple kotlin_test.

**Notes:**
* The kotlin test library is not added implicitly, it is available with the label
`@rules_kotlin//kotlin/compiler:kotlin-test`.
""",
    attrs = _ATTRS,
    executable = True,
    outputs = _COMMON_OUTPUTS,
    test = True,
    toolchains = _COMMON_TOOLCHAINS + _RUNNABLE_COMMON_TOOLCHAINS,
    implementation = kt_jvm_test_impl,
    fragments = ["java"],  # Required fragments of the target configuration
    host_fragments = ["java"],  # Required fragments of the host configuration
)
