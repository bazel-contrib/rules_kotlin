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
load(
    "@rules_android//providers:providers.bzl",
    _AndroidLibraryResourceClassJarProvider = "AndroidLibraryResourceClassJarProvider",
)
load(
    "@rules_android//rules:java.bzl",
    _java = "java",
)
load(
    "@rules_android//rules:processing_pipeline.bzl",
    _ProviderInfo = "ProviderInfo",
    _processing_pipeline = "processing_pipeline",
)
load(
    "@rules_android//rules:utils.bzl",
    _get_android_sdk = "get_android_sdk",
    _utils = "utils",
)
load(
    "@rules_android//rules/android_library:impl.bzl",
    _BASE_PROCESSORS = "PROCESSORS",
    _finalize = "finalize",
)
load(
    "@rules_java//java:defs.bzl",
    "JavaInfo",
)
load(
    "//kotlin/internal/jvm:compile.bzl",
    _compile = "compile",
)
load(
    "//kotlin/internal/jvm:jvm_deps.bzl",
    _jvm_deps_utils = "jvm_deps_utils",
)

def _process_jvm(ctx, resources_ctx, **_unused_sub_ctxs):
    """Custom JvmProcessor that handles Kotlin compilation
    """
    r_java = resources_ctx.r_java
    outputs = struct(jar = ctx.outputs.lib_jar, srcjar = ctx.outputs.lib_src_jar, deploy_jar = None)
    providers = _kt_android_produce_jar_actions(ctx, "kt_android_library", outputs, r_java)

    return _ProviderInfo(
        name = "jvm_ctx",
        value = struct(
            java_info = providers.java,
            kt_info = providers.kt,
            providers = [
                providers.kt,
                providers.java,
            ],
        ),
    )

PROCESSORS = _processing_pipeline.replace(
    _BASE_PROCESSORS,
    JvmProcessor = _process_jvm,
)

_PROCESSING_PIPELINE = _processing_pipeline.make_processing_pipeline(
    processors = PROCESSORS,
    finalize = _finalize,
)

def kt_android_library_impl(ctx):
    """The rule implementation.

    Args:
      ctx: The context.

    Returns:
      A list of providers.
    """
    java_package = _java.resolve_package_from_label(ctx.label, ctx.attr.custom_package)
    return _processing_pipeline.run(ctx, java_package, _PROCESSING_PIPELINE)

def _get_android_resource_class_jars(targets):
    # Each dep's `.jars` is already a *transitive* R.class jar depset, and these
    # depsets overlap heavily across deps (shared base/framework R.jars). The old
    # code flattened every dep's depset separately via list_or_depset_to_list and
    # wrapped each element in a JavaInfo, re-materializing the shared closure once
    # per dep -- O(N^2) work that dominated kt_android_library analysis time.
    #
    # Merge into a single depset first (cheap, lazy, deduped) and flatten ONCE, so
    # we create one JavaInfo per *unique* R.jar. The compile classpath is a set
    # downstream (jvm_deps re-collects into a depset), so dedup is semantics-safe.
    jar_depsets = [
        d[_AndroidLibraryResourceClassJarProvider].jars
        for d in targets
        if _AndroidLibraryResourceClassJarProvider in d
    ]
    if not jar_depsets:
        return []

    return [
        JavaInfo(output_jar = jar, compile_jar = jar, neverlink = True)
        for jar in depset(transitive = jar_depsets).to_list()
    ]

def _kt_android_produce_jar_actions(
        ctx,
        rule_kind,
        outputs,
        rClass = None,
        extra_resources = {}):
    """Setup The actions to compile a jar and if any resources or resource_jars were provided to merge these in with the
    compilation output.
    """
    deps = getattr(ctx.attr, "deps", [])
    associates = getattr(ctx.attr, "associates", [])
    exports = getattr(ctx.attr, "exports", [])
    runtime_deps = getattr(ctx.attr, "runtime_deps", [])
    _compile.verify_associates_not_duplicated_in_deps(deps = deps, associate_deps = associates)

    # Collect the android compile dependencies
    android_java_infos = [
        JavaInfo(
            output_jar = _get_android_sdk(ctx).android_jar,
            compile_jar = _get_android_sdk(ctx).android_jar,
            neverlink = True,
        ),
    ]
    if rClass:
        android_java_infos.append(rClass)
    android_java_infos.extend(_get_android_resource_class_jars(deps + associates + runtime_deps))

    compile_deps = _jvm_deps_utils.jvm_deps(
        ctx,
        toolchains = _compile.compiler_toolchains(ctx),
        associate_deps = associates,
        deps = deps,
        deps_java_infos = android_java_infos,
        exports = exports,
        runtime_deps = runtime_deps,
    )

    # Setup the compile action.
    return _compile.kt_jvm_produce_output_jar_actions(
        ctx,
        rule_kind = rule_kind,
        compile_deps = compile_deps,
        outputs = outputs,
        extra_resources = extra_resources,
    ) if ctx.attr.srcs else _compile.export_only_providers(
        ctx = ctx,
        actions = ctx.actions,
        outputs = outputs,
        attr = ctx.attr,
    )
