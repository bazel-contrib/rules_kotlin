"""Providers for Kotlin compiler plugins."""

# buildifier: disable=name-conventions
KtCompilerPluginOption = provider(
    doc = "A single id/value option passed to a Kotlin compiler plugin.",
    fields = {
        "key": "The option key.",
        "value": "The option value.",
    },
)

KtCompilerPluginInfo = provider(
    doc = "Describes a Kotlin compiler plugin.",
    fields = {
        "classpath": "The kotlin compiler plugin classpath.",
        "compile": "Run this plugin during koltinc compilation.",
        "data": "Depset of files the plugin reads at compile time; they are compilation inputs.",
        "id": "The id of the plugin.",
        "merge_cfgs": "A Callable[[KtCompilerPluginInfo, List[KtPluginConfiguration]]] that merge multiple plugin configurations.",
        "options": "List of plugin options, represented as KtCompilerPluginOption, to be passed to the compiler",
        "plugin_jars": "List of plugin jars.",
        "resolve_cfg": "A Callable[[KtCompilerPluginInfo, Dict[str, List[str]], List[Target], Callable[[str], str], List[File]]" +
                       " that resolves an associated plugin configuration; the last argument holds configuration data files.",
        "stubs": "Run this plugin during kapt stub generation.",
    },
)

# buildifier: disable=name-conventions
KtPluginConfiguration = provider(
    doc = "Resolved configuration (classpath, data, options) for a Kotlin compiler plugin.",
    fields = {
        "classpath": "Depset of jars to add to the classpath when running the plugin.",
        "data": "Depset of files the plugin reads at compile time: the configuration data files and its dependencies runfiles." +
                " They are compilation inputs.",
        "id": "The id of the compiler plugin associated with this configuration.",
        "options": "List of plugin options, represented KtCompilerPluginOption",
    },
)

KspPluginInfo = provider(
    doc = "Describes a KSP plugin: its Java plugins, processor options and Java-generation flag.",
    fields = {
        "generates_java": "Runs Java compilation action for this plugin",
        "options": "Dict of processor options (key-value strings) passed to KSP via environment.options",
        "plugins": "List of JavaPluginInfo providers for the plugins to run with KSP",
    },
)
