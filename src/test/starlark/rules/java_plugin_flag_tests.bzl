"""Tests for the `--plugin` flag on the Java half of a mixed target.

The Java compilation receives the javac plugins of the flag, as `java_library` does. The
plugins of the flag are not annotation processors for the Kotlin stubs: kapt stays off, and the
Kotlin compilation does not carry them.
"""

load("@rules_java//java:defs.bzl", "java_import", "java_plugin")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:truth.bzl", "matching")
load("@rules_testing//lib:util.bzl", "TestingAspectInfo")
load("//kotlin:jvm.bzl", "kt_jvm_library")
load("//src/test/starlark:case.bzl", "suite")
load(":util.bzl", "basename_of", "values_for_flag_of")

_ATTRS = {
    "plugin_jar": attr.string(),
}

def _canonical_label(relative_label):
    return str(Label("//%s%s" % (native.package_name(), relative_label)))

def _mnemonics(target):
    return [action.mnemonic for action in target[TestingAspectInfo].actions]

def _processorpath_basenames(action):
    return values_for_flag_of(action, "--processorpath").transform(
        desc = "basenames of --processorpath",
        map_each = basename_of,
    )

def _mixed_target_assertion(env, target):
    subject = env.expect.that_target(target)
    plugin_jar = env.ctx.attr.plugin_jar

    _processorpath_basenames(subject.action_named("Javac")).contains(plugin_jar)

    kotlin_compile = subject.action_named("KotlinCompile")
    _processorpath_basenames(kotlin_compile).not_contains(plugin_jar)
    kotlin_compile.inputs().not_contains_predicate(matching.file_basename_equals(plugin_jar))
    env.expect.that_collection(_mnemonics(target)).not_contains("KotlinKapt")

def _kotlin_only_target_assertion(env, target):
    mnemonics = env.expect.that_collection(_mnemonics(target))
    mnemonics.not_contains("Javac")
    mnemonics.not_contains("KotlinKapt")

def _make_plugin_flag_test(assertion, with_java):
    def _case(test):
        dep_jar = test.artifact(name = "plugin_dep.jar")
        dep = test.have(
            java_import,
            name = "plugin_dep",
            jars = [dep_jar],
        )
        plugin = test.have(
            java_plugin,
            name = "plugin",
            deps = [dep],
        )

        srcs = [test.artifact(name = "Lib.kt")]
        if with_java:
            srcs.append(test.artifact(name = "Aux.java"))
        library = test.got(
            kt_jvm_library,
            name = "library",
            srcs = srcs,
        )

        analysis_test(
            name = test.name,
            impl = assertion,
            target = library,
            config_settings = {"//command_line_option:plugin": [_canonical_label(plugin)]},
            attr_values = {"plugin_jar": test.name + "_plugin_dep.jar"},
            attrs = _ATTRS,
        )

    return _case

def java_plugin_flag_tests(name):
    suite(
        name,
        javac_receives_the_plugins_of_the_flag = _make_plugin_flag_test(
            _mixed_target_assertion,
            with_java = True,
        ),
        kotlin_only_target_has_no_javac_action = _make_plugin_flag_test(
            _kotlin_only_target_assertion,
            with_java = False,
        ),
    )
