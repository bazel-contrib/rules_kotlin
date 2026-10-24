"""Utilities for resolving compiler plugin configurations."""

load("@rules_java//java/common:java_common.bzl", "java_common")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load(":providers.bzl", "KtCompilerPluginOption", "KtPluginConfiguration")

def _resolve_plugin_cfg(info, options, deps, expand_location, data = []):
    """Resolves a plugin config.

    Args:
        info: KtCompilerPluginInfo of the plugin configuration.
        options: Dict[str, List[str]] of options from kt_plugin_cfg
        deps: List[Target] from kt_plugin_cfg
        expand_location: Callable[str]str to expand any target references, from ctx.expand_location
        data: List[File] from kt_plugin_cfg; the files an option value names through $(location).
    Return:
        List[Provider] of providers.
    """
    ji = java_common.merge([dep[JavaInfo] for dep in deps if JavaInfo in dep])
    classpath = depset(ji.runtime_output_jars, transitive = [ji.transitive_runtime_jars])

    # The compilation gets the data files and the runfiles of the dependencies as inputs.
    data_files = depset(
        data,
        transitive = [dep[DefaultInfo].default_runfiles.files for dep in deps],
    )
    return [
        KtPluginConfiguration(
            id = info.id,
            options = _resolve_plugin_options(options, expand_location),
            classpath = classpath,
            data = data_files,
        ),
    ]

def _merge_plugin_cfgs(info, cfgs):
    classpath = depset(transitive = [cfg.classpath for cfg in cfgs])
    options = [o for cfg in cfgs for o in cfg.options]
    return KtPluginConfiguration(
        id = info.id,
        options = options,
        classpath = classpath,
        data = depset(transitive = [cfg.data for cfg in cfgs]),
    )

def _resolve_plugin_options(string_list_dict, expand_location):
    """
    Resolves plugin options from a string dict to a dict of strings.

    Args:
        string_list_dict: a dict of list[string].
        expand_location:
    Returns:
        list of KtCompilerPluginOption
    """
    options = []
    for (k, vs) in string_list_dict.items():
        for v in vs:
            if "=" in k:
                fail("kotlin compiler option keys cannot contain the = symbol")
            options.append(KtCompilerPluginOption(
                key = k,
                value = expand_location(v) if v else "",
            ))
    return options

plugin_common = struct(
    resolve_cfg = _resolve_plugin_cfg,
    merge_cfgs = _merge_plugin_cfgs,
    resolve_plugin_options = _resolve_plugin_options,
)
