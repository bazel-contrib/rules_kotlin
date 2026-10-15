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
"""Statically-defined processing pipelines for the Kotlin/JVM rules.

Downstream rules compose a chain with `processing_pipeline.{prepend,append,replace}`.
"""

load(
    "//kotlin/internal:defs.bzl",
    _TOOLCHAIN_TYPE = "TOOLCHAIN_TYPE",
)
load(
    "//kotlin/internal/jvm:common.bzl",
    _expand_env = "expand_env",
    _infer_test_class = "infer_test_class",
    _make_providers = "make_providers",
    _write_launcher_action = "write_launcher_action",
)
load(
    "//kotlin/internal/jvm:compile.bzl",
    _compile = "compile",
)
load(
    "//src/main/starlark/core/pipeline:pipeline.bzl",
    _ProviderInfo = "ProviderInfo",
    _processing_pipeline = "processing_pipeline",
)

def _process_deps(context):
    """Collect the deps, exports, runtime_deps and data targets that contribute runfiles."""
    ctx = context.ctx
    return _ProviderInfo(
        name = "DepsProcessor",
        value = ctx.attr.deps + getattr(ctx.attr, "exports", []) + ctx.attr.runtime_deps + ctx.attr.data,
        runfiles = None,
    )

def _process_compile(context):
    """Run the JVM compile engine for the library, or emit export-only providers when it has no jar."""
    ctx = context.ctx
    providers = _compile.kt_jvm_produce_jar_actions(ctx, "kt_jvm_library") if ctx.attr.srcs or ctx.attr.resources else _compile.export_only_providers(
        ctx = ctx,
        actions = ctx.actions,
        outputs = ctx.outputs,
        attr = ctx.attr,
    )
    return _ProviderInfo(
        name = "JvmCompileProcessor",
        value = providers,
        runfiles = None,
    )

def finalize_library(context):
    """Assemble the kt_jvm_library providers from the accumulated processor results."""
    return _make_providers(
        context.ctx,
        providers = context.outputs["JvmCompileProcessor"],
        runfiles_targets = context.outputs["DepsProcessor"],
    )

def _process_binary_compile(context):
    """Run the JVM compile engine for the binary with rule_kind "kt_jvm_binary"."""
    ctx = context.ctx
    return _ProviderInfo(
        name = "JvmCompileProcessor",
        value = _compile.kt_jvm_produce_jar_actions(ctx, "kt_jvm_binary"),
        runfiles = None,
    )

def _process_binary_launcher(context):
    """Build the binary launcher and collect its executable and runtime-jar runfiles."""
    ctx = context.ctx
    providers = context.outputs["JvmCompileProcessor"]
    jvm_flags = []
    if hasattr(ctx.fragments.java, "default_jvm_opts"):
        jvm_flags = ctx.fragments.java.default_jvm_opts
    jvm_flags.extend(ctx.attr.jvm_flags)
    launcher_result = _write_launcher_action(
        ctx,
        providers.java.transitive_runtime_jars,
        ctx.attr.main_class,
        jvm_flags,
    )

    # Java runtime files are needed in runfiles for the (Windows) launcher.
    java_runtime = ctx.toolchains["@bazel_tools//tools/jdk:runtime_toolchain_type"].java_runtime
    return _ProviderInfo(
        name = "LauncherProcessor",
        value = struct(
            executable = launcher_result.executable,
            transitive_files = depset(
                order = "default",
                transitive = [providers.java.transitive_runtime_jars, java_runtime.files],
            ),
        ),
        runfiles = None,
    )

def finalize_binary(context):
    """Assemble the kt_jvm_binary providers: DefaultInfo with the launcher plus RunEnvironmentInfo."""
    ctx = context.ctx
    launcher = context.outputs["LauncherProcessor"]
    return _make_providers(
        ctx,
        context.outputs["JvmCompileProcessor"],
        context.outputs["DepsProcessor"],
        launcher.transitive_files,
        launcher.executable,
        RunEnvironmentInfo(
            environment = _expand_env(ctx),
            inherited_environment = ctx.attr.env_inherit,
        ),
    )

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
    runtime_jars = depset(ctx.files._bazel_test_runner, transitive = [providers.java.transitive_runtime_jars])

    coverage_runfiles = []
    if ctx.configuration.coverage_enabled:
        jacocorunner = ctx.toolchains[_TOOLCHAIN_TYPE].jacocorunner
        coverage_runfiles = jacocorunner.files.to_list()

    test_class = _infer_test_class(ctx)

    jvm_flags = []
    if hasattr(ctx.fragments.java, "default_jvm_opts"):
        jvm_flags = ctx.fragments.java.default_jvm_opts

    jvm_flags.extend(ctx.attr.jvm_flags)
    launcher_result = _write_launcher_action(
        ctx,
        runtime_jars,
        main_class = ctx.attr.main_class,
        jvm_flags = [
            "-ea",
            "-Dbazel.test_suite=%s" % test_class,
        ] + jvm_flags,
        is_test = True,
    )

    # Get java runtime files from toolchain for runfiles (needed for Windows launcher)
    java_runtime = ctx.toolchains["@bazel_tools//tools/jdk:runtime_toolchain_type"].java_runtime

    return _ProviderInfo(
        name = "TestLauncherProcessor",
        value = struct(
            executable = launcher_result.executable,
            transitive_files = depset(
                order = "default",
                transitive = [runtime_jars, depset(coverage_runfiles), depset(launcher_result.coverage_metadata), java_runtime.files],
            ),
        ),
        runfiles = None,
    )

def finalize_test(context):
    """Assemble the kt_jvm_junit_test providers: DefaultInfo with the launcher plus TestEnvironment."""
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

LIBRARY_PROCESSORS = dict(
    DepsProcessor = _process_deps,
    JvmCompileProcessor = _process_compile,
)

LIBRARY_PROCESSING_PIPELINE = _processing_pipeline.make_processing_pipeline(
    processors = LIBRARY_PROCESSORS,
    finalize = finalize_library,
)

BINARY_PROCESSORS = dict(
    DepsProcessor = _process_deps,
    JvmCompileProcessor = _process_binary_compile,
    LauncherProcessor = _process_binary_launcher,
)

BINARY_PROCESSING_PIPELINE = _processing_pipeline.make_processing_pipeline(
    processors = BINARY_PROCESSORS,
    finalize = finalize_binary,
)

TEST_PROCESSORS = dict(
    DepsProcessor = _process_deps,
    JvmCompileProcessor = _process_test_compile,
    TestLauncherProcessor = _process_test_launcher,
)

TEST_PROCESSING_PIPELINE = _processing_pipeline.make_processing_pipeline(
    processors = TEST_PROCESSORS,
    finalize = finalize_test,
)
