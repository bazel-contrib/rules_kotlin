"""Build a target with `//command_line_option:java_language_version` pinned to a fixed value."""

def _pin_java_language_version_impl(_settings, attr):
    return {"//command_line_option:java_language_version": attr.java_language_version}

_pin_java_language_version = transition(
    implementation = _pin_java_language_version_impl,
    inputs = [],
    outputs = ["//command_line_option:java_language_version"],
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
    doc = "Forwards `target`, built with --java_language_version pinned to `java_language_version`.",
    implementation = _java_language_version_env_impl,
    attrs = {
        "java_language_version": attr.string(mandatory = True),
        "target": attr.label(mandatory = True, cfg = _pin_java_language_version),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)
