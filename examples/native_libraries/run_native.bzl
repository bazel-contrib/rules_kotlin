"""Runs the JNI binary as a build tool, outside its runfiles workspace."""

def _run_native_impl(ctx):
    output = ctx.actions.declare_file(ctx.label.name + ".txt")
    ctx.actions.run(
        executable = ctx.attr.tool[DefaultInfo].files_to_run,
        arguments = [output.path],
        outputs = [output],
        mnemonic = "TestNativeTool",
    )
    return [DefaultInfo(files = depset([output]))]

run_native = rule(
    implementation = _run_native_impl,
    attrs = {"tool": attr.label(executable = True, cfg = "exec")},
)
