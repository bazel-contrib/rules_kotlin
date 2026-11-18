"""Tests that the unused deps check runs for targets that are only built as dependencies."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:truth.bzl", "matching")
load("//src/test/starlark:case.bzl", "suite")
load(":arrangement.bzl", "arrange")

_TOOLCHAINS = {
    "error": str(Label("@rules_kotlin//src/test/starlark/rules:report_unused_deps_error_toolchain")),
    "warn": str(Label("@rules_kotlin//src/test/starlark/rules:report_unused_deps_toolchain")),
}

def _config_settings(report_unused_deps):
    if report_unused_deps == "off":
        return {}
    return {"//command_line_option:extra_toolchains": [_TOOLCHAINS[report_unused_deps]]}

def _jdeps_basename(target):
    return matching.file_basename_equals(target.label.name + ".jdeps")

def _jdeps_validated(env, targets):
    for target in [targets.main, targets.dep]:
        env.expect.that_target(target).output_group("_validation").contains_predicate(_jdeps_basename(target))

def _jdeps_not_validated(env, targets):
    for target in [targets.main, targets.dep]:
        env.expect.that_target(target).output_group("_validation").not_contains_predicate(_jdeps_basename(target))

def _analyze(test, impl, report_unused_deps):
    (_, dependency_a, main_target_library) = arrange(test)
    analysis_test(
        name = test.name,
        impl = impl,
        targets = {
            "dep": dependency_a,
            "main": main_target_library,
        },
        config_settings = _config_settings(report_unused_deps),
    )

def _test_error_validates_jdeps(test):
    """With "error", the target and its dependency both validate their jdeps.

    So a dependency's unused deps fail the build even when only the dependent is requested.
    """
    _analyze(test, _jdeps_validated, "error")

def _test_warn_adds_no_validation(test):
    """"warn" never fails the build, so it does not force a JdepsMerge on the target or its dependencies."""
    _analyze(test, _jdeps_not_validated, "warn")

def _test_off_adds_no_validation(test):
    """With the check off, no extra JdepsMerge work is forced on dependencies."""
    _analyze(test, _jdeps_not_validated, "off")

def jdeps_validation_tests(name):
    suite(
        name,
        error_validates_jdeps = _test_error_validates_jdeps,
        warn_adds_no_validation = _test_warn_adds_no_validation,
        off_adds_no_validation = _test_off_adds_no_validation,
    )
