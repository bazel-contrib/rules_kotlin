"""Tests for the dialect-aware selection of the kt_compiler_plugin classpath.

The plugin classpath must match the dialect of the compiler that runs the plugin: a matching
dialect loads the original jars, a mismatched dialect loads the jars reshaded to the compiler
dialect. The compiler dialect follows the invocation: the legacy invocation runs the CLI
distribution, and the Build Tools API invocation always runs the embeddable compiler, because
the official Build Tools API implementation assumes the embeddable compiler.
"""

load("@rules_java//java:defs.bzl", "java_import")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("//kotlin:core.bzl", "kt_compiler_plugin")
load("//src/test/starlark:case.bzl", "suite")

_BUILD_TOOLS_API_SETTING = str(Label("@rules_kotlin//kotlin/settings:experimental_build_tools_api"))

_ATTRS = {
    "want_basenames": attr.string_list(),
}

def _plugin_classpath_assertion(env, target):
    env.expect.that_collection(
        [f.basename for f in target[DefaultInfo].files.to_list()],
    ).contains_exactly(env.ctx.attr.want_basenames)

def _make_dialect_test(target_embedded_compiler, build_tools_api, want_infix):
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

        analysis_test(
            name = test.name,
            impl = _plugin_classpath_assertion,
            target = plugin,
            config_settings = {_BUILD_TOOLS_API_SETTING: build_tools_api},
            attr_values = {"want_basenames": want},
            attrs = _ATTRS,
        )

    return _case

def plugin_dialect_tests(name):
    suite(
        name,
        embedded_plugin_reshades_for_the_legacy_invocation = _make_dialect_test(
            target_embedded_compiler = True,
            build_tools_api = False,
            want_infix = "reshaded",
        ),
        embedded_plugin_stays_original_on_the_build_tools_api = _make_dialect_test(
            target_embedded_compiler = True,
            build_tools_api = True,
            want_infix = None,
        ),
        plain_plugin_reshades_for_the_build_tools_api = _make_dialect_test(
            target_embedded_compiler = False,
            build_tools_api = True,
            want_infix = "embeddable_reshaded",
        ),
        plain_plugin_stays_original_on_the_legacy_invocation = _make_dialect_test(
            target_embedded_compiler = False,
            build_tools_api = False,
            want_infix = None,
        ),
    )
