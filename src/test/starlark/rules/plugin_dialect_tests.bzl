"""Tests for the dialect-aware selection of the kt_compiler_plugin classpath.

The plugin classpath must match the dialect of the compiler that runs the plugin: a matching
dialect loads the original jars, a mismatched dialect loads the jars reshaded to the compiler
dialect. The compiler dialect follows the toolchain: the CLI distribution by default, the
embeddable dialect when the toolchain runs the Build Tools API with btapi_embedded_compiler.
"""

load("@rules_java//java:defs.bzl", "java_import")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("//kotlin:core.bzl", "kt_compiler_plugin")
load("//src/test/starlark:case.bzl", "suite")

_EMBEDDABLE_RUNTIME_TOOLCHAIN = str(Label("@rules_kotlin//src/test/starlark/rules:embeddable_runtime_toolchain"))

_ATTRS = {
    "want_basenames": attr.string_list(),
}

def _plugin_classpath_assertion(env, target):
    env.expect.that_collection(
        [f.basename for f in target[DefaultInfo].files.to_list()],
    ).contains_exactly(env.ctx.attr.want_basenames)

def _make_dialect_test(target_embedded_compiler, embeddable_runtime, want_infix):
    def _case(test):
        dep_jar = test.artifact(name = "plugin_dep.jar")
        dep = test.have(
            java_import,
            name = "plugin_dep_lib",
            jars = [dep_jar],
        )
        plugin = test.got(
            kt_compiler_plugin,
            name = "plugin",
            id = "test.dialect." + test.name,
            target_embedded_compiler = target_embedded_compiler,
            deps = [dep],
        )

        dep_jar_basename = test.name + "_plugin_dep.jar"
        if want_infix:
            want = ["%s_plugin_dep_lib_%s_%s" % (test.name, want_infix, dep_jar_basename)]
        else:
            want = [dep_jar_basename]

        config_settings = {}
        if embeddable_runtime:
            config_settings = {
                "//command_line_option:extra_toolchains": [_EMBEDDABLE_RUNTIME_TOOLCHAIN],
            }

        analysis_test(
            name = test.name,
            impl = _plugin_classpath_assertion,
            target = plugin,
            config_settings = config_settings,
            attr_values = {"want_basenames": want},
            attrs = _ATTRS,
        )

    return _case

def plugin_dialect_tests(name):
    suite(
        name,
        embedded_plugin_reshades_for_the_default_compiler = _make_dialect_test(
            target_embedded_compiler = True,
            embeddable_runtime = False,
            want_infix = "reshaded",
        ),
        embedded_plugin_stays_original_on_the_embeddable_compiler = _make_dialect_test(
            target_embedded_compiler = True,
            embeddable_runtime = True,
            want_infix = None,
        ),
        plain_plugin_reshades_for_the_embeddable_compiler = _make_dialect_test(
            target_embedded_compiler = False,
            embeddable_runtime = True,
            want_infix = "embeddable_reshaded",
        ),
        plain_plugin_stays_original_on_the_default_compiler = _make_dialect_test(
            target_embedded_compiler = False,
            embeddable_runtime = False,
            want_infix = None,
        ),
    )
