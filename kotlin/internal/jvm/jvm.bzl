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
"""Kotlin Rules

### Setup

Add `rules_kotlin` to your `MODULE.bazel`:

```bzl
bazel_dep(name = "rules_kotlin", version = "<VERSION>")
```

To enable persistent worker support, add the following to the appropriate `bazelrc` file:

```
build --strategy=KotlinCompile=worker
test --strategy=KotlinCompile=worker
```


### Standard Libraries

The Kotlin libraries that are bundled in a kotlin release should be used with the rules, the mandatory standard libraries are added implicetly. The following
Kotlin Libraries are available from the `//kotlin/compiler` aliases:

* `kotlin-test`,
* `kotlin-reflect`.

So if you needed to add reflect as a dep use the following label `//kotlin/compiler:kotlin-reflect`.

### Mixed Mode compilation

The JVM rules can compile both Java and Kotlin sources. The Java compiler wrapper is not optimized or persistent and does not have the features found in the
native java rules. This mode is usefull for migrating a package to Kotlin over time.

### Annotation Processing

Annotation processing works just as it does in Java, plugins are declared via a [`java_plugin`](https://docs.bazel.build/versions/master/be/java.html#java_plugin)
and may also be inherited from a `java_library` via the `exported_plugins` attribute. Annotation work in mixed-mode compilation and the Kotlin compiler take
care of processing both aspects.

An example which can be found under `//examples/dagger`:

```bzl
java_plugin(
    name = "dagger_plugin",
    deps = [
        "@dagger_compiler//jar",
        "@guava//jar",
        "@dagger_producers//jar",
        "@dagger//jar",
        "@javax_inject//jar"
    ],
    processor_class = "dagger.internal.codegen.ComponentProcessor"
)

java_library(
    name = "dagger_lib",
    exports = [
        "@javax_inject//jar",
        "@dagger//jar",
    ],
    exported_plugins = ["dagger_plugin"]
)

kt_jvm_binary(
    name = "dagger",
    srcs = glob(["src/**"]),
    main_class = "coffee.CoffeeApp",
    deps = [":dagger_lib"],
)
```
"""

load("@bazel_features//:features.bzl", "bazel_features")
load("@rules_java//java:defs.bzl", "JavaInfo")
load("@rules_java//java/common:java_plugin_info.bzl", "JavaPluginInfo")
load(
    "//kotlin/internal:defs.bzl",
    "KtPluginConfiguration",
    _JAVA_RUNTIME_TOOLCHAIN_TYPE = "JAVA_RUNTIME_TOOLCHAIN_TYPE",
    _JAVA_TOOLCHAIN_TYPE = "JAVA_TOOLCHAIN_TYPE",
    _KspPluginInfo = "KspPluginInfo",
    _KtCompilerPluginInfo = "KtCompilerPluginInfo",
    _KtJvmInfo = "KtJvmInfo",
    _TOOLCHAIN_TYPE = "TOOLCHAIN_TYPE",
)
load(
    "//kotlin/internal:opts.bzl",
    _JavacOptions = "JavacOptions",
    _KotlincOptions = "KotlincOptions",
)
load(
    "//kotlin/internal/jvm:impl.bzl",
    "kt_plugin_cfg_impl",
    _kt_compiler_deps_aspect_impl = "kt_compiler_deps_aspect_impl",
    _kt_compiler_plugin_impl = "kt_compiler_plugin_impl",
    _kt_jvm_binary_impl = "kt_jvm_binary_impl",
    _kt_jvm_import_impl = "kt_jvm_import_impl",
    _kt_jvm_junit_test_impl = "kt_jvm_junit_test_impl",
    _kt_jvm_library_impl = "kt_jvm_library_impl",
    _kt_ksp_plugin_impl = "kt_ksp_plugin_impl",
)
load("//kotlin/internal/utils:utils.bzl", "utils")

# Toolchain type for the Windows launcher maker
_LAUNCHER_MAKER_TOOLCHAIN_TYPE = "@bazel_tools//tools/launcher:launcher_maker_toolchain_type"

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
    "_zipper": attr.label(
        executable = True,
        cfg = "exec",
        default = Label("@bazel_tools//tools/zip:zipper"),
        allow_files = True,
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
        "_use_auto_exec_groups": attr.bool(default = False),
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
Note: for Starlark rules, values are used as-is (no automatic $(location) / make variable expansion).""",
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

_common_outputs = dict(
    jar = "%{name}.jar",
    # The params file, declared here so that validate it can be validated for testing.
    #    jar_2_params = "%{name}.jar-2.params",
    srcjar = "%{name}-sources.jar",
)

_common_toolchains = [
    _TOOLCHAIN_TYPE,
    _JAVA_TOOLCHAIN_TYPE,
]

_runnable_common_toolchains = [
    _JAVA_RUNTIME_TOOLCHAIN_TYPE,
] + ([config_common.toolchain_type(_LAUNCHER_MAKER_TOOLCHAIN_TYPE, mandatory = False)] if bazel_features.rules._has_launcher_maker_toolchain else [])

kt_jvm_library = rule(
    doc = """This rule compiles and links Kotlin and Java sources into a .jar file.""",
    attrs = _lib_common_attr,
    outputs = _common_outputs,
    toolchains = _common_toolchains,
    fragments = ["java"],  # Required fragments of the target configuration
    host_fragments = ["java"],  # Required fragments of the host configuration
    implementation = _kt_jvm_library_impl,
    provides = [JavaInfo, _KtJvmInfo],
)

kt_jvm_binary = rule(
    doc = """\
Builds a Java archive ("jar file"), plus a wrapper shell script with the same name as the rule. The wrapper
shell script uses a classpath that includes, among other things, a jar file for each library on which the binary
depends.

**Note:** This rule does not have all of the features found in [`java_binary`](https://docs.bazel.build/versions/master/be/java.html#java_binary).
It is appropriate for building workspace utilities. `java_binary` should be preferred for release artefacts.
""",
    attrs = dict(_runnable_common_attr.items() + {
        "main_class": attr.string(
            doc = """Name of class with main() method to use as entry point.""",
            mandatory = True,
        ),
    }.items()),
    executable = True,
    outputs = _common_outputs,
    toolchains = _common_toolchains + _runnable_common_toolchains,
    fragments = ["java"],  # Required fragments of the target configuration
    host_fragments = ["java"],  # Required fragments of the host configuration
    implementation = _kt_jvm_binary_impl,
)

kt_jvm_test = rule(
    doc = """\
Setup a simple kotlin_test.

**Notes:**
* The kotlin test library is not added implicitly, it is available with the label
`@rules_kotlin//kotlin/compiler:kotlin-test`.
""",
    attrs = utils.add_dicts(_runnable_common_attr, {
        "env": attr.string_dict(
            doc = "Specifies additional environment variables to set when the target is executed by bazel test.",
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
        "_lcov_merger": attr.label(
            default = Label("@bazel_tools//tools/test/CoverageOutputGenerator/java/com/google/devtools/coverageoutputgenerator:Main"),
        ),
    }),
    executable = True,
    outputs = _common_outputs,
    test = True,
    toolchains = _common_toolchains + _runnable_common_toolchains,
    implementation = _kt_jvm_junit_test_impl,
    fragments = ["java"],  # Required fragments of the target configuration
    host_fragments = ["java"],  # Required fragments of the host configuration
)

kt_jvm_import = rule(
    doc = """\
Import Kotlin jars.

## examples

```bzl
# Old style usage -- reference file groups, do not used this.
kt_jvm_import(
    name = "kodein",
    jars = [
        "@com_github_salomonbrys_kodein_kodein//jar:file",
        "@com_github_salomonbrys_kodein_kodein_core//jar:file"
    ]
)

# This style will pull in the transitive runtime dependencies of the targets as well.
kt_jvm_import(
    name = "kodein",
    jars = [
        "@com_github_salomonbrys_kodein_kodein//jar",
        "@com_github_salomonbrys_kodein_kodein_core//jar"
    ]
)

# Import a single kotlin jar.
kt_jvm_import(
    name = "kotlin-stdlib",
    jars = ["lib/kotlin-stdlib.jar"],
    srcjar = "lib/kotlin-stdlib-sources.jar"
)
```
""",
    attrs = {
        "deps": attr.label_list(
            doc = """Compile and runtime dependencies""",
            default = [],
            mandatory = False,
            providers = [JavaInfo],
        ),
        "exported_compiler_plugins": attr.label_list(
            doc = """\
Exported compiler plugins.

Compiler plugins listed here will be treated as if they were added in the plugins
attribute of any targets that directly depend on this target. Like java_plugins'
exported_plugins, this is not transitive""",
            default = [],
            providers = [[_KtCompilerPluginInfo], [KtPluginConfiguration], [_KspPluginInfo]],
        ),
        "exports": attr.label_list(
            doc = """\
Exported libraries.

Deps listed here will be made available to other rules, as if the parents explicitly depended on
these deps. This is not true for regular (non-exported) deps.""",
            default = [],
            providers = [JavaInfo, _KtJvmInfo],
        ),
        "jar": attr.label(
            doc = """The jar listed here is equivalent to an export attribute.""",
            allow_single_file = True,
            cfg = "target",
        ),
        "jars": attr.label_list(
            doc = """\
The jars listed here are equavalent to an export attribute. The label should be either to a single
class jar, or one or more filegroup labels.  The filegroups, when resolved, must contain  only one jar
containing classes, and (optionally) one peer file containing sources, named `<jarname>-sources.jar`.

DEPRECATED - please use `jar` and `srcjar` attributes.""",
            allow_files = True,
            cfg = "target",
        ),
        "neverlink": attr.bool(
            doc = """If true only use this library for compilation and not at runtime.""",
            default = False,
        ),
        "runtime_deps": attr.label_list(
            doc = """Additional runtime deps.""",
            default = [],
            mandatory = False,
            providers = [JavaInfo],
        ),
        "srcjar": attr.label(
            doc = """The sources for the class jar.""",
            allow_single_file = True,
            cfg = "target",
            # TODO(https://github.com/bazelbuild/intellij/issues/1616): Remove when the Intellij Aspect has the
            #  correct null checks.
            default = "//third_party:empty.jar",
        ),
    },
    implementation = _kt_jvm_import_impl,
    provides = [JavaInfo, _KtJvmInfo],
)

_kt_compiler_deps_aspect = aspect(
    implementation = _kt_compiler_deps_aspect_impl,
    attr_aspects = ["deps", "runtime_deps", "exports"],
    attrs = {
        "_jarjar": attr.label(
            executable = True,
            cfg = "exec",
            default = Label("//third_party:jarjar_runner"),
        ),
        "_kotlin_compiler_reshade_rules": attr.label(
            default = Label("//kotlin/internal/jvm:kotlin-compiler-reshade.jarjar"),
            allow_single_file = True,
        ),
    },
)

kt_compiler_plugin = rule(
    doc = """\
Define a plugin for the Kotlin compiler to run. The plugin can then be referenced in the `plugins` attribute
of the `kt_jvm_*` rules.

An example can be found under `//examples/plugin`:

```bzl
kt_compiler_plugin(
    name = "open_for_testing_plugin",
    id = "org.jetbrains.kotlin.allopen",
    options = {
        "annotation": "plugin.OpenForTesting",
    },
    deps = [
        "//kotlin/compiler:allopen-compiler-plugin",
    ],
)

kt_jvm_library(
    name = "open_for_testing",
    srcs = ["OpenForTesting.kt"],
)

kt_jvm_library(
    name = "user",
    srcs = ["User.kt"],
    plugins = [":open_for_testing_plugin"],
    deps = [
        ":open_for_testing",
    ],
)
```
""",
    attrs = {
        "compile_phase": attr.bool(
            doc = "Runs the compiler plugin during kotlin compilation. Known examples: `allopen`, `sam_with_reciever`",
            default = True,
        ),
        "data": attr.label_list(
            doc = "The list of data files to be used by compiler's plugin",
            providers = [DefaultInfo],
            cfg = "exec",
        ),
        "deps": attr.label_list(
            doc = "The list of libraries to be added to the compiler's plugin classpath",
            providers = [JavaInfo],
            cfg = "exec",
            aspects = [_kt_compiler_deps_aspect],
        ),
        "id": attr.string(
            doc = "The ID of the plugin",
            mandatory = True,
        ),
        "options": attr.string_dict(
            doc = """\
Dictionary of options to be passed to the plugin.
Supports the following template values:

- `{generatedClasses}`: directory for generated class output
- `{temp}`: temporary directory, discarded between invocations
- `{generatedSources}`:  directory for generated source output
- `{classpath}` : replaced with a list of jars separated by the filesystem appropriate separator.
""",
            default = {},
        ),
        "stubs_phase": attr.bool(
            doc = "Runs the compiler plugin in kapt stub generation.",
            default = True,
        ),
        "target_embedded_compiler": attr.bool(
            doc = """Plugin was compiled against the embeddable kotlin compiler. These plugins expect shaded kotlinc
            dependencies, and will fail when running against a non-embeddable compiler.""",
            default = False,
        ),
        "_jarjar": attr.label(
            executable = True,
            cfg = "exec",
            default = Label("//third_party:jarjar_runner"),
        ),
        "_kotlin_compiler_reshade_rules": attr.label(
            default = Label("//kotlin/internal/jvm:kotlin-compiler-reshade.jarjar"),
            allow_single_file = True,
        ),
    },
    implementation = _kt_compiler_plugin_impl,
    provides = [_KtCompilerPluginInfo],
)

kt_ksp_plugin = rule(
    doc = """\
Define a KSP plugin for the Kotlin compiler to run. The plugin can then be referenced in the `plugins` attribute
of the `kt_jvm_*` and `kt_android_*` rules.

An example can be found under `//examples/ksp`:

```bzl
kt_ksp_plugin(
    name = "moshi-kotlin-codegen",
    processor_class = "com.squareup.moshi.kotlin.codegen.ksp.JsonClassSymbolProcessorProvider",
    deps = [
        "@maven//:com_squareup_moshi_moshi",
        "@maven//:com_squareup_moshi_moshi_kotlin",
        "@maven//:com_squareup_moshi_moshi_kotlin_codegen",
    ],
)

kt_jvm_library(
    name = "lib",
    srcs = glob(["*.kt"]),
    plugins = ["//:moshi-kotlin-codegen"],
)
```
""",
    attrs = {
        "deps": attr.label_list(
            doc = "The list of libraries to be added to the compiler's plugin classpath",
            providers = [JavaInfo],
            cfg = "exec",
            aspects = [_kt_compiler_deps_aspect],
        ),
        "generates_java": attr.bool(
            doc = """Runs Java compilation action for plugin generating Java output.""",
            default = False,
        ),
        "options": attr.string_dict(
            doc = """Processor options passed to the KSP processor via SymbolProcessorEnvironment.options.
            Each entry is a key-value pair available to the processor at processing time.""",
            default = {},
        ),
        "processor_class": attr.string(
            doc = " The fully qualified class name that the Java compiler uses as an entry point to the annotation processor.",
            mandatory = True,
        ),
        "target_embedded_compiler": attr.bool(
            doc = """Plugin was compiled against the embeddable kotlin compiler. These plugins expect shaded kotlinc
            dependencies, and will fail when running against a non-embeddable compiler.""",
            default = False,
        ),
        "_kotlin_compiler_reshade_rules": attr.label(
            default = Label("//kotlin/internal/jvm:kotlin-compiler-reshade.jarjar"),
            allow_single_file = True,
        ),
    },
    implementation = _kt_ksp_plugin_impl,
    provides = [_KspPluginInfo],
)

kt_plugin_cfg = rule(
    implementation = kt_plugin_cfg_impl,
    doc = """
    Configurations for kt_compiler_plugin.

    This allows setting options and dependencies independently from the initial plugin definition.
    """,
    attrs = {
        "data": attr.label_list(
            doc = "The list of data files to be used by compiler's plugin",
            providers = [DefaultInfo],
            cfg = "exec",
        ),
        "deps": attr.label_list(
            doc = "Dependencies for this configuration.",
            providers = [
                [_KspPluginInfo],
                [JavaInfo],
                [JavaPluginInfo],
            ],
            cfg = "exec",
        ),
        "options": attr.string_list_dict(
            doc = "A dictionary of flag to values to be used as plugin configuration options.",
        ),
        "plugin": attr.label(
            doc = "The plugin to associate with this configuration",
            providers = [_KtCompilerPluginInfo],
            mandatory = True,
        ),
    },
)

attrs = struct(
    lib_common_attr = _lib_common_attr,
    runnable_common_attr = _runnable_common_attr,
)
