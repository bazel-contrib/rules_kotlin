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
"""Rule implementations for Kotlin/JVM rules."""

load("@rules_java//java:defs.bzl", "JavaInfo", "JavaPluginInfo", "java_common")
load(
    "//kotlin/internal:defs.bzl",
    _KspPluginInfo = "KspPluginInfo",
    _KtCompilerPluginInfo = "KtCompilerPluginInfo",
    _KtJvmInfo = "KtJvmInfo",
    _TOOLCHAIN_TYPE = "TOOLCHAIN_TYPE",
)
load(
    "//kotlin/internal/jvm:pipelines.bzl",
    _BINARY_PROCESSING_PIPELINE = "BINARY_PROCESSING_PIPELINE",
    _LIBRARY_PROCESSING_PIPELINE = "LIBRARY_PROCESSING_PIPELINE",
    _TEST_PROCESSING_PIPELINE = "TEST_PROCESSING_PIPELINE",
)
load(
    "//kotlin/internal/utils:utils.bzl",
    _utils = "utils",
)
load(
    "//src/main/starlark/core/pipeline:pipeline.bzl",
    _processing_pipeline = "processing_pipeline",
)
load("//src/main/starlark/core/plugin:common.bzl", "plugin_common")
load("//third_party:jarjar.bzl", "jarjar_action")

# buildifier: disable=unused-variable
def _is_source_jar_stub(jar):
    """Workaround for intellij plugin expecting a source jar"""
    return jar.path.endswith("third_party/empty.jar")

def _unify_jars(ctx):
    if bool(ctx.attr.jar):
        return struct(class_jar = ctx.file.jar, source_jar = ctx.file.srcjar, ijar = None)
    else:
        # Legacy handling.
        jars = []
        source_jars = []
        if (ctx.file.srcjar and not ("%s" % ctx.file.srcjar.path).endswith("third_party/empty.jar")):
            source_jars.append(ctx.file.srcjar)

        # There must be a single jar jar and it can either be a filegroup or a JavaInfo.
        for jar in ctx.attr.jars:
            # If a JavaInfo is available it's because it was picked up from a `maven_jar` style attribute -- e.g.,
            # @com_google_guava_guava//jar. so the transitive_compile_jars or the transitive_runtime_jars should not be
            # visited -- descending into these results in ijars entering the graph.
            if JavaInfo in jar:
                jars += jar[JavaInfo].full_compile_jars.to_list()
                source_jars += jar[JavaInfo].transitive_source_jars.to_list()
            else:
                # this branch occurs when the attr was a filegroup.
                for file in jar.files.to_list():
                    if file.basename.endswith("-sources.jar"):
                        source_jars.append(file)
                    elif file.basename.endswith(".jar"):
                        jars.append(file)
                    else:
                        fail("a jar pointing to a filegroup must either end with -sources.jar or .jar: %s", file)

        if len(jars) > 1:
            fail("Got more than one jar, this is an error create an issue: %s" % jars)
        if len(source_jars) > 1:
            fail("Got more than one source jar. " +
                 "Did you include both srcjar and a sources jar in the jars attribute?: %s" % source_jars)
        return struct(class_jar = jars[0], source_jar = source_jars[0] if len(source_jars) == 1 else None, ijar = None)

def kt_jvm_import_impl(ctx):
    """Implements the kt_jvm_import rule.

    Args:
        ctx: the rule context providing the imported jar attributes.

    Returns:
        The list of providers exposing the imported jars.
    """
    if bool(ctx.attr.jars) and bool(ctx.attr.jar):
        fail("Cannot use both jars= and jar= attribute.  Prefer jar=")

    artifact = _unify_jars(ctx)
    kt_info = _KtJvmInfo(
        module_name = _utils.derive_module_name(ctx),
        module_jars = [],
        exported_compiler_plugins = depset(getattr(ctx.attr, "exported_compiler_plugins", [])),
        outputs = struct(
            jars = [artifact],
        ),
    )

    return [
        DefaultInfo(
            files = depset(direct = [artifact.class_jar]),
            runfiles = ctx.runfiles(
                # Append class jar with the optional sources jar
                files = [artifact.class_jar] + [artifact.source_jar] if artifact.source_jar else [],
            ).merge_all([d[DefaultInfo].default_runfiles for d in ctx.attr.deps]),
        ),
        JavaInfo(
            output_jar = artifact.class_jar,
            compile_jar = artifact.class_jar,
            source_jar = artifact.source_jar,
            runtime_deps = [dep[JavaInfo] for dep in ctx.attr.runtime_deps if JavaInfo in dep],
            deps = [dep[JavaInfo] for dep in ctx.attr.deps if JavaInfo in dep],
            exports = [d[JavaInfo] for d in getattr(ctx.attr, "exports", [])],
            neverlink = getattr(ctx.attr, "neverlink", False),
        ),
        kt_info,
    ]

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
        pipeline = _LIBRARY_PROCESSING_PIPELINE,
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
        pipeline = _BINARY_PROCESSING_PIPELINE,
    )

def kt_jvm_junit_test_impl(ctx):
    """Implements the kt_jvm_test rule for JUnit tests.

    Args:
        ctx: the rule context providing the test sources, deps, and test runner.

    Returns:
        The list of providers producing the runnable JUnit test.
    """
    return _processing_pipeline.run(
        ctx = ctx,
        java_package = None,
        pipeline = _TEST_PROCESSING_PIPELINE,
    )

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
    ] + plugin.resolve_cfg(plugin, ctx.attr.options, ctx.attr.deps, _expand_location_with_data_deps(ctx))

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
