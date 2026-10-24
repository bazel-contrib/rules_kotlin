"""Tests for the jdeps passed to KotlinBuilder."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:truth.bzl", "matching")
load("//src/test/starlark:case.bzl", "suite")
load(":arrangement.bzl", "arrange")
load(":util.bzl", "basename_of", "values_for_flag_of")

_REPORT_UNUSED_DEPS_TOOLCHAIN = str(Label("@rules_kotlin//src/test/starlark/rules:report_unused_deps_toolchain"))
_REDUCED_CLASSPATH_TOOLCHAIN = str(Label("@rules_kotlin//src/test/starlark/rules:reduced_classpath_toolchain"))

def _config_settings(toolchain):
    return {
        str(Label("@rules_kotlin//kotlin/settings:experimental_prune_transitive_deps")): True,
        str(Label("@rules_kotlin//kotlin/settings:experimental_prune_transitive_deps_keep_transitive_repositories")): [],
        str(Label("@rules_kotlin//kotlin/settings:experimental_strict_associate_dependencies")): False,
        "//command_line_option:extra_toolchains": [toolchain],
    }

def _deps_artifacts_absent_assertions(env, target):
    action = env.expect.that_target(target).action_named("KotlinCompile")
    dependency_jdeps = "%s_dependency_a.jdeps" % env.ctx.attr.namespace

    action.inputs().not_contains_predicate(matching.file_basename_equals(dependency_jdeps))
    values_for_flag_of(action, "--deps_artifacts").contains_exactly([])

    jdeps_merge = env.expect.that_target(target).action_named("JdepsMerge")
    values_for_flag_of(jdeps_merge, "--report_unused_deps").contains_exactly(["warn"])

def _deps_artifacts_present_assertions(env, target):
    action = env.expect.that_target(target).action_named("KotlinCompile")
    dependency_jdeps = "%s_dependency_a.jdeps" % env.ctx.attr.namespace

    action.inputs().contains_at_least_predicates([
        matching.file_basename_equals(dependency_jdeps),
    ])
    values_for_flag_of(action, "--deps_artifacts").transform(
        desc = "basenames",
        map_each = basename_of,
    ).contains_exactly([dependency_jdeps])

def _make_deps_artifacts_test(toolchain, assertions):
    def _case(test):
        (_, _dependency_a, main_target_library) = arrange(test)

        analysis_test(
            name = test.name,
            impl = assertions,
            target = main_target_library,
            config_settings = _config_settings(toolchain),
            attr_values = {
                "namespace": test.name,
            },
            attrs = {
                "namespace": attr.string(),
            },
        )

    return _case

def deps_artifacts_tests(name):
    suite(
        name,
        default_mode = _make_deps_artifacts_test(_REPORT_UNUSED_DEPS_TOOLCHAIN, _deps_artifacts_absent_assertions),
        reduced_mode = _make_deps_artifacts_test(_REDUCED_CLASSPATH_TOOLCHAIN, _deps_artifacts_present_assertions),
    )
