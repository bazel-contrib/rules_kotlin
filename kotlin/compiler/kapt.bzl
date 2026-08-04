"""Defines kapt plugin rule."""

load("@rules_java//java/common:java_common.bzl", "java_common")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("@rules_java//java/common:java_plugin_info.bzl", "JavaPluginInfo")
load("//src/main/starlark/core/options:opts.javac.bzl", "JavacOptions")
load("//src/main/starlark/core/plugin:common.bzl", "plugin_common")
load(
    "//src/main/starlark/core/plugin:providers.bzl",
    "KtCompilerPluginInfo",
    "KtCompilerPluginOption",
    "KtPluginConfiguration",
)

def _resolve_kapt_cfg(
        info,
        option_string_list_dict,
        deps,
        expand_location):  # @unused Needed for lambda contract.
    infos = []
    plugins = []
    for d in deps:
        if JavaInfo in d:
            infos.append(d[JavaInfo])
        if JavaPluginInfo in d:
            # mild chicanary to turn a JavaPluginInfo in to a JavaInfo.
            # This is necessary to merge all the java related things into a single JavaInfo
            # that exports all plugins. It would be easier if there was a way to
            # generate JavaInfo without an output_jar.
            jpi = d[JavaPluginInfo]
            for o in jpi.java_outputs:
                infos.append(
                    JavaInfo(
                        output_jar = o.class_jar,
                        compile_jar = o.compile_jar,
                        exported_plugins = [jpi],
                    ),
                )

    ji = java_common.merge(infos)
    classpath = depset(ji.runtime_output_jars, transitive = [ji.transitive_runtime_jars])
    data = None
    data_runfiles = [d[DefaultInfo].default_runfiles for d in deps if d[DefaultInfo]]
    if data_runfiles:
        data = data_runfiles[0].merge_all(data_runfiles[1:])
    return [
        ji,  # allows java compilation to pick up the annotation processor.
        JavacOptions(
            annotation_processor_options = {
                k: v
                for (k, vs) in option_string_list_dict.items()
                for v in vs
            },
        ),
        KtPluginConfiguration(
            id = info.id,
            options = [
                KtCompilerPluginOption(
                    id = info.id,
                    value = "apoption=%s:%s" % (k, v),
                )
                for (k, vs) in option_string_list_dict.items()
                for v in vs
            ],
            classpath = classpath,
            data = data,
        ),
    ] + plugins

def _kapt_compiler_plugin_impl(ctx):
    plugin_id = ctx.attr.id
    return [
        KtCompilerPluginInfo(
            id = plugin_id,
            classpath = depset(),
            options = [],
            stubs = True,
            compile = False,
            resolve_cfg = _resolve_kapt_cfg,
            merge_cfgs = plugin_common.merge_cfgs,
        ),
    ]

kapt_compiler_plugin = rule(
    implementation = _kapt_compiler_plugin_impl,
    attrs = {
        "id": attr.string(default = "org.jetbrains.kotlin.kapt3"),
    },
)
