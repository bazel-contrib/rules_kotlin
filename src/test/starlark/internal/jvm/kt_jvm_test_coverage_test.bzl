"""Tests for the kt_jvm_test launcher under coverage on Windows."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("@rules_testing//lib:util.bzl", "util")
load("//kotlin:jvm.bzl", "kt_jvm_test")

_WINDOWS = Label("//src/test/starlark/internal/jvm:windows_x86_64")
_WINDOWS_CC = Label("//src/test/starlark/internal/jvm:windows_cc_toolchain")

def _windows_coverage_test_suite_flag_impl(env, target):
    action = env.expect.that_target(target).action_named("JavaLauncherMaker")
    argv = action.actual.argv
    env.expect.that_collection(argv).contains("jacoco_main_class=com.google.testing.junit.runner.BazelTestRunner")
    jvm_flags = [arg for arg in argv if arg.startswith("jvm_flags=")]
    env.expect.that_collection(jvm_flags).has_size(1)
    flags = jvm_flags[0].removeprefix("jvm_flags=").split("\t")
    env.expect.that_collection(flags).contains("-Dbazel.test_suite=test.SubjectTest")
    env.expect.that_collection(flags).not_contains("-Dbazel.test_suite=com.google.testing.junit.runner.BazelTestRunner")

def _windows_coverage_test_suite_flag_test(name):
    kt_jvm_test(
        name = name + "_subject",
        srcs = [util.empty_file(name + "_Test.kt")],
        test_class = "test.SubjectTest",
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        impl = _windows_coverage_test_suite_flag_impl,
        target = name + "_subject",
        config_settings = {
            "//command_line_option:collect_code_coverage": True,
            "//command_line_option:extra_toolchains": [str(_WINDOWS_CC)],
            "//command_line_option:platforms": [str(_WINDOWS)],
        },
    )

def kt_jvm_test_coverage_test_suite(name):
    test_suite(
        name = name,
        tests = [
            _windows_coverage_test_suite_flag_test,
        ],
    )
