"""Runs a binary as a build tool, where its working directory is the execroot."""

def _run_tool_impl(ctx):
    output = ctx.actions.declare_file(ctx.label.name + ".txt")
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [output.path],
        outputs = [output],
        mnemonic = "RunNativeTool",
    )
    return [DefaultInfo(files = depset([output]))]

run_tool = rule(
    implementation = _run_tool_impl,
    attrs = {"tool": attr.label(executable = True, cfg = "exec")},
)
