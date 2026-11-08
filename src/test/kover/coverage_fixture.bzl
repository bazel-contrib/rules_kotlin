"""Build a runnable fixture with Kover enabled during an ordinary bazel test."""

def _coverage_settings(settings, _attr):
    return {
        "//command_line_option:collect_code_coverage": True,
        "//command_line_option:extra_toolchains": [str(Label(":toolchain"))] + settings["//command_line_option:extra_toolchains"],
        "//command_line_option:instrumentation_filter": "^//src/test/kover[/:]",
    }

_coverage = transition(
    implementation = _coverage_settings,
    inputs = ["//command_line_option:extra_toolchains"],
    outputs = [
        "//command_line_option:collect_code_coverage",
        "//command_line_option:extra_toolchains",
        "//command_line_option:instrumentation_filter",
    ],
)

def _fixture_impl(ctx):
    test = ctx.attr.test[0][DefaultInfo]

    # The agent writes next to its argument file. Stage the report inputs in a writable workspace.
    inputs = ctx.actions.declare_file(ctx.label.name + ".inputs")
    ctx.actions.write(inputs, "\n".join([
        f.short_path
        for f in test.default_runfiles.files.to_list()
        if f.extension in ["jar", "kt", "txt"]
    ]))
    return [DefaultInfo(
        files = depset([test.files_to_run.executable]),
        runfiles = test.default_runfiles.merge(ctx.runfiles(files = [inputs])),
    )]

coverage_fixture = rule(
    implementation = _fixture_impl,
    attrs = {
        "test": attr.label(cfg = _coverage, mandatory = True),
        "_allowlist_function_transition": attr.label(default = "@bazel_tools//tools/allowlists/function_transition_allowlist"),
    },
)
