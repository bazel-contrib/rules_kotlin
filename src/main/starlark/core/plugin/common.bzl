"""Utilities for resolving compiler plugin configurations."""

load("@rules_java//java/common:java_common.bzl", "java_common")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load(":providers.bzl", "KtCompilerPluginOption", "KtPluginConfiguration")

def _resolve_plugin_cfg(info, options, deps, expand_location):
    """Resolves a plugin config.

    Args:
        info: KtCompilerPluginInfo of the plugin configuration.
        options: Dict[str, List[str]] of options from kt_plugin_cfg
        deps: List[Target] from kt_plugin_cfg
        expand_location: Callable[str]str to expand any target references, from ctx.expand_location
    Return:
        List[Provider] of providers.
    """
    ji = java_common.merge([dep[JavaInfo] for dep in deps if JavaInfo in dep])
    classpath = depset(ji.runtime_output_jars, transitive = [ji.transitive_runtime_jars])
    data = None
    data_runfiles = [d[DefaultInfo].default_runfiles for d in deps if d[DefaultInfo]]
    if data_runfiles:
        data = data_runfiles[0].merge_all(data_runfiles[1:])
    return [
        KtPluginConfiguration(
            id = info.id,
            options = _resolve_plugin_options(info.id, options, expand_location),
            classpath = classpath,
            data = data,
        ),
    ]

def _merge_plugin_cfgs(info, cfgs):
    classpath = depset(transitive = [cfg.classpath for cfg in cfgs])
    options = [o for cfg in cfgs for o in cfg.options]
    return KtPluginConfiguration(
        id = info.id,
        options = options,
        classpath = classpath,
        data = depset(),
    )

def _resolve_plugin_options(id, string_list_dict, expand_location):
    """
    Resolves plugin options from a string dict to a dict of strings.

    Args:
        id: the plugin id
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
            value = k + "=" + expand_location(v) if v else k
            options.append(KtCompilerPluginOption(id = id, value = value))
    return options

plugin_common = struct(
    resolve_cfg = _resolve_plugin_cfg,
    merge_cfgs = _merge_plugin_cfgs,
    resolve_plugin_options = _resolve_plugin_options,
)
