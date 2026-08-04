"""Tests that ktlint_fix exports Java runfiles."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//kotlin:lint.bzl", "ktlint_fix")

def _ktlint_fix_launcher_exports_java_runfiles_test_impl(ctx):
    env = analysistest.begin(ctx)

    launcher_actions = [
        action
        for action in analysistest.target_actions(env)
        if action.mnemonic == "FileWrite" and action.outputs.to_list()[0].path.endswith("-lint-fix.sh")
    ]

    asserts.equals(
        env,
        1,
        len(launcher_actions),
        "expected exactly one lint-fix launcher action",
    )

    launcher_content = launcher_actions[0].content
    asserts.true(
        env,
        "RUNFILES_MANIFEST_FILE" in launcher_content,
        "launcher must derive JAVA_RUNFILES for manifest-based runfiles layouts",
    )
    asserts.true(
        env,
        "export JAVA_RUNFILES=\"${RUNFILES_DIR}\"" in launcher_content,
        "launcher must derive JAVA_RUNFILES for directory-based runfiles layouts",
    )

    return analysistest.end(env)

ktlint_fix_launcher_exports_java_runfiles_test = analysistest.make(
    _ktlint_fix_launcher_exports_java_runfiles_test_impl,
)

def ktlint_fix_runfiles_test_suite(name):
    write_file(
        name = "ktlint_fix_runfiles_subject_src",
        out = "KtlintFixRunfilesSubject.kt",
        content = ["class KtlintFixRunfilesSubject"],
        tags = ["manual"],
    )

    ktlint_fix(
        name = "ktlint_fix_runfiles_subject",
        srcs = [":ktlint_fix_runfiles_subject_src"],
        tags = ["manual"],
    )

    ktlint_fix_launcher_exports_java_runfiles_test(
        name = "ktlint_fix_launcher_exports_java_runfiles_test",
        target_under_test = ":ktlint_fix_runfiles_subject",
        tags = ["manual"],
    )

    native.test_suite(
        name = name,
        tests = [":ktlint_fix_launcher_exports_java_runfiles_test"],
    )
