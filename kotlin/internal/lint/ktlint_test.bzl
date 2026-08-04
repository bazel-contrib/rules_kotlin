"""Defines ktlint_test rule that lints sources."""

load("@bazel_lib//lib:paths.bzl", "BASH_RLOCATION_FUNCTION", "to_rlocation_path")
load("@bazel_lib//lib:windows_utils.bzl", "create_windows_native_launcher_script")
load("//src/main/starlark/core/compile:common.bzl", "JAVA_RUNTIME_TOOLCHAIN_TYPE")
load(":editorconfig.bzl", "get_editorconfig", "is_android_rules_enabled", "is_experimental_rules_enabled")
load(":ktlint_config.bzl", "KtlintConfigInfo")

def _ktlint_test_impl(ctx):
    editorconfig = get_editorconfig(ctx.attr.config)

    # Build ktlint arguments
    args = []
    if editorconfig:
        args.append("--editorconfig=$(rlocation {})".format(to_rlocation_path(ctx, editorconfig)))
    if is_android_rules_enabled(ctx.attr.config):
        args.append("--android")
    if is_experimental_rules_enabled(ctx.attr.config):
        args.append("--experimental")
    args.append("--relative")

    # Add source files via rlocation
    for f in ctx.files.srcs:
        args.append("$(rlocation {})".format(to_rlocation_path(ctx, f)))

    # Generate bash script
    bash_launcher = ctx.actions.declare_file(ctx.attr.name + ".sh")
    script_content = """\
#!/usr/bin/env bash
set -euo pipefail
{rlocation_function}
PATH="{java_home}/bin:$PATH" \
"$(rlocation {ktlint})" {args}
""".format(
        rlocation_function = BASH_RLOCATION_FUNCTION,
        java_home = ctx.toolchains[JAVA_RUNTIME_TOOLCHAIN_TYPE].java_runtime.java_home_runfiles_path,
        ktlint = to_rlocation_path(ctx, ctx.executable._ktlint_tool),
        args = " ".join(args),
    )

    ctx.actions.write(
        bash_launcher,
        script_content,
        is_executable = True,
    )
    java_runtime_files = ctx.toolchains[JAVA_RUNTIME_TOOLCHAIN_TYPE].java_runtime.files

    # Check if target platform is Windows
    windows_constraint = ctx.attr._windows_constraint[platform_common.ConstraintValueInfo]
    is_windows = ctx.target_platform_has_constraint(windows_constraint)

    if is_windows:
        launcher = create_windows_native_launcher_script(ctx, bash_launcher)
    else:
        launcher = bash_launcher

    files = [ctx.executable._ktlint_tool, bash_launcher] + ctx.files.srcs
    if editorconfig:
        files.append(editorconfig)

    return [
        DefaultInfo(
            runfiles = ctx.runfiles(
                files = files,
                transitive_files = java_runtime_files,
            ).merge_all([
                ctx.attr._ktlint_tool[DefaultInfo].default_runfiles,
                ctx.attr._runfiles_library[DefaultInfo].default_runfiles,
            ]),
            executable = launcher,
        ),
    ]

ktlint_test = rule(
    _ktlint_test_impl,
    attrs = {
        "config": attr.label(
            doc = "ktlint_config to use",
            providers = [[KtlintConfigInfo]],
        ),
        "srcs": attr.label_list(
            allow_files = [".kt", ".kts"],
            doc = "Source files to lint",
            mandatory = True,
            allow_empty = False,
        ),
        "_ktlint_tool": attr.label(
            default = "//kotlin/internal/lint:ktlint",
            executable = True,
            cfg = "exec",
        ),
        "_runfiles_library": attr.label(
            default = "@bazel_tools//tools/bash/runfiles",
        ),
        "_windows_constraint": attr.label(
            default = "@platforms//os:windows",
        ),
    },
    doc = "Lint Kotlin files, and fail if the linter raises errors.",
    test = True,
    toolchains = [
        JAVA_RUNTIME_TOOLCHAIN_TYPE,
        "@bazel_tools//tools/sh:toolchain_type",
    ],
)
