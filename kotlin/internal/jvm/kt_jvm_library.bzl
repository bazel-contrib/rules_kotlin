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
"""kt_jvm_library rule and implementation."""

load("@rules_java//java:defs.bzl", "JavaInfo")
load("//kotlin/internal:defs.bzl", _KtJvmInfo = "KtJvmInfo")
load("//kotlin/internal/jvm:attrs.bzl", _attrs = "attrs")
load(
    "//kotlin/internal/jvm:common.bzl",
    _make_providers = "make_providers",
    _process_deps = "process_deps",
)
load("//kotlin/internal/jvm:compile.bzl", _compile = "compile")
load(
    "//kotlin/internal/jvm:rule.bzl",
    _COMMON_OUTPUTS = "COMMON_OUTPUTS",
    _COMMON_TOOLCHAINS = "COMMON_TOOLCHAINS",
)
load(
    "//src/main/starlark/core/pipeline:pipeline.bzl",
    _ProviderInfo = "ProviderInfo",
    _processing_pipeline = "processing_pipeline",
)

_ATTRS = _attrs.lib_common_attr

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

def finalize(context):
    """Assemble the kt_jvm_library providers from the accumulated processor results."""
    return _make_providers(
        context.ctx,
        providers = context.outputs["JvmCompileProcessor"],
        runfiles_targets = context.outputs["DepsProcessor"],
    )

PROCESSORS = dict(
    DepsProcessor = _process_deps,
    JvmCompileProcessor = _process_compile,
)

_PROCESSING_PIPELINE = _processing_pipeline.make_processing_pipeline(
    processors = PROCESSORS,
    finalize = finalize,
)

def kt_jvm_library_impl(ctx):
    """Implements the kt_jvm_library rule.

    Args:
        ctx: the rule context providing the library sources and dependencies.

    Returns:
        The list of providers produced by compiling the library.
    """
    if ctx.attr.neverlink and ctx.attr.runtime_deps:
        fail("runtime_deps and neverlink is nonsensical.", attr = "runtime_deps")

    if not ctx.attr.srcs and len(ctx.attr.deps) > 0:
        fail(
            "deps without srcs is invalid." +
            "\nTo add runtime dependencies use runtime_deps." +
            "\nTo export libraries use exports.",
            attr = "deps",
        )
    if not ctx.attr.srcs and not ctx.attr.resources and ctx.attr.manifest_lines:
        fail(
            "manifest_lines without srcs or resources is invalid: the target has no jar of its own.",
            attr = "manifest_lines",
        )
    return _processing_pipeline.run(
        ctx = ctx,
        java_package = None,
        pipeline = _PROCESSING_PIPELINE,
    )

kt_jvm_library = rule(
    doc = """This rule compiles and links Kotlin and Java sources into a .jar file.""",
    attrs = _ATTRS,
    outputs = _COMMON_OUTPUTS,
    toolchains = _COMMON_TOOLCHAINS,
    fragments = ["java"],  # Required fragments of the target configuration
    host_fragments = ["java"],  # Required fragments of the host configuration
    implementation = kt_jvm_library_impl,
    provides = [JavaInfo, _KtJvmInfo],
)
