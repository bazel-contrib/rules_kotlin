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
"""Implementation of kt_android_local_test rule."""

load(
    "@bazel_skylib//rules:common_settings.bzl",
    _BuildSettingInfo = "BuildSettingInfo",
)
load(
    "@rules_android//providers:providers.bzl",
    _AndroidFilteredJdepsInfo = "AndroidFilteredJdepsInfo",
)
load(
    "@rules_android//rules:attrs.bzl",
    _attrs = "attrs",
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
    "@rules_android//rules:resources.bzl",
    _resources = "resources",
)
load(
    "@rules_android//rules:utils.bzl",
    _compilation_mode = "compilation_mode",
    _get_android_sdk = "get_android_sdk",
    _get_android_toolchain = "get_android_toolchain",
    _utils = "utils",
)
load(
    "@rules_android//rules/android_local_test:impl.bzl",
    _BASE_PROCESSORS = "PROCESSORS",
    _filter_jdeps = "filter_jdeps",
    _finalize = "finalize",
)
load(
    "@rules_java//java:defs.bzl",
    "JavaInfo",
    "java_common",
)
load(
    "//kotlin/internal:defs.bzl",
    _JAVA_RUNTIME_TOOLCHAIN_TYPE = "JAVA_RUNTIME_TOOLCHAIN_TYPE",
    _TOOLCHAIN_TYPE = "TOOLCHAIN_TYPE",
)
load(
    "//kotlin/internal/jvm:compile.bzl",
    _compile = "compile",
)
load(
    "//kotlin/internal/jvm:jvm_deps.bzl",
    _jvm_deps_utils = "jvm_deps_utils",
)

_JACOCOCO_CLASS = "com.google.testing.coverage.JacocoCoverageRunner"

def _process_resources(ctx, java_package, manifest_ctx, **_unused_sub_ctxs):
    # Note: This needs to be kept in sync with.
    # The main difference between this and the upstream macro is that both ctx.attr.associates and ctx.attr.deps needs to
    # be passed to `_resources.package(` in order for ALL of the resource references to get merged into a single R
    # class file.
    # https://github.com/bazelbuild/rules_android/blob/e98ee9eb79c9398a9866d073a43ecd5e97aaf896/rules/android_local_test/impl.bzl#L94-L122
    resources_ctx = _resources.package(
        ctx,
        # This entire section is being overridden so that we can pass the associates into the deps section.
        # Without this tests won't be able to reference resources of the associate targets
        deps = ctx.attr.associates + ctx.attr.deps,
        manifest = manifest_ctx.processed_manifest,
        manifest_values = manifest_ctx.processed_manifest_values,
        manifest_merge_order = ctx.attr._manifest_merge_order[_BuildSettingInfo].value,
        resource_files = ctx.files.resource_files,
        assets = ctx.files.assets,
        assets_dir = ctx.attr.assets_dir,
        resource_configs = ctx.attr.resource_configuration_filters,
        densities = ctx.attr.densities,
        nocompress_extensions = ctx.attr.nocompress_extensions,
        compilation_mode = _compilation_mode.get(ctx),
        java_package = java_package,
        shrink_resources = _attrs.tristate.no,
        build_java_with_final_resources = True,
        aapt = _get_android_toolchain(ctx).aapt2.files_to_run,
        android_jar = _get_android_sdk(ctx).android_jar,
        busybox = _get_android_toolchain(ctx).android_resources_busybox.files_to_run,
        host_javabase = ctx.attr._host_javabase,
        # TODO(b/140582167): Throwing on resource conflict need to be rolled
        # out to android_local_test.
        should_throw_on_conflict = False,
    )

    return _ProviderInfo(
        name = "resources_ctx",
        value = resources_ctx,
    )

def _process_jvm(ctx, resources_ctx, **_unused_sub_ctxs):
    """Custom JvmProcessor that handles Kotlin compilation
    """
    _compile.verify_associates_not_duplicated_in_deps(deps = getattr(ctx.attr, "deps", []), associate_deps = getattr(ctx.attr, "associates", []))

    outputs = struct(jar = ctx.outputs.jar, srcjar = ctx.actions.declare_file(ctx.label.name + "-src.jar"))

    deps = (
        [_get_android_toolchain(ctx).testsupport] +
        getattr(ctx.attr, "associates", []) +
        getattr(ctx.attr, "deps", [])
    )

    if ctx.configuration.coverage_enabled:
        deps.append(ctx.toolchains[_TOOLCHAIN_TYPE].jacocorunner)
        java_start_class = _JACOCOCO_CLASS
        coverage_start_class = ctx.attr.main_class
    else:
        java_start_class = ctx.attr.main_class
        coverage_start_class = None

    # Setup the compile action.
    providers = _compile.kt_jvm_produce_output_jar_actions(
        ctx,
        rule_kind = "kt_android_local_test",
        compile_deps = _jvm_deps_utils.jvm_deps(
            ctx,
            toolchains = _compile.compiler_toolchains(ctx),
            deps = deps,
            deps_java_infos = (
                ([resources_ctx.r_java] if resources_ctx.r_java else []) +
                [
                    JavaInfo(
                        output_jar = _get_android_sdk(ctx).android_jar,
                        compile_jar = _get_android_sdk(ctx).android_jar,
                        # The android_jar must not be compiled into the test, it
                        # will bloat the Jar with no benefit.
                        neverlink = True,
                    ),
                ]
            ),
            associate_deps = getattr(ctx.attr, "associates", []),
            runtime_deps = getattr(ctx.attr, "runtime_deps", []),
        ),
        outputs = outputs,
    )

    java_info = providers.java
    if getattr(java_common, "add_constraints", None):
        java_info = java_common.add_constraints(java_info, constraints = ["android"])

    # Create test run action
    providers = [providers.kt, java_info]
    runfiles = []

    # Create a filtered jdeps with no resources jar. See b/129011477 for more context.
    if java_info.outputs.jdeps != None:
        filtered_jdeps = ctx.actions.declare_file(ctx.label.name + ".filtered.jdeps")
        _filter_jdeps(ctx, java_info.outputs.jdeps, filtered_jdeps, _utils.only(resources_ctx.r_java.compile_jars.to_list()))
        providers.append(_AndroidFilteredJdepsInfo(jdeps = filtered_jdeps))
        runfiles.append(filtered_jdeps)

    # Append the security manager override
    jvm_flags = []
    java_runtime = ctx.toolchains[_JAVA_RUNTIME_TOOLCHAIN_TYPE].java_runtime

    _java_runtime_version = getattr(java_runtime, "version", 0)
    if _java_runtime_version >= 17 and _java_runtime_version < 24:
        jvm_flags.append("-Djava.security.manager=allow")

    return _ProviderInfo(
        name = "jvm_ctx",
        value = struct(
            java_info = java_info,
            providers = providers,
            deps = deps,
            java_start_class = java_start_class,
            coverage_start_class = coverage_start_class,
            android_properties_file = ctx.file.robolectric_properties_file.short_path,
            additional_jvm_flags = jvm_flags,
        ),
        runfiles = ctx.runfiles(files = runfiles),
    )

PROCESSORS = _processing_pipeline.replace(
    _BASE_PROCESSORS,
    ResourceProcessor = _process_resources,
    JvmProcessor = _process_jvm,
)

_PROCESSING_PIPELINE = _processing_pipeline.make_processing_pipeline(
    processors = PROCESSORS,
    finalize = _finalize,
)

def kt_android_local_test_impl(ctx):
    """The rule implementation.

    Args:
      ctx: The context.

    Returns:
      A list of providers.
    """
    java_package = _java.resolve_package_from_label(ctx.label, ctx.attr.custom_package)
    return _processing_pipeline.run(ctx, java_package, _PROCESSING_PIPELINE)
