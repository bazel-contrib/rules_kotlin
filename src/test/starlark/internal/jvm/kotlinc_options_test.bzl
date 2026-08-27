"""Tests for the kotlinc language and diagnostics options."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//kotlin:core.bzl", "kt_kotlinc_options")
load("//kotlin:jvm.bzl", "kt_jvm_library")

# Every flag the options fixture below must put on the compiler's pass-through channel.
_EXPECTED_PASSTHROUGH_FLAGS = [
    "-api-version=2.2",
    "-language-version=2.2",
    "-progressive",
    "-Xallow-kotlin-package",
    "-Xallow-unstable-dependencies",
    "-Xrender-internal-diagnostic-names",
    "-Xreport-all-warnings",
    "-Xwhen-guards",
    "-XXLanguage:+WhenGuards",
]

def _kotlin_compile_action(env):
    actions = analysistest.target_actions(env)
    compile_actions = [
        action
        for action in actions
        if action.mnemonic == "KotlinCompile"
    ]
    asserts.equals(env, expected = 1, actual = len(compile_actions))
    return compile_actions[0]

def _value_of(env, argv, flag):
    for i in range(len(argv) - 1):
        if argv[i] == flag:
            return argv[i + 1]
    asserts.true(env, False, msg = "flag %s not found in the KotlinCompile action" % flag)
    return None

def _language_options_test_impl(ctx):
    env = analysistest.begin(ctx)
    argv = _kotlin_compile_action(env).argv

    for flag in _EXPECTED_PASSTHROUGH_FLAGS:
        asserts.true(
            env,
            flag in argv,
            msg = "expected %s on the KotlinCompile action" % flag,
        )

    # api_version/language_version also override the worker's toolchain channel, so every
    # compiler invocation of the task (including the KAPT stub generation pre-pass) sees the
    # effective versions.
    asserts.equals(env, expected = "2.2", actual = _value_of(env, argv, "--kotlin_api_version"))
    asserts.equals(
        env,
        expected = "2.2",
        actual = _value_of(env, argv, "--kotlin_language_version"),
    )

    return analysistest.end(env)

_language_options_test = analysistest.make(_language_options_test_impl)

def _toolchain_versions_by_default_test_impl(ctx):
    env = analysistest.begin(ctx)
    argv = _kotlin_compile_action(env).argv

    # Without kotlinc options the worker channel carries the toolchain-wide versions.
    asserts.equals(env, expected = "2.4", actual = _value_of(env, argv, "--kotlin_api_version"))
    asserts.equals(
        env,
        expected = "2.4",
        actual = _value_of(env, argv, "--kotlin_language_version"),
    )

    return analysistest.end(env)

_toolchain_versions_by_default_test = analysistest.make(_toolchain_versions_by_default_test_impl)

def _kotlinc_options_contents():
    write_file(
        name = "language_options_kt_source",
        out = "LanguageOptionsSource.kt",
        tags = ["manual"],
    )

    kt_kotlinc_options(
        name = "language_options",
        api_version = "2.2",
        language_version = "2.2",
        progressive = True,
        tags = ["manual"],
        x_allow_kotlin_package = True,
        x_allow_unstable_dependencies = True,
        x_render_internal_diagnostic_names = True,
        x_report_all_warnings = True,
        x_when_guards = True,
        x_xlanguage = ["+WhenGuards"],
    )

    kt_jvm_library(
        name = "language_options_library",
        srcs = ["language_options_kt_source"],
        kotlinc_opts = ":language_options",
        tags = ["manual"],
    )

    kt_jvm_library(
        name = "default_options_library",
        srcs = ["language_options_kt_source"],
        tags = ["manual"],
    )

    _language_options_test(
        name = "language_options_reach_the_compiler_test",
        target_under_test = ":language_options_library",
    )

    _toolchain_versions_by_default_test(
        name = "toolchain_versions_by_default_test",
        target_under_test = ":default_options_library",
    )

def kotlinc_options_test_suite(name):
    _kotlinc_options_contents()

    native.test_suite(
        name = name,
        tests = [
            ":language_options_reach_the_compiler_test",
            ":toolchain_versions_by_default_test",
        ],
    )
