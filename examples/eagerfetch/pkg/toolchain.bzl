def _a_toolchain(ctx):
    return [
        platform_common.ToolchainInfo()
    ]

a_toolchain = rule(
    implementation = _a_toolchain,
    provides = [platform_common.ToolchainInfo],
    attrs = {}
)
