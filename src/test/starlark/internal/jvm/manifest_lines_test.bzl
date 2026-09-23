"""Tests for the manifest_lines attribute: the lines reach the runtime fold only, and bad lines fail the analysis."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//kotlin:jvm.bzl", "kt_jvm_library")

_MAIN_CLASS_LINE = "Main-Class: manifest.lines.Main"
_PREMAIN_CLASS_LINE = "Premain-Class: manifest.lines.Agent"

def _fold_action(env, action_type):
    actions = [
        action
        for action in analysistest.target_actions(env)
        if action.mnemonic == "KotlinFoldJars" + action_type
    ]
    asserts.equals(env, expected = 1, actual = len(actions), msg = "expected one KotlinFoldJars%s action" % action_type)
    return actions[0]

def _lines_reach_the_runtime_fold_test_impl(ctx):
    env = analysistest.begin(ctx)

    argv = _fold_action(env, "Runtime").argv
    asserts.true(env, _MAIN_CLASS_LINE in argv, msg = "the first line must reach the runtime fold: %s" % argv)
    asserts.true(env, _PREMAIN_CLASS_LINE in argv, msg = "the second line must reach the runtime fold: %s" % argv)
    if _MAIN_CLASS_LINE in argv and _PREMAIN_CLASS_LINE in argv:
        # The lines belong to the --deploy_manifest_lines group, after the two attributes the rules write.
        rule_kind_index = [i for i, arg in enumerate(argv) if arg.startswith("Injecting-Rule-Kind: ")][0]
        asserts.true(env, argv.index(_MAIN_CLASS_LINE) == rule_kind_index + 1, msg = "the lines must follow Injecting-Rule-Kind: %s" % argv)
        asserts.true(env, argv.index(_PREMAIN_CLASS_LINE) == rule_kind_index + 2, msg = "the lines must keep their order: %s" % argv)
        asserts.true(env, argv.index("--output") > argv.index(_PREMAIN_CLASS_LINE), msg = "the lines must end before --output: %s" % argv)

    abi_argv = _fold_action(env, "Abi").argv
    asserts.false(env, _MAIN_CLASS_LINE in abi_argv, msg = "the compile jar takes the rule attributes only: %s" % abi_argv)
    asserts.true(env, len([arg for arg in abi_argv if arg.startswith("Target-Label: ")]) == 1, msg = "the compile jar keeps Target-Label: %s" % abi_argv)

    return analysistest.end(env)

_lines_reach_the_runtime_fold_test = analysistest.make(_lines_reach_the_runtime_fold_test_impl)

def _rejects_a_line_without_a_value_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "is not one `Name: value` line")
    return analysistest.end(env)

_rejects_a_line_without_a_value_test = analysistest.make(_rejects_a_line_without_a_value_test_impl, expect_failure = True)

def _rejects_a_rule_attribute_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "repeats the attribute Manifest-Version")
    return analysistest.end(env)

_rejects_a_rule_attribute_test = analysistest.make(_rejects_a_rule_attribute_test_impl, expect_failure = True)

def _rejects_a_multi_release_value_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "Multi-Release takes `true` or `false`")
    return analysistest.end(env)

_rejects_a_multi_release_value_test = analysistest.make(_rejects_a_multi_release_value_test_impl, expect_failure = True)

def _rejects_lines_on_an_export_only_library_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "manifest_lines without srcs or resources is invalid")
    return analysistest.end(env)

_rejects_lines_on_an_export_only_library_test = analysistest.make(_rejects_lines_on_an_export_only_library_test_impl, expect_failure = True)

def _manifest_lines_contents():
    write_file(
        name = "manifest_lines_kt_source",
        out = "ManifestLinesSource.kt",
        content = ["class ManifestLinesSource"],
        tags = ["manual"],
    )

    kt_jvm_library(
        name = "manifest_lines_library",
        srcs = ["manifest_lines_kt_source"],
        manifest_lines = [
            _MAIN_CLASS_LINE,
            _PREMAIN_CLASS_LINE,
        ],
        tags = ["manual"],
    )

    kt_jvm_library(
        name = "manifest_line_without_a_value_library",
        srcs = ["manifest_lines_kt_source"],
        manifest_lines = ["Main-Class"],
        tags = ["manual"],
    )

    kt_jvm_library(
        name = "manifest_rule_attribute_library",
        srcs = ["manifest_lines_kt_source"],
        manifest_lines = ["Manifest-Version: 1.0"],
        tags = ["manual"],
    )

    kt_jvm_library(
        name = "manifest_multi_release_value_library",
        srcs = ["manifest_lines_kt_source"],
        manifest_lines = ["Multi-Release: yes"],
        tags = ["manual"],
    )

    kt_jvm_library(
        name = "manifest_lines_export_only_library",
        srcs = [],
        manifest_lines = [_MAIN_CLASS_LINE],
        tags = ["manual"],
    )

    _lines_reach_the_runtime_fold_test(
        name = "manifest_lines_reach_the_runtime_fold_test",
        target_under_test = ":manifest_lines_library",
    )

    _rejects_a_line_without_a_value_test(
        name = "manifest_line_without_a_value_is_rejected_test",
        target_under_test = ":manifest_line_without_a_value_library",
    )

    _rejects_a_rule_attribute_test(
        name = "manifest_rule_attribute_is_rejected_test",
        target_under_test = ":manifest_rule_attribute_library",
    )

    _rejects_a_multi_release_value_test(
        name = "manifest_multi_release_value_is_rejected_test",
        target_under_test = ":manifest_multi_release_value_library",
    )

    _rejects_lines_on_an_export_only_library_test(
        name = "manifest_lines_on_an_export_only_library_are_rejected_test",
        target_under_test = ":manifest_lines_export_only_library",
    )

def manifest_lines_test_suite(name):
    _manifest_lines_contents()

    native.test_suite(
        name = name,
        tests = [
            ":manifest_lines_reach_the_runtime_fold_test",
            ":manifest_line_without_a_value_is_rejected_test",
            ":manifest_rule_attribute_is_rejected_test",
            ":manifest_multi_release_value_is_rejected_test",
            ":manifest_lines_on_an_export_only_library_are_rejected_test",
        ],
    )
