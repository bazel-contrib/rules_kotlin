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
"""Shared attributes for Kotlin JVM and Android rules."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@rules_java//java:defs.bzl", "JavaInfo")
load("@rules_java//java/common:java_plugin_info.bzl", "JavaPluginInfo")
load(
    "//kotlin/internal:defs.bzl",
    "KtPluginConfiguration",
    _KspPluginInfo = "KspPluginInfo",
    _KtCompilerPluginInfo = "KtCompilerPluginInfo",
    _KtJvmInfo = "KtJvmInfo",
)
load(
    "//kotlin/internal:opts.bzl",
    _JavacOptions = "JavacOptions",
    _KotlincOptions = "KotlincOptions",
)
load("//kotlin/internal/utils:utils.bzl", "utils")

_implicit_deps = {
    "java_stub_template": attr.label(
        cfg = "exec",
        default = Label("//third_party:java_stub_template.txt"),
        allow_single_file = True,
    ),
    "_host_javabase": attr.label(
        default = Label("@bazel_tools//tools/jdk:current_java_runtime"),
        cfg = "exec",
    ),
    "_java_plugins": attr.label(
        default = Label("@bazel_tools//tools/jdk:java_plugins_flag_alias"),
        providers = [JavaPluginInfo],
    ),
    "_java_toolchain": attr.label(
        default = Label("@bazel_tools//tools/jdk:current_java_toolchain"),
    ),
    "_ksp2_kotlinx_coroutines": attr.label(
        doc = "kotlinx-coroutines-core-jvm JAR required by KSP2",
        default = Label("//kotlin/compiler:ksp-intellij-kotlinx-coroutines-core-jvm"),
        cfg = "exec",
    ),
    "_ksp2_symbol_processing_aa": attr.label(
        doc = "KSP2 symbol-processing-aa JAR for processor classpath",
        default = Label("//kotlin/compiler:symbol-processing-aa"),
        cfg = "exec",
    ),
    "_ksp2_symbol_processing_api": attr.label(
        doc = "KSP2 symbol-processing-api JAR for processor classpath",
        default = Label("//kotlin/compiler:symbol-processing-api"),
        cfg = "exec",
    ),
    "_ksp2_symbol_processing_common_deps": attr.label(
        doc = "KSP2 symbol-processing-common-deps JAR for processor classpath",
        default = Label("//kotlin/compiler:symbol-processing-common-deps"),
        cfg = "exec",
    ),
    "_kt_toolchain": attr.label(
        doc = """The Kotlin toolchain. it's only purpose is to enable the Intellij
        to discover Kotlin language version""",
        default = Label("//kotlin/internal:current_toolchain"),
        cfg = "target",
    ),
    "_singlejar": attr.label(
        executable = True,
        cfg = "exec",
        default = Label("@bazel_tools//tools/jdk:singlejar"),
        allow_files = True,
    ),
    "_toolchain": attr.label(
        doc = """The Kotlin JVM Runtime. it's only purpose is to enable the Android native rules to discover the Kotlin
        runtime for dexing""",
        default = Label("//kotlin/compiler:kotlin-stdlib"),
        cfg = "target",
    ),
}

_runnable_implicit_deps = utils.add_dicts(
    {
        "_java_runtime": attr.label(
            default = Label("@bazel_tools//tools/jdk:current_java_runtime"),
        ),
        "_launcher": attr.label(
            default = "@bazel_tools//tools/launcher:launcher",
            cfg = "target",
            executable = True,
        ),
        "_windows_constraint": attr.label(
            default = "@platforms//os:windows",
        ),
    },
    # Only add _windows_launcher_maker when the toolchain is not available (legacy fallback)
    {} if bazel_features.rules._has_launcher_maker_toolchain else {
        "_windows_launcher_maker": attr.label(
            default = "@bazel_tools//tools/launcher:launcher_maker",
            cfg = "exec",
            executable = True,
        ),
    },
)

_common_attr = utils.add_dicts(
    _implicit_deps,
    {
        "associates": attr.label_list(
            doc = """Kotlin deps who should be considered part of the same module/compilation-unit
            for the purposes of "internal" access. Such deps must all share the same module space
            and so a target cannot associate to two deps from two different modules.""",
            default = [],
            providers = [JavaInfo, _KtJvmInfo],
        ),
        "data": attr.label_list(
            doc = """The list of files needed by this rule at runtime. See general comments about `data` at
        [Attributes common to all build rules](https://docs.bazel.build/versions/master/be/common-definitions.html#common-attributes).""",
            allow_files = True,
        ),
        "deps": attr.label_list(
            doc = """A list of dependencies of this rule.See general comments about `deps` at
        [Attributes common to all build rules](https://docs.bazel.build/versions/master/be/common-definitions.html#common-attributes).""",
            providers = [
                [JavaInfo],
                [_KtJvmInfo],
            ],
            allow_files = False,
        ),
        "javac_opts": attr.label(
            doc = """Javac options to be used when compiling this target. These opts if provided will
            be used instead of the ones provided to the toolchain.""",
            default = None,
            providers = [_JavacOptions],
            mandatory = False,
        ),
        "kotlinc_opts": attr.label(
            doc = """Kotlinc options to be used when compiling this target. These opts if provided
            will be used instead of the ones provided to the toolchain.""",
            default = None,
            providers = [_KotlincOptions],
            mandatory = False,
        ),
        "manifest_lines": attr.string_list(
            doc = """Lines to add to the main section of the manifest of the output jar, each in the form `Name: value`.
        They follow the `Target-Label` and `Injecting-Rule-Kind` attributes the rules write. A line that repeats them,
        `Manifest-Version` or `Created-By` is rejected. As in the `deploy_manifest_lines` attribute of `java_binary`,
        `Multi-Release`, `Add-Exports` and `Add-Opens` lines are not copied as they are: singlejar merges them and writes
        them in its normalized form, and `Multi-Release` takes `true` or `false`. A target without `srcs` and `resources`
        has no jar of its own and rejects the attribute.""",
            default = [],
        ),
        "module_name": attr.string(
            doc = """The name of the module, if not provided the module name is derived from the label. --e.g.,
        `//some/package/path:label_name` is translated to
        `some_package_path-label_name`.""",
            mandatory = False,
        ),
        "plugins": attr.label_list(
            default = [],
            cfg = "exec",
            providers = [
                [JavaPluginInfo],
                [KtPluginConfiguration],
                [_KspPluginInfo],
                [_KtCompilerPluginInfo],
                [_KtCompilerPluginInfo],
            ],
        ),
        "resource_jars": attr.label_list(
            doc = """Set of archives containing Java resources. If specified, the contents of these jars are merged into
        the output jar.""",
            default = [],
        ),
        "resource_strip_prefix": attr.label(
            doc = """The path prefix to strip from Java resources. Should be a label pointing to a directory.
        Files residing under common prefix such as `src/main/resources` or `src/test/resources` or `kotlin`
        will have stripping applied by convention if this is not specified.""",
            allow_single_file = True,
            #             providers = ["FileProvider"],
        ),
        "resources": attr.label_list(
            doc = """A list of files that should be include in a Java jar.""",
            default = [],
            allow_files = True,
        ),
        "runtime_deps": attr.label_list(
            doc = """Libraries to make available to the final binary or test at runtime only. Like ordinary deps, these will
        appear on the runtime classpath, but unlike them, not on the compile-time classpath.""",
            default = [],
            allow_files = False,
        ),
        "srcs": attr.label_list(
            doc = """The list of source files that are processed to create the target, this can contain both Java and Kotlin
        files. Java analysis occurs first so Kotlin classes may depend on Java classes in the same compilation unit.""",
            default = [],
            allow_files = [".srcjar", ".kt", ".java"],
        ),
    },
)

_lib_common_attr = utils.add_dicts(_common_attr, {
    "exported_compiler_plugins": attr.label_list(
        doc = """\
Exported compiler plugins.

Compiler plugins listed here will be treated as if they were added in the plugins attribute
of any targets that directly depend on this target. Like `java_plugin`s exported_plugins,
this is not transitive""",
        default = [],
        cfg = "exec",
        providers = [[_KtCompilerPluginInfo], [KtPluginConfiguration]],
    ),
    "exports": attr.label_list(
        doc = """\
Exported libraries.

Deps listed here will be made available to other rules, as if the parents explicitly depended on
these deps. This is not true for regular (non-exported) deps.""",
        default = [],
        providers = [JavaInfo],
    ),
    "neverlink": attr.bool(
        doc = """If true only use this library for compilation and not at runtime.""",
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
})

_runnable_common_attr = utils.add_dicts(_common_attr, _runnable_implicit_deps, {
    "env": attr.string_dict(
        doc = """Environment variables to set when this binary is executed with `bazel run`.
Subject to $(location) and "Make variable" substitution.""",
        default = {},
    ),
    "env_inherit": attr.string_list(
        doc = """Names of environment variables to inherit from the shell when executed with `bazel run`.""",
        default = [],
    ),
    "jvm_flags": attr.string_list(
        doc = """A list of flags to embed in the wrapper script generated for running this binary. Note: does not yet
        support make variable substitution.""",
        default = [],
    ),
})

attrs = struct(
    lib_common_attr = _lib_common_attr,
    runnable_common_attr = _runnable_common_attr,
)
