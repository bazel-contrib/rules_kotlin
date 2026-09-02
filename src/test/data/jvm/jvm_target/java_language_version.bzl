"""Build a target with a pinned Java language version and optional extra toolchains."""

def _pin_java_language_version_impl(settings, attr):
    return {
        "//command_line_option:extra_toolchains": settings["//command_line_option:extra_toolchains"] + attr.extra_toolchains,
        "//command_line_option:java_language_version": attr.java_language_version,
    }

_pin_java_language_version = transition(
    implementation = _pin_java_language_version_impl,
    inputs = ["//command_line_option:extra_toolchains"],
    outputs = [
        "//command_line_option:extra_toolchains",
        "//command_line_option:java_language_version",
    ],
)

def _java_language_version_env_impl(ctx):
    dep = ctx.attr.target
    if type(dep) == "list":
        dep = dep[0]
    return [DefaultInfo(
        files = dep[DefaultInfo].files,
        runfiles = dep[DefaultInfo].default_runfiles,
    )]

java_language_version_env = rule(
    doc = "Forwards `target`, built with a pinned Java language version and extra toolchains.",
    implementation = _java_language_version_env_impl,
    attrs = {
        "extra_toolchains": attr.string_list(default = []),
        "java_language_version": attr.string(mandatory = True),
        "target": attr.label(mandatory = True, cfg = _pin_java_language_version),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)
