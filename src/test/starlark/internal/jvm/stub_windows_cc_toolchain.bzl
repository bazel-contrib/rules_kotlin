"""A stub Windows cc toolchain with no tools, for analysis tests only."""

load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/toolchains:cc_toolchain_config_info.bzl", "CcToolchainConfigInfo")

def _impl(ctx):
    return cc_common.create_cc_toolchain_config_info(
        ctx = ctx,
        toolchain_identifier = "stub_windows",
        target_system_name = "x86_64-pc-windows-msvc",
        target_cpu = "x64_windows",
        target_libc = "msvcrt",
        compiler = "msvc-cl",
        abi_version = "local",
        abi_libc_version = "local",
    )

stub_windows_cc_toolchain_config = rule(
    implementation = _impl,
    provides = [CcToolchainConfigInfo],
)
