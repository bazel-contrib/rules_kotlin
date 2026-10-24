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
"""Kotlin compiler plugin rules and implementations."""

load(
    "@rules_java//java:defs.bzl",
    "JavaInfo",
    "java_common",
)
load("@rules_java//java/common:java_plugin_info.bzl", "JavaPluginInfo")
load(
    "//kotlin/internal:defs.bzl",
    _KspPluginInfo = "KspPluginInfo",
    _KtCompilerPluginInfo = "KtCompilerPluginInfo",
    _TOOLCHAIN_TYPE = "TOOLCHAIN_TYPE",
)
load("//src/main/starlark/core/plugin:common.bzl", "plugin_common")
load("//third_party:jarjar.bzl", "jarjar_action")

_KtCompilerPluginClasspathInfo = provider(
    doc = "JavaInfos of a Kotlin compiler plugin library and its reshaded variants.",
    fields = {
        "infos": "list JavaInfos of a compiler library",
        "reshaded_infos": "list JavaInfos of a compiler library, reshaded to the CLI-distribution compiler dialect",
        "reshaded_infos_embeddable": "list JavaInfos of a compiler library, reshaded to the embeddable compiler dialect",
    },
)

def kt_compiler_deps_aspect_impl(target, ctx):
    """
    Collects and reshades (if necessary) all jars in the plugin transitive closure.

    Args:
        target: Target of the rule being inspected
        ctx: aspect ctx
    Returns:
        list of _KtCompilerPluginClasspathInfo
    """
    transitive_infos = [
        t[_KtCompilerPluginClasspathInfo]
        for d in ["deps", "runtime_deps", "exports"]
        for t in getattr(ctx.rule.attr, d, [])
        if _KtCompilerPluginClasspathInfo in t
    ]
    reshaded_infos = []
    reshaded_infos_embeddable = []
    infos = [
        i
        for t in transitive_infos
        for i in t.infos
    ]
    if JavaInfo in target:
        ji = target[JavaInfo]
        infos.append(ji)
        reshaded_infos.append(
            _reshade_kotlinc_jars(
                target = target,
                ctx = ctx,
                rules_file = ctx.file._kotlin_compiler_reshade_rules,
                output_infix = "reshaded",
                jars = ji.runtime_output_jars,
                deps = [
                    i
                    for t in transitive_infos
                    for i in t.reshaded_infos
                ],
            ),
        )
        reshaded_infos_embeddable.append(
            _reshade_kotlinc_jars(
                target = target,
                ctx = ctx,
                rules_file = ctx.file._kotlin_compiler_embeddable_reshade_rules,
                output_infix = "embeddable_reshaded",
                jars = ji.runtime_output_jars,
                deps = [
                    i
                    for t in transitive_infos
                    for i in t.reshaded_infos_embeddable
                ],
            ),
        )

    return [
        _KtCompilerPluginClasspathInfo(
            infos = [java_common.merge(infos)],
            reshaded_infos = reshaded_infos,
            reshaded_infos_embeddable = reshaded_infos_embeddable,
        ),
    ]

def _reshade_kotlinc_jars(target, ctx, rules_file, output_infix, jars, deps):
    # No jars to reshade — just propagate transitive deps (e.g. sourceless libraries).
    if not jars:
        return java_common.merge(deps) if deps else java_common.merge([])

    reshaded = [
        jarjar_action(
            actions = ctx.actions,
            jarjar = ctx.executable._jarjar,
            rules = rules_file,
            input = jar,
            output = ctx.actions.declare_file(
                "%s_%s_%s" % (target.label.name, output_infix, jar.basename),
            ),
        )
        for jar in jars
    ]

    # JavaInfo only takes a single jar, so create many and merge them.
    return java_common.merge(
        [
            JavaInfo(output_jar = jar, compile_jar = jar, deps = deps)
            for jar in reshaded
        ],
    )

def _expand_location_with_data_deps(ctx):
    return lambda targets: ctx.expand_location(targets, ctx.attr.data)

def _runs_embedded_compiler(ctx):
    """Tells whether the compilation actions run the embeddable compiler dialect.

    The legacy invocation runs the CLI distribution; the Build Tools API invocation runs the
    embeddable compiler. Without a resolved toolchain the selection keeps the CLI-distribution
    dialect.
    """
    toolchain = ctx.toolchains[_TOOLCHAIN_TYPE]
    return toolchain != None and toolchain.experimental_build_tools_api

def kt_compiler_plugin_impl(ctx):
    """Implements the kt_compiler_plugin rule.

    Args:
        ctx: the rule context providing the plugin id, options, and deps.

    Returns:
        The list of providers exposing the compiler plugin configuration.
    """
    plugin_id = ctx.attr.id

    # Select the plugin jars matching the dialect of the compiler that runs them: a matching
    # dialect loads the original jars, a mismatched dialect loads the jars reshaded to the
    # compiler dialect.
    if ctx.attr.target_embedded_compiler:
        field = "infos" if _runs_embedded_compiler(ctx) else "reshaded_infos"
    else:
        field = "reshaded_infos_embeddable" if _runs_embedded_compiler(ctx) else "infos"

    deps = ctx.attr.deps
    info = java_common.merge([
        i
        for d in deps
        for i in getattr(d[_KtCompilerPluginClasspathInfo], field)
    ])

    classpath = depset(info.runtime_output_jars, transitive = [info.transitive_runtime_jars])

    options = plugin_common.resolve_plugin_options(ctx.attr.options, _expand_location_with_data_deps(ctx))

    return [
        DefaultInfo(files = classpath),
        _KtCompilerPluginInfo(
            id = plugin_id,
            classpath = classpath,
            options = options,
            data = depset(ctx.files.data),
            stubs = ctx.attr.stubs_phase,
            compile = ctx.attr.compile_phase,
            resolve_cfg = plugin_common.resolve_cfg,
            merge_cfgs = plugin_common.merge_cfgs,
        ),
    ]

def kt_plugin_cfg_impl(ctx):
    plugin = ctx.attr.plugin[_KtCompilerPluginInfo]
    return [
        plugin,
    ] + plugin.resolve_cfg(plugin, ctx.attr.options, ctx.attr.deps, _expand_location_with_data_deps(ctx), ctx.files.data)

def kt_ksp_plugin_impl(ctx):
    """Implements the kt_ksp_plugin rule.

    Args:
        ctx: the rule context providing the KSP processor deps and options.

    Returns:
        The list of providers exposing the KSP plugin configuration.
    """
    deps = ctx.attr.deps
    if ctx.attr.target_embedded_compiler:
        info = java_common.merge([
            i
            for d in deps
            for i in d[_KtCompilerPluginClasspathInfo].reshaded_infos
        ])
    else:
        info = java_common.merge([dep[JavaInfo] for dep in deps])

    classpath = depset(info.runtime_output_jars, transitive = [info.transitive_runtime_jars])

    return [
        DefaultInfo(files = classpath),
        _KspPluginInfo(
            plugins = [
                JavaPluginInfo(
                    runtime_deps = [
                        info,
                    ],
                    processor_class = ctx.attr.processor_class,
                    # rules_kotlin doesn't support stripping non-api generating annotation
                    # processors out of the public ABI.
                    generates_api = True,
                ),
            ],
            generates_java = ctx.attr.generates_java,
            options = ctx.attr.options,
        ),
    ]

_kt_compiler_deps_aspect = aspect(
    implementation = kt_compiler_deps_aspect_impl,
    attr_aspects = ["deps", "runtime_deps", "exports"],
    attrs = {
        "_jarjar": attr.label(
            executable = True,
            cfg = "exec",
            default = Label("//third_party:jarjar_runner"),
        ),
        "_kotlin_compiler_embeddable_reshade_rules": attr.label(
            default = Label("//kotlin/internal/jvm:kotlin-compiler-embeddable-reshade.jarjar"),
            allow_single_file = True,
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
        "annotation": ["plugin.OpenForTesting"],
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
            doc = """The files the plugin reads at compile time. An option value names one of them as
            `$(location <file>)`. The files are inputs of the compilation.""",
            allow_files = True,
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
        "options": attr.string_list_dict(
            doc = """\
Dictionary of options to be passed to the plugin.
Each option key can have multiple values.
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
            doc = """Plugin was compiled against the embeddable kotlin compiler. The plugin classpath is
            reshaded when this dialect differs from the dialect of the compiler that the toolchain runs.""",
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
    implementation = kt_compiler_plugin_impl,
    provides = [_KtCompilerPluginInfo],
    # Optional: the toolchain tells which compiler dialect runs the plugin. Without a resolved
    # toolchain the selection keeps the CLI-distribution dialect.
    toolchains = [config_common.toolchain_type(_TOOLCHAIN_TYPE, mandatory = False)],
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
    implementation = kt_ksp_plugin_impl,
    provides = [_KspPluginInfo],
)

kt_plugin_cfg = rule(
    implementation = kt_plugin_cfg_impl,
    doc = """
    Configurations for kt_compiler_plugin, ksp_plugin, and java_plugin.

    This allows setting options and dependencies independently from the initial plugin definition.
    """,
    attrs = {
        "data": attr.label_list(
            doc = """The files the plugin reads at compile time. An option value names one of them as
            `$(location <file>)`. The files are inputs of the compilation.""",
            allow_files = True,
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
