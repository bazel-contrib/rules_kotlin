"""Tests for disabling java annotation processing via the no_proc javac option."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//kotlin:jvm.bzl", "kt_javac_options", "kt_jvm_library")

def _javac_action(env):
    actions = analysistest.target_actions(env)
    javac_actions = [
        action
        for action in actions
        if action.mnemonic == "Javac"
    ]
    asserts.equals(env, expected = 1, actual = len(javac_actions))
    return javac_actions[0]

def _no_proc_reaches_javac_test_impl(ctx):
    env = analysistest.begin(ctx)

    # A java-only target: the -proc:none for targets with Kotlin sources does not apply, so the
    # flag can only come from the no_proc option.
    asserts.true(
        env,
        "-proc:none" in _javac_action(env).argv,
        msg = "kt_javac_options(no_proc = True) should reach the Javac action as -proc:none",
    )

    return analysistest.end(env)

_no_proc_reaches_javac_test = analysistest.make(_no_proc_reaches_javac_test_impl)

def _no_proc_off_by_default_test_impl(ctx):
    env = analysistest.begin(ctx)

    asserts.false(
        env,
        "-proc:none" in _javac_action(env).argv,
        msg = "annotation processing must stay enabled for java-only targets by default",
    )

    return analysistest.end(env)

_no_proc_off_by_default_test = analysistest.make(_no_proc_off_by_default_test_impl)

def _mixed_target_no_proc_test_impl(ctx):
    env = analysistest.begin(ctx)

    # A target with Kotlin sources compiles its Java half with -proc:none regardless of options:
    # Kotlin owns annotation processing there.
    argv = _javac_action(env).argv
    asserts.true(
        env,
        "-proc:none" in argv,
        msg = "the java half of a mixed target must always be compiled with -proc:none",
    )
    asserts.equals(
        env,
        expected = 1,
        actual = len([arg for arg in argv if arg == "-proc:none"]),
    )

    return analysistest.end(env)

_mixed_target_no_proc_test = analysistest.make(_mixed_target_no_proc_test_impl)

def _mixed_target_explicit_no_proc_test_impl(ctx):
    env = analysistest.begin(ctx)

    # A mixed target whose options also set no_proc must not end up with a duplicated flag: the
    # options render -proc:none themselves, and the Kotlin-sources rule detects that via the
    # option value.
    argv = _javac_action(env).argv
    asserts.equals(
        env,
        expected = 1,
        actual = len([arg for arg in argv if arg == "-proc:none"]),
    )

    return analysistest.end(env)

_mixed_target_explicit_no_proc_test = analysistest.make(_mixed_target_explicit_no_proc_test_impl)

def _release_flag_reaches_javac_test_impl(ctx):
    env = analysistest.begin(ctx)

    # The Javac action tokenizes each flag into individual argv entries, so "--release 25"
    # reaches the action as ["--release", "25"].
    argv = _javac_action(env).argv
    asserts.true(
        env,
        "--release" in argv,
        msg = "kt_javac_options(release = \"25\") should reach the Javac action as --release 25",
    )
    asserts.equals(
        env,
        expected = "25",
        actual = argv[argv.index("--release") + 1],
    )

    return analysistest.end(env)

_release_flag_reaches_javac_test = analysistest.make(_release_flag_reaches_javac_test_impl)

def _javac_options_contents():
    write_file(
        name = "javac_flags_java_source",
        out = "JavacFlagsSource.java",
        content = ["class JavacFlagsSource {}"],
        tags = ["manual"],
    )

    write_file(
        name = "javac_flags_kt_source",
        out = "JavacFlagsSource.kt",
        content = ["class JavacFlagsKotlinSource"],
        tags = ["manual"],
    )

    kt_javac_options(
        name = "no_proc_javac_options",
        no_proc = True,
        tags = ["manual"],
    )

    kt_javac_options(
        name = "release_25_javac_options",
        release = "25",
        tags = ["manual"],
    )

    kt_jvm_library(
        name = "javac_no_proc_library",
        srcs = ["javac_flags_java_source"],
        javac_opts = ":no_proc_javac_options",
        tags = ["manual"],
    )

    kt_jvm_library(
        name = "javac_default_options_library",
        srcs = ["javac_flags_java_source"],
        tags = ["manual"],
    )

    kt_jvm_library(
        name = "javac_mixed_library",
        srcs = [
            "javac_flags_java_source",
            "javac_flags_kt_source",
        ],
        tags = ["manual"],
    )

    kt_jvm_library(
        name = "javac_mixed_no_proc_library",
        srcs = [
            "javac_flags_java_source",
            "javac_flags_kt_source",
        ],
        javac_opts = ":no_proc_javac_options",
        tags = ["manual"],
    )

    kt_jvm_library(
        name = "javac_release_25_library",
        srcs = ["javac_flags_java_source"],
        javac_opts = ":release_25_javac_options",
        tags = ["manual"],
    )

    _no_proc_reaches_javac_test(
        name = "no_proc_reaches_the_javac_action_test",
        target_under_test = ":javac_no_proc_library",
    )

    _no_proc_off_by_default_test(
        name = "no_proc_off_by_default_test",
        target_under_test = ":javac_default_options_library",
    )

    _mixed_target_no_proc_test(
        name = "mixed_target_no_proc_test",
        target_under_test = ":javac_mixed_library",
    )

    _mixed_target_explicit_no_proc_test(
        name = "mixed_target_explicit_no_proc_test",
        target_under_test = ":javac_mixed_no_proc_library",
    )

    _release_flag_reaches_javac_test(
        name = "release_25_reaches_the_javac_action_test",
        target_under_test = ":javac_release_25_library",
    )

def javac_options_test_suite(name):
    _javac_options_contents()

    native.test_suite(
        name = name,
        tests = [
            ":no_proc_reaches_the_javac_action_test",
            ":no_proc_off_by_default_test",
            ":mixed_target_no_proc_test",
            ":mixed_target_explicit_no_proc_test",
            ":release_25_reaches_the_javac_action_test",
        ],
    )
