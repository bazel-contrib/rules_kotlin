"""Defines ktlint_fix rule that reformats sources in place."""

load("@bazel_lib//lib:paths.bzl", "BASH_RLOCATION_FUNCTION", "to_rlocation_path")
load("@bazel_lib//lib:windows_utils.bzl", "create_windows_native_launcher_script")
load(":editorconfig.bzl", "get_editorconfig", "is_android_rules_enabled", "is_experimental_rules_enabled")
load(":ktlint_config.bzl", "KtlintConfigInfo")

def _ktlint_fix_impl(ctx):
    editorconfig = get_editorconfig(ctx.attr.config)

    # Build ktlint arguments (editorconfig uses rlocation since it's in runfiles)
    args = ["--format"]
    if editorconfig:
        args.append("--editorconfig=$(rlocation {})".format(to_rlocation_path(ctx, editorconfig)))
    if is_android_rules_enabled(ctx.attr.config):
        args.append("--android")
    if is_experimental_rules_enabled(ctx.attr.config):
        args.append("--experimental")
    args.append("--relative")

    # Source files use BUILD_WORKSPACE_DIRECTORY since we want to modify the actual files
    srcs = " ".join(['"${{BUILD_WORKSPACE_DIRECTORY}}/{}"'.format(src.path) for src in ctx.files.srcs])

    # Generate bash script
    bash_launcher = ctx.actions.declare_file("%s-lint-fix.sh" % ctx.label.name)
    content = """\
#!/usr/bin/env bash
set -euo pipefail
{rlocation_function}
# java_binary launchers fail to discover runfiles in some bazel run setups.
# Populate JAVA_RUNFILES from either directory- or manifest-based runfiles env.
if [[ -z "${{JAVA_RUNFILES:-}}" ]]; then
  if [[ -n "${{RUNFILES_DIR:-}}" ]]; then
    export JAVA_RUNFILES="${{RUNFILES_DIR}}"
  elif [[ -n "${{RUNFILES_MANIFEST_FILE:-}}" ]]; then
    if [[ "${{RUNFILES_MANIFEST_FILE}}" == */MANIFEST ]]; then
      export JAVA_RUNFILES="${{RUNFILES_MANIFEST_FILE%/MANIFEST}}"
    elif [[ "${{RUNFILES_MANIFEST_FILE}}" == *.runfiles_manifest ]]; then
      export JAVA_RUNFILES="${{RUNFILES_MANIFEST_FILE%.runfiles_manifest}}.runfiles"
    fi
  fi
fi
"$(rlocation {ktlint})" {args} {srcs}
""".format(
        rlocation_function = BASH_RLOCATION_FUNCTION,
        ktlint = to_rlocation_path(ctx, ctx.executable._ktlint_tool),
        args = " ".join(args),
        srcs = srcs,
    )

    ctx.actions.write(
        output = bash_launcher,
        content = content,
        is_executable = True,
    )

    # Check if target platform is Windows
    windows_constraint = ctx.attr._windows_constraint[platform_common.ConstraintValueInfo]
    is_windows = ctx.target_platform_has_constraint(windows_constraint)

    if is_windows:
        launcher = create_windows_native_launcher_script(ctx, bash_launcher)
    else:
        launcher = bash_launcher

    files = [ctx.executable._ktlint_tool, bash_launcher]
    if editorconfig:
        files.append(editorconfig)
    runfiles = ctx.runfiles(files = files).merge_all([
        ctx.attr._ktlint_tool[DefaultInfo].default_runfiles,
        ctx.attr._runfiles_library[DefaultInfo].default_runfiles,
    ])

    return [
        DefaultInfo(
            executable = launcher,
            runfiles = runfiles,
        ),
    ]

ktlint_fix = rule(
    _ktlint_fix_impl,
    attrs = {
        "config": attr.label(
            doc = "ktlint_config to use",
            providers = [[KtlintConfigInfo]],
        ),
        "srcs": attr.label_list(
            allow_files = [".kt", ".kts"],
            doc = "Source files to review and fix",
            mandatory = True,
            allow_empty = False,
        ),
        "_ktlint_tool": attr.label(
            default = "//kotlin/internal/lint:ktlint",
            executable = True,
            cfg = "target",
        ),
        "_runfiles_library": attr.label(
            default = "@bazel_tools//tools/bash/runfiles",
        ),
        "_windows_constraint": attr.label(
            default = "@platforms//os:windows",
        ),
    },
    executable = True,
    doc = "Lint Kotlin files and automatically fix them as needed",
    toolchains = ["@bazel_tools//tools/sh:toolchain_type"],
)
