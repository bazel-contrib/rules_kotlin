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
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@rules_java//java:defs.bzl", "JavaInfo", "java_common")
load(
    "//kotlin/internal:defs.bzl",
    _TOOLCHAIN_TYPE = "TOOLCHAIN_TYPE",
)
load(
    "//kotlin/internal:opts.bzl",
    "JavacOptions",
    "KotlincOptions",
    "kt_javac_options",
    "kt_kotlinc_options",
)

"""Kotlin Toolchains

This file contains macros for defining and registering specific toolchains.

### Examples

To override a tool chain use the appropriate macro in a `BUILD` file to declare the toolchain:

```bzl
load("@rules_kotlin//kotlin:toolchains.bzl", "define_kt_toolchain")

define_kt_toolchain(
    name= "custom_toolchain",
    api_version = "2.1",
    language_version = "2.1",
)
```
and then register it in `MODULE.bazel`:
```bzl
register_toolchains("//:custom_toolchain")
```
"""

def _kotlin_toolchain_impl(ctx):
    # Create neverlink JavaInfo providers using actual compile_jars (header jars) from stdlib targets.
    compile_time_providers = []
    for target in ctx.attr.jvm_stdlibs:
        if JavaInfo in target:
            for java_output in target[JavaInfo].java_outputs:
                compile_time_providers.append(JavaInfo(
                    output_jar = java_output.class_jar,
                    compile_jar = java_output.compile_jar if java_output.compile_jar else java_output.class_jar,
                    neverlink = True,
                ))

    # For runtime, use actual JavaInfo providers (they contain proper runtime jars)
    runtime_providers = [
        target[JavaInfo]
        for target in ctx.attr.jvm_runtime
        if JavaInfo in target
    ]

    use_btapi = ctx.attr.experimental_build_tools_api or ctx.attr._experimental_build_tools_api[BuildSettingInfo].value

    if use_btapi:
        build_tools_info = ctx.attr.build_tools_impl[JavaInfo]
        build_tools_runtime_classpath = depset(
            direct = build_tools_info.runtime_output_jars,
            transitive = [build_tools_info.transitive_runtime_jars],
        )
    else:
        build_tools_runtime_classpath = depset()

    toolchain = dict(
        language_version = ctx.attr.language_version,
        api_version = ctx.attr.api_version,
        debug = ctx.attr.debug,
        jvm_target = ctx.attr.jvm_target,
        kotlinbuilder = ctx.attr.kotlinbuilder,
        builder_args = [],
        jdeps_merger = ctx.attr.jdeps_merger,
        ksp2 = ctx.attr.ksp2,
        ksp2_invoker = ctx.attr.ksp2_invoker,
        snapshot_worker = ctx.attr.snapshot_worker,
        build_tools_impl = ctx.attr.build_tools_impl,
        experimental_build_tools_api = use_btapi,
        btapi_runtime_classpath = build_tools_runtime_classpath,
        jvm_abi_gen = ctx.file.jvm_abi_gen if use_btapi else None,
        skip_code_gen = ctx.file.skip_code_gen if use_btapi else None,
        jdeps_gen = ctx.file.jdeps_gen if use_btapi else None,
        kapt = ctx.file.kapt if use_btapi else None,
        jvm_stdlibs = java_common.merge(compile_time_providers + runtime_providers),
        jvm_emit_jdeps = ctx.attr._jvm_emit_jdeps[BuildSettingInfo].value,
        execution_requirements = {
            "supports-multiplex-sandboxing": "1" if ctx.attr.experimental_multiplex_sandboxing else "0",
            "supports-multiplex-workers": "1" if ctx.attr.experimental_multiplex_workers else "0",
            "supports-path-mapping": "1" if ctx.attr.supports_path_mapping else "0",
            "supports-workers": "1",
        },
        experimental_use_abi_jars = ctx.attr.experimental_use_abi_jars,
        experimental_treat_internal_as_private_in_abi_jars = ctx.attr.experimental_treat_internal_as_private_in_abi_jars,
        experimental_remove_private_classes_in_abi_jars = ctx.attr.experimental_remove_private_classes_in_abi_jars,
        experimental_remove_debug_info_in_abi_jars = ctx.attr.experimental_remove_debug_info_in_abi_jars,
        experimental_strict_kotlin_deps = ctx.attr.experimental_strict_kotlin_deps,
        experimental_report_unused_deps = ctx.attr.experimental_report_unused_deps,
        experimental_reduce_classpath_mode = ctx.attr.experimental_reduce_classpath_mode,
        experimental_incremental_compilation = ctx.attr.experimental_incremental_compilation[BuildSettingInfo].value,
        experimental_ic_enable_logging = ctx.attr.experimental_ic_enable_logging[BuildSettingInfo].value,
        javac_options = ctx.attr.javac_options[JavacOptions] if ctx.attr.javac_options else None,
        kotlinc_options = ctx.attr.kotlinc_options[KotlincOptions] if ctx.attr.kotlinc_options else None,
        empty_jar = ctx.file._empty_jar,
        empty_jdeps = ctx.file._empty_jdeps,
        jacocorunner = ctx.attr.jacocorunner,
        experimental_prune_transitive_deps = ctx.attr._experimental_prune_transitive_deps[BuildSettingInfo].value,
        experimental_strict_associate_dependencies = ctx.attr._experimental_strict_associate_dependencies[BuildSettingInfo].value,
    )

    return [
        platform_common.ToolchainInfo(**toolchain),
    ]

_kt_toolchain = rule(
    doc = """The kotlin toolchain. This should not be created directly `define_kt_toolchain` should be used. The
    rules themselves define the toolchain using that macro.""",
    attrs = {
        "api_version": attr.string(
            doc = "this is the -api_version flag [see](https://kotlinlang.org/docs/reference/compatibility.html).",
            default = "2.1",
            values = [
                "1.1",
                "1.2",
                "1.3",
                "1.4",
                "1.5",
                "1.6",
                "1.7",
                "1.8",
                "1.9",
                "2.0",
                "2.1",
                "2.2",
                "2.3",
            ],
        ),
        "build_tools_impl": attr.label(
            doc = "Kotlin runtime: kotlin-build-tools-impl artifact.",
            providers = [JavaInfo],
            cfg = "exec",
            default = Label("//kotlin/compiler:kotlin-build-tools-impl"),
        ),
        "experimental_build_tools_api": attr.bool(
            doc = "Enables experimental support for Build Tools API integration",
            default = False,
        ),
        "debug": attr.string_list(
            doc = """Debugging tags passed to the builder. Two tags are supported. `timings` will cause the builder to
            print timing information. `trace` will cause the builder to print tracing messages. These tags can be
            enabled via the defines `kt_timings=1` and `kt_trace=1`. These can also be enabled on a per target bases by
            using `tags` attribute defined directly on the rules.""",
            allow_empty = True,
        ),
        "experimental_ic_enable_logging": attr.label(
            doc = "Enables incremental-compilation logging output.",
            default = Label("//kotlin/settings:experimental_ic_enable_logging"),
        ),
        "experimental_incremental_compilation": attr.label(
            doc = "Enables incremental compilation. Requires experimental_build_tools_api.",
            default = Label("//kotlin/settings:experimental_incremental_compilation"),
        ),
        "experimental_multiplex_sandboxing": attr.bool(
            doc = """Run workers with multiplex sandboxing.""",
            default = False,
        ),
        "experimental_multiplex_workers": attr.bool(
            doc = """Run workers in multiplex mode.""",
            default = True,
        ),
        "experimental_reduce_classpath_mode": attr.string(
            doc = "Removes unneeded dependencies from the classpath",
            default = "NONE",
            values = [
                "NONE",
                "KOTLINBUILDER_REDUCED",
            ],
        ),
        "experimental_remove_debug_info_in_abi_jars": attr.bool(
            doc = """This applies the following compiler plugin option:
              plugin:org.jetbrains.kotlin.jvm.abi:removeDebugInfo=true
            Can be disabled for an individual target using the tag.
            `kt_remove_debug_info_in_abi_plugin_incompatible`""",
            default = False,
        ),
        "experimental_remove_private_classes_in_abi_jars": attr.bool(
            doc = """This applies the following compiler plugin option:
              plugin:org.jetbrains.kotlin.jvm.abi:removePrivateClasses=true
            Can be disabled for an individual target using the tag.
            `kt_remove_private_classes_in_abi_plugin_incompatible`""",
            default = False,
        ),
        "experimental_report_unused_deps": attr.string(
            doc = "Report unused dependencies",
            default = "off",
            values = [
                "off",
                "warn",
                "error",
            ],
        ),
        "experimental_strict_kotlin_deps": attr.string(
            doc = "Report strict deps violations",
            default = "off",
            values = [
                "off",
                "warn",
                "error",
            ],
        ),
        "experimental_treat_internal_as_private_in_abi_jars": attr.bool(
            doc = """This applies the following compiler plugin option:
              plugin:org.jetbrains.kotlin.jvm.abi:treatInternalAsPrivate=true
            Can be disabled for an individual target using the tag.
            `kt_treat_internal_as_private_in_abi_plugin_incompatible`""",
            default = False,
        ),
        "experimental_use_abi_jars": attr.bool(
            doc = """Compile using abi jars. Can be disabled for an individual target using the tag
            `kt_abi_plugin_incompatible`""",
            default = False,
        ),
        "jacocorunner": attr.label(
            default = Label("@remote_java_tools//:jacoco_coverage_runner"),
        ),
        "javac_options": attr.label(
            doc = "Compiler options for javac",
            providers = [JavacOptions],
        ),
        "jdeps_gen": attr.label(
            doc = "Kotlin builder plugin: jdeps-gen.",
            allow_single_file = True,
            cfg = "exec",
            default = Label("//src/main/kotlin:jdeps-gen"),
        ),
        "jdeps_merger": attr.label(
            doc = "the jdeps merger executable",
            default = Label("//src/main/kotlin:jdeps_merger"),
            executable = True,
            allow_files = True,
            cfg = "exec",
        ),
        "jvm_abi_gen": attr.label(
            doc = "Kotlin builder plugin: jvm-abi-gen.",
            allow_single_file = True,
            cfg = "exec",
            default = Label("//kotlin/compiler:jvm-abi-gen"),
        ),
        "jvm_runtime": attr.label_list(
            doc = "The implicit jvm runtime libraries. This is internal.",
            providers = [JavaInfo],
            cfg = "target",
        ),
        "jvm_stdlibs": attr.label_list(
            doc = "The jvm stdlibs. This is internal.",
            providers = [JavaInfo],
            cfg = "target",
        ),
        "jvm_target": attr.string(
            doc = "the -jvm_target flag. This is only tested at 1.8.",
            default = "1.8",
            values = [
                "1.6",
                "1.8",
                "9",
                "10",
                "11",
                "12",
                "13",
                "15",
                "16",
                "17",
                "18",
                "19",
                "20",
                "21",
                "22",
                "23",
                "24",
                "25",
            ],
        ),
        "kapt": attr.label(
            doc = "Kotlin builder plugin: kotlin-annotation-processing-embeddable.",
            allow_single_file = True,
            cfg = "exec",
            default = Label("//kotlin/compiler:kotlin-annotation-processing-embeddable"),
        ),
        "kotlinbuilder": attr.label(
            doc = "the kotlin builder executable",
            default = Label("//src/main/kotlin:build"),
            executable = True,
            allow_files = True,
            cfg = "exec",
        ),
        "kotlinc_options": attr.label(
            doc = "Compiler options for kotlinc",
            providers = [KotlincOptions],
        ),
        "ksp2": attr.label(
            doc = "the KSP2 worker executable",
            default = Label("//src/main/kotlin:ksp2"),
            executable = True,
            allow_files = True,
            cfg = "exec",
        ),
        "ksp2_invoker": attr.label(
            doc = "the KSP2 invoker library JAR (loaded at runtime in KSP2 classloader)",
            default = Label("//src/main/kotlin:ksp2_invoker"),
            allow_files = True,
            cfg = "exec",
        ),
        "language_version": attr.string(
            doc = "this is the -language_version flag [see](https://kotlinlang.org/docs/reference/compatibility.html)",
            default = "2.1",
            values = [
                "1.1",
                "1.2",
                "1.3",
                "1.4",
                "1.5",
                "1.6",
                "1.7",
                "1.8",
                "1.9",
                "2.0",
                "2.1",
                "2.2",
                "2.3",
            ],
        ),
        "snapshot_worker": attr.label(
            doc = "the snapshot worker executable",
            default = Label("//src/main/kotlin:snapshot"),
            executable = True,
            allow_files = True,
            cfg = "exec",
        ),
        "skip_code_gen": attr.label(
            doc = "Kotlin builder plugin: skip-code-gen.",
            allow_single_file = True,
            cfg = "exec",
            default = Label("//src/main/kotlin:skip-code-gen"),
        ),
        "supports_path_mapping": attr.bool(
            doc = """Enable path mapping for Kotlin actions. Requires experimental_multiplex_sandboxing.""",
            default = False,
        ),
        "_empty_jar": attr.label(
            doc = """Empty jar for exporting JavaInfos.""",
            allow_single_file = True,
            cfg = "target",
            default = Label("//third_party:empty.jar"),
        ),
        "_empty_jdeps": attr.label(
            doc = """Empty jdeps for exporting JavaInfos.""",
            allow_single_file = True,
            cfg = "target",
            default = Label("//third_party:empty.jdeps"),
        ),
        "_experimental_prune_transitive_deps": attr.label(
            doc = """If enabled, compilation is performed against only direct dependencies.
            Transitive deps required for compilation must be explicitly added. Using
            kt_experimental_prune_transitive_deps_incompatible tag allows to exclude specific targets""",
            default = Label("//kotlin/settings:experimental_prune_transitive_deps"),
        ),
        "_experimental_build_tools_api": attr.label(
            doc = """Public build setting controlling Build Tools API support.""",
            default = Label("//kotlin/settings:experimental_build_tools_api"),
        ),
        "_experimental_strict_associate_dependencies": attr.label(
            doc = """
            If enabled, only the direct compile jars will be collected for each listed associate target
            instead of the compelte transitive set of jars. This helps prevent Kotlin internals from leaking beyond
            their intended exposure by only exposing the direct java outputs. Using
            kt_experimental_prune_transitive_deps_incompatible tag allows to exclude specific targets""",
            default = Label("//kotlin/settings:experimental_strict_associate_dependencies"),
        ),
        "_jvm_emit_jdeps": attr.label(default = "//kotlin/settings:jvm_emit_jdeps"),
    },
    implementation = _kotlin_toolchain_impl,
    provides = [platform_common.ToolchainInfo],
)

# Evaluating the select in the context of bzl file to get its repository
_DEBUG_SELECT = select({
    str(Label("//kotlin/internal:builder_debug_trace")): ["trace"],
    "//conditions:default": [],
}) + select({
    str(Label("//kotlin/internal:builder_debug_timings")): ["timings"],
    "//conditions:default": [],
})

# Evaluating the labels in the context of bzl file to get its repository
_EXPERIMENTAL_USE_ABI_JARS = str(Label("//kotlin/internal:experimental_use_abi_jars"))
_NOEXPERIMENTAL_USE_ABI_JARS = str(Label("//kotlin/internal:noexperimental_use_abi_jars"))

def define_kt_toolchain(
        name,
        language_version = None,
        api_version = None,
        jvm_target = None,
        experimental_use_abi_jars = False,
        experimental_treat_internal_as_private_in_abi_jars = False,
        experimental_remove_private_classes_in_abi_jars = False,
        experimental_remove_debug_info_in_abi_jars = False,
        experimental_strict_kotlin_deps = None,
        experimental_report_unused_deps = None,
        experimental_reduce_classpath_mode = None,
        experimental_multiplex_workers = None,
        experimental_multiplex_sandboxing = None,
        supports_path_mapping = None,
        experimental_incremental_compilation = None,
        experimental_ic_enable_logging = None,
        experimental_build_tools_api = None,
        javac_options = Label("//kotlin/internal:default_javac_options"),
        kotlinc_options = Label("//kotlin/internal:default_kotlinc_options"),
        jvm_stdlibs = None,
        jvm_runtime = None,
        jacocorunner = None,
        build_tools_impl = None,
        jvm_abi_gen = None,
        skip_code_gen = None,
        jdeps_gen = None,
        kapt = None,
        exec_compatible_with = None,
        target_compatible_with = None,
        target_settings = None):
    """Define the Kotlin toolchain."""
    impl_name = name + "_impl"

    _kt_toolchain(
        name = impl_name,
        language_version = language_version,
        api_version = api_version,
        jvm_target = jvm_target,
        debug = _DEBUG_SELECT,
        experimental_use_abi_jars = select({
            _EXPERIMENTAL_USE_ABI_JARS: True,
            _NOEXPERIMENTAL_USE_ABI_JARS: False,
            "//conditions:default": experimental_use_abi_jars,
        }),
        experimental_treat_internal_as_private_in_abi_jars = experimental_treat_internal_as_private_in_abi_jars,
        experimental_remove_private_classes_in_abi_jars = experimental_remove_private_classes_in_abi_jars,
        experimental_remove_debug_info_in_abi_jars = experimental_remove_debug_info_in_abi_jars,
        experimental_multiplex_workers = experimental_multiplex_workers,
        experimental_multiplex_sandboxing = experimental_multiplex_sandboxing,
        supports_path_mapping = supports_path_mapping,
        experimental_strict_kotlin_deps = experimental_strict_kotlin_deps,
        experimental_report_unused_deps = experimental_report_unused_deps,
        experimental_reduce_classpath_mode = experimental_reduce_classpath_mode,
        experimental_incremental_compilation = experimental_incremental_compilation,
        experimental_ic_enable_logging = experimental_ic_enable_logging,
        experimental_build_tools_api = experimental_build_tools_api,
        javac_options = javac_options,
        kotlinc_options = kotlinc_options,
        visibility = ["//visibility:public"],
        jacocorunner = jacocorunner,
        build_tools_impl = build_tools_impl,
        jvm_abi_gen = jvm_abi_gen,
        skip_code_gen = skip_code_gen,
        jdeps_gen = jdeps_gen,
        kapt = kapt,
        jvm_stdlibs = jvm_stdlibs if jvm_stdlibs != None else [
            Label("//kotlin/compiler:annotations"),
            Label("//kotlin/compiler:kotlin-stdlib"),
        ],
        jvm_runtime = jvm_runtime if jvm_runtime != None else [
            Label("//kotlin/compiler:kotlin-stdlib"),
        ],
    )
    native.toolchain(
        name = name,
        toolchain_type = _TOOLCHAIN_TYPE,
        toolchain = impl_name,
        visibility = ["//visibility:public"],
        exec_compatible_with = exec_compatible_with or [],
        target_compatible_with = target_compatible_with or [],
        target_settings = target_settings or [],
    )

def _kt_toolchain_alias_impl(ctx):
    toolchain_info = ctx.toolchains[_TOOLCHAIN_TYPE]

    return [
        toolchain_info,
    ]

_kt_toolchain_alias = rule(
    implementation = _kt_toolchain_alias_impl,
    toolchains = [_TOOLCHAIN_TYPE],
)

def kt_configure_toolchains():
    """
    Defines the toolchain_type and default toolchain for kotlin compilation.

    Must be called in kotlin/internal/BUILD.bazel
    """
    if native.package_name() != "kotlin/internal":
        fail("kt_configure_toolchains must be called in kotlin/internal not %s" % native.package_name())

    kt_kotlinc_options(
        name = "default_kotlinc_options",
        include_stdlibs = "none",
        visibility = ["//visibility:public"],
    )

    kt_javac_options(
        name = "default_javac_options",
        visibility = ["//visibility:public"],
    )

    native.config_setting(
        name = "experimental_use_abi_jars",
        values = {"define": "experimental_use_abi_jars=1"},
        visibility = ["//visibility:public"],
    )
    native.config_setting(
        name = "noexperimental_use_abi_jars",
        values = {"define": "experimental_use_abi_jars=0"},
        visibility = ["//visibility:public"],
    )

    native.config_setting(
        name = "builder_debug_timings",
        values = {"define": "kt_timings=1"},
        visibility = ["//visibility:public"],
    )

    native.config_setting(
        name = "experimental_multiplex_workers",
        values = {"define": "kt_multiplex=1"},
        visibility = ["//visibility:public"],
    )

    native.config_setting(
        name = "builder_debug_trace",
        values = {"define": "kt_trace=1"},
        visibility = ["//visibility:public"],
    )

    native.toolchain_type(
        name = "kt_toolchain_type",
        visibility = ["//visibility:public"],
    )

    define_kt_toolchain(
        name = "default_toolchain",
    )

    _kt_toolchain_alias(
        name = "current_toolchain",
        visibility = ["//visibility:public"],
    )
