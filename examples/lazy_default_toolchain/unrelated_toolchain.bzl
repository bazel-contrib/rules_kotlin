def _unrelated_toolchain_impl(_ctx):
    return [platform_common.ToolchainInfo()]

unrelated_toolchain = rule(
    implementation = _unrelated_toolchain_impl,
)

def _unrelated_target_impl(ctx):
    output = ctx.actions.declare_file(ctx.label.name + ".txt")
    ctx.actions.write(output, "unrelated toolchain resolved\n")
    return [DefaultInfo(files = depset([output]))]

unrelated_target = rule(
    implementation = _unrelated_target_impl,
    toolchains = ["//:unrelated_toolchain_type"],
)
