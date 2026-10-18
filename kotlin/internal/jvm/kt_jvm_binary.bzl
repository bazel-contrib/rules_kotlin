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
"""kt_jvm_binary rule and implementation."""

load("//kotlin/internal/jvm:attrs.bzl", _attrs = "attrs")
load(
    "//kotlin/internal/jvm:common.bzl",
    _expand_env = "expand_env",
    _make_providers = "make_providers",
    _process_deps = "process_deps",
    _write_launcher_action = "write_launcher_action",
)
load("//kotlin/internal/jvm:compile.bzl", _compile = "compile")
load(
    "//kotlin/internal/jvm:rule.bzl",
    _COMMON_OUTPUTS = "COMMON_OUTPUTS",
    _COMMON_TOOLCHAINS = "COMMON_TOOLCHAINS",
    _RUNNABLE_COMMON_TOOLCHAINS = "RUNNABLE_COMMON_TOOLCHAINS",
)
load("//kotlin/internal/utils:utils.bzl", _utils = "utils")
load(
    "//src/main/starlark/core/pipeline:pipeline.bzl",
    _ProviderInfo = "ProviderInfo",
    _processing_pipeline = "processing_pipeline",
)

_ATTRS = _utils.add_dicts(_attrs.runnable_common_attr, {
    "main_class": attr.string(
        doc = """Name of class with main() method to use as entry point.""",
        mandatory = True,
    ),
})

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

def finalize(context):
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

PROCESSORS = dict(
    DepsProcessor = _process_deps,
    JvmCompileProcessor = _process_binary_compile,
    LauncherProcessor = _process_binary_launcher,
)

_PROCESSING_PIPELINE = _processing_pipeline.make_processing_pipeline(
    processors = PROCESSORS,
    finalize = finalize,
)

def kt_jvm_binary_impl(ctx):
    """Implements the kt_jvm_binary rule.

    Args:
        ctx: the rule context providing the binary sources, deps, and main class.

    Returns:
        The list of providers producing the runnable binary.
    """
    if len(ctx.attr.srcs) == 0 and len(ctx.attr.deps) > 0:
        fail("deps without srcs is invalid. To add runtime classpath and resources, use runtime_deps.", attr = "deps")
    return _processing_pipeline.run(
        ctx = ctx,
        java_package = None,
        pipeline = _PROCESSING_PIPELINE,
    )

kt_jvm_binary = rule(
    doc = """\
Builds a Java archive ("jar file"), plus a wrapper shell script with the same name as the rule. The wrapper
shell script uses a classpath that includes, among other things, a jar file for each library on which the binary
depends.

**Note:** This rule does not have all of the features found in [`java_binary`](https://docs.bazel.build/versions/master/be/java.html#java_binary).
It is appropriate for building workspace utilities. `java_binary` should be preferred for release artefacts.
""",
    attrs = _ATTRS,
    executable = True,
    outputs = _COMMON_OUTPUTS,
    toolchains = _COMMON_TOOLCHAINS + _RUNNABLE_COMMON_TOOLCHAINS,
    fragments = ["java"],  # Required fragments of the target configuration
    host_fragments = ["java"],  # Required fragments of the host configuration
    implementation = kt_jvm_binary_impl,
)
