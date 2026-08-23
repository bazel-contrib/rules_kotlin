"""Tests for the inputs declared on the JdepsMerge action."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:truth.bzl", "matching")
load("//src/test/starlark:case.bzl", "suite")
load(":arrangement.bzl", "arrange")
load(":util.bzl", "abi_jar_of")

_REPORT_UNUSED_DEPS_TOOLCHAIN = str(Label("@rules_kotlin//src/test/starlark/rules:report_unused_deps_toolchain"))

_ATTRS = {
    "not_want_inputs": attr.label_list(providers = [DefaultInfo], allow_files = True),
    "want_inputs": attr.label_list(providers = [DefaultInfo], allow_files = True),
}

def _jdeps_merge_input_assertions(env, target):
    action = env.expect.that_target(target).action_named("JdepsMerge")

    # Compare by basename: with config_settings the target is analyzed in a transitioned
    # configuration, so the output path prefix differs.
    action.inputs().contains_at_least_predicates([
        matching.file_basename_equals(abi_jar_of(f.basename))
        for f in env.ctx.files.want_inputs
        if not f.basename.endswith("jdeps")
    ])
    for f in env.ctx.files.not_want_inputs:
        if f.basename.endswith("jdeps"):
            continue
        action.inputs().not_contains_predicate(matching.file_basename_equals(abi_jar_of(f.basename)))

def _config_settings(report_unused_deps, prune_transitive_deps = True):
    settings = {
        str(Label("@rules_kotlin//kotlin/settings:experimental_prune_transitive_deps")): prune_transitive_deps,
        str(Label("@rules_kotlin//kotlin/settings:experimental_prune_transitive_deps_keep_transitive_repositories")): [],
        str(Label("@rules_kotlin//kotlin/settings:experimental_strict_associate_dependencies")): False,
    }
    if report_unused_deps:
        settings["//command_line_option:extra_toolchains"] = [_REPORT_UNUSED_DEPS_TOOLCHAIN]
    return settings

def _test_kotlin_only_target_gets_the_compile_classpath(test):
    """A Kotlin only target only needs the jars that can appear in its jdeps.

    Those are the jars on the Kotlin compile classpath, which with
    experimental_prune_transitive_deps is a strict subset of the transitive closure.
    """
    (dependency_a_trans_dep_jar, dependency_a, main_target_library) = arrange(test)

    analysis_test(
        name = test.name,
        impl = _jdeps_merge_input_assertions,
        target = main_target_library,
        config_settings = _config_settings(report_unused_deps = True),
        attr_values = {
            "not_want_inputs": [
                dependency_a_trans_dep_jar,
            ],
            "want_inputs": [
                dependency_a,
            ],
        },
        attrs = _ATTRS,
    )

def _test_target_with_java_sources_gets_the_compile_classpath(test):
    """A mixed Kotlin/Java target gets the pruned Kotlin compile classpath for JdepsMerge."""
    (dependency_a_trans_dep_jar, dependency_a, main_target_library) = arrange(
        test,
        with_java_main = True,
    )

    analysis_test(
        name = test.name,
        impl = _jdeps_merge_input_assertions,
        target = main_target_library,
        config_settings = _config_settings(report_unused_deps = True),
        attr_values = {
            "not_want_inputs": [
                dependency_a_trans_dep_jar,
            ],
            "want_inputs": [
                dependency_a,
            ],
        },
        attrs = _ATTRS,
    )

def _test_report_unused_deps_off_gets_no_jars(test):
    (dependency_a_trans_dep_jar, dependency_a, main_target_library) = arrange(test)

    analysis_test(
        name = test.name,
        impl = _jdeps_merge_input_assertions,
        target = main_target_library,
        config_settings = _config_settings(report_unused_deps = False),
        attr_values = {
            "not_want_inputs": [
                dependency_a,
                dependency_a_trans_dep_jar,
            ],
            "want_inputs": [],
        },
        attrs = _ATTRS,
    )

def _test_mixed_target_without_pruning_gets_transitive_classpath(test):
    """A mixed Kotlin/Java target keeps transitive jars when pruning is disabled."""
    (dependency_a_trans_dep_jar, dependency_a, main_target_library) = arrange(
        test,
        with_java_main = True,
    )

    analysis_test(
        name = test.name,
        impl = _jdeps_merge_input_assertions,
        target = main_target_library,
        config_settings = _config_settings(
            report_unused_deps = True,
            prune_transitive_deps = False,
        ),
        attr_values = {
            "not_want_inputs": [],
            "want_inputs": [
                dependency_a,
                dependency_a_trans_dep_jar,
            ],
        },
        attrs = _ATTRS,
    )

def jdeps_merge_inputs_tests(name):
    suite(
        name,
        kotlin_only = _test_kotlin_only_target_gets_the_compile_classpath,
        with_java_sources = _test_target_with_java_sources_gets_the_compile_classpath,
        report_unused_deps_off = _test_report_unused_deps_off_gets_no_jars,
        pruning_disabled = _test_mixed_target_without_pruning_gets_transitive_classpath,
    )
