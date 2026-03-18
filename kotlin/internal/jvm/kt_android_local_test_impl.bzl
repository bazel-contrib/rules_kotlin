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
    "@rules_android//rules:common.bzl",
    _common = "common",
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
    _DEFAULT_GC_FLAGS = "DEFAULT_GC_FLAGS",
    _DEFAULT_JIT_FLAGS = "DEFAULT_JIT_FLAGS",
    _DEFAULT_VERIFY_FLAGS = "DEFAULT_VERIFY_FLAGS",
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
load(
    "//kotlin/internal/jvm:kover.bzl",
    _create_kover_agent_actions = "create_kover_agent_actions",
    _create_kover_metadata_action = "create_kover_metadata_action",
    _get_kover_agent_files = "get_kover_agent_file",
    _get_kover_jvm_flags = "get_kover_jvm_flags",
    _is_kover_enabled = "is_kover_enabled",
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

    jvm_flags = []
    transitive = []

    if ctx.configuration.coverage_enabled:
        if _is_kover_enabled(ctx):
            kover_agent_files = _get_kover_agent_files(ctx)
            kover_output_file, kover_args_file = _create_kover_agent_actions(ctx, ctx.attr.name)
            kover_output_metadata_file = _create_kover_metadata_action(
                ctx,
                ctx.attr.name,
                ctx.attr.deps + ctx.attr.associates,
                kover_output_file,
            )

            flags = _get_kover_jvm_flags(kover_agent_files, kover_args_file)
            jvm_flags.append(flags)

            transitive.extend([depset(kover_agent_files), depset([kover_args_file]), depset([kover_output_metadata_file])])

            java_start_class = ctx.attr.main_class
            coverage_start_class = None
        else:
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
        runfiles = ctx.runfiles(
            files = runfiles,
            transitive_files = depset(transitive = transitive),
        ),
    )

# TODO: follow up with Google to have rules_android provide better extensibility points
def _process_stub(ctx, deploy_jar_ctx, jvm_ctx, stub_preprocess_ctx, **_unused_sub_ctxs):
    runfiles = []

    merged_instr = None
    if ctx.configuration.coverage_enabled:
        if not _is_kover_enabled(ctx):
            merged_instr = ctx.actions.declare_file(ctx.label.name + "_merged_instr.jar")
            _java.singlejar(
                ctx,
                [f for f in deploy_jar_ctx.classpath.to_list() if f.short_path.endswith(".jar")],
                merged_instr,
                mnemonic = "JavaDeployJar",
                include_build_data = True,
                java_toolchain = _common.get_java_toolchain(ctx),
            )
            runfiles.append(merged_instr)

    stub = ctx.actions.declare_file(ctx.label.name)
    classpath_file = ctx.actions.declare_file(ctx.label.name + "_classpath")
    runfiles.append(classpath_file)
    test_class = _get_test_class(ctx)
    if not test_class:
        fail("test_class could not be derived for " + str(ctx.label) +
             ". Explicitly set test_class or move this source file to " +
             "a java source root.")

    _create_stub(
        ctx,
        stub_preprocess_ctx.substitutes,
        stub,
        classpath_file,
        deploy_jar_ctx.classpath,
        _get_jvm_flags(ctx, test_class, jvm_ctx.android_properties_file, jvm_ctx.additional_jvm_flags),
        jvm_ctx.java_start_class,
        jvm_ctx.coverage_start_class,
        merged_instr,
    )
    return _ProviderInfo(
        name = "stub_ctx",
        value = struct(
            stub = stub,
        ),
        runfiles = ctx.runfiles(
            files = runfiles,
            transitive_files = depset(
                transitive = stub_preprocess_ctx.runfiles,
            ),
        ),
    )

def _get_test_class(ctx):
    # Use the specified test_class if set
    if ctx.attr.test_class != "":
        return ctx.attr.test_class

    # Use a heuristic based on the rule name and the "srcs" list
    # to determine the primary Java class.
    expected = "/" + ctx.label.name + ".java"
    for f in ctx.attr.srcs:
        path = f.label.package + "/" + f.label.name
        if path.endswith(expected):
            return _java.resolve_package(path[:-5])

    # Last resort: Use the name and package name of the target.
    return _java.resolve_package(ctx.label.package + "/" + ctx.label.name)

def _create_stub(
        ctx,
        substitutes,
        stub_file,
        classpath_file,
        runfiles,
        jvm_flags,
        java_start_class,
        coverage_start_class,
        merged_instr):
    subs = {
        # To avoid cracking open the depset, classpath is read from a separate
        # file created in its own action. Needed as expand_template does not
        # support ctx.actions.args().
        "%classpath%": "$(eval echo $(<%s))" % (classpath_file.short_path),
        "%java_start_class%": java_start_class,
        "%jvm_flags%": " ".join(jvm_flags),
        "%needs_runfiles%": "1",
        "%runfiles_manifest_only%": "",
        "%workspace_prefix%": ctx.workspace_name + "/",
    }

    if coverage_start_class:
        prefix = ctx.attr._runfiles_root_prefix[_BuildSettingInfo].value
        subs["%set_jacoco_metadata%"] = (
            "export JACOCO_METADATA_JAR=${JAVA_RUNFILES}/" + prefix +
            merged_instr.short_path
        )
        subs["%set_jacoco_main_class%"] = (
            "export JACOCO_MAIN_CLASS=" + coverage_start_class
        )
        subs["%set_jacoco_java_runfiles_root%"] = (
            "export JACOCO_JAVA_RUNFILES_ROOT=${JAVA_RUNFILES}/" + prefix
        )
    else:
        subs["%set_jacoco_metadata%"] = ""
        subs["%set_jacoco_main_class%"] = ""
        subs["%set_jacoco_java_runfiles_root%"] = ""

    subs.update(substitutes)

    ctx.actions.expand_template(
        template = _utils.only(_get_android_toolchain(ctx).java_stub.files.to_list()),
        output = stub_file,
        substitutions = subs,
        is_executable = True,
    )

    args = ctx.actions.args()
    args.add_joined(
        runfiles,
        join_with = ":",
        map_each = _get_classpath,
    )
    args.set_param_file_format("multiline")
    ctx.actions.write(
        output = classpath_file,
        content = args,
    )
    return stub_file

def _get_classpath(s):
    return "${J3}" + s.short_path

def _get_jvm_flags(ctx, main_class, robolectric_properties_path, additional_jvm_flags):
    return [
        "-ea",
        "-Dbazel.test_suite=" + main_class,
        "-Drobolectric.offline=true",
        "-Drobolectric-deps.properties=" + robolectric_properties_path,
        "-Duse_framework_manifest_parser=true",
        "-Drobolectric.logging=stdout",
        "-Drobolectric.logging.enabled=true",
        "-Dorg.robolectric.packagesToNotAcquire=com.google.testing.junit.runner.util",
    ] + _DEFAULT_JIT_FLAGS + _DEFAULT_GC_FLAGS + _DEFAULT_VERIFY_FLAGS + additional_jvm_flags + [
        ctx.expand_make_variables(
            "jvm_flags",
            ctx.expand_location(flag, ctx.attr.data),
            {},
        )
        for flag in ctx.attr.jvm_flags
    ]

PROCESSORS = _processing_pipeline.replace(
    _BASE_PROCESSORS,
    ResourceProcessor = _process_resources,
    JvmProcessor = _process_jvm,
    StubProcessor = _process_stub,
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
