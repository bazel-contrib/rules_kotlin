"""Tests that the unused deps check runs for targets that are only built as dependencies."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:truth.bzl", "matching")
load("//src/test/starlark:case.bzl", "suite")
load(":arrangement.bzl", "arrange")

_REPORT_UNUSED_DEPS_TOOLCHAIN = str(Label("@rules_kotlin//src/test/starlark/rules:report_unused_deps_toolchain"))

def _config_settings(report_unused_deps):
    if not report_unused_deps:
        return {}
    return {"//command_line_option:extra_toolchains": [_REPORT_UNUSED_DEPS_TOOLCHAIN]}

def _jdeps_in_validation(env, target):
    env.expect.that_target(target).output_group("_validation").contains_predicate(
        matching.file_basename_equals(target.label.name + ".jdeps"),
    )

def _jdeps_not_in_validation(env, target):
    env.expect.that_target(target).output_group("_validation").not_contains_predicate(
        matching.file_basename_equals(target.label.name + ".jdeps"),
    )

def _test_report_unused_deps_validates_jdeps(test):
    """With unused deps reported, the jdeps file is a validation output, not only a default output."""
    (_, _, main_target_library) = arrange(test)

    analysis_test(
        name = test.name,
        impl = _jdeps_in_validation,
        target = main_target_library,
        config_settings = _config_settings(report_unused_deps = True),
    )

def _test_report_unused_deps_off_adds_no_validation(test):
    """With the check off, no extra JdepsMerge work is forced on dependencies."""
    (_, _, main_target_library) = arrange(test)

    analysis_test(
        name = test.name,
        impl = _jdeps_not_in_validation,
        target = main_target_library,
        config_settings = _config_settings(report_unused_deps = False),
    )

def jdeps_validation_tests(name):
    suite(
        name,
        jdeps_validated = _test_report_unused_deps_validates_jdeps,
        jdeps_not_validated_when_off = _test_report_unused_deps_off_adds_no_validation,
    )
