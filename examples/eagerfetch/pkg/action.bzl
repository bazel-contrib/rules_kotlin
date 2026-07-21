def _a_action(ctx):
    out = ctx.actions.declare_file("%s.txt" % ctx.label.name)
    ctx.actions.write(out, content="fooey")
    return [
        DefaultInfo(files=depset([out]))
    ]

a_action=rule(
    implementation = _a_action,
    attrs = {},
    toolchains = [":toolchain_type"]
)
