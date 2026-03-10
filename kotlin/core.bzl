load(
    "//kotlin/internal:opts.bzl",
    _kt_javac_options = "kt_javac_options",
    _kt_kotlinc_options = "kt_kotlinc_options",
)
load(
    "//kotlin/internal:toolchains.bzl",
    _define_kt_toolchain = "define_kt_toolchain",
)
load(
    "//kotlin/internal/jvm:jvm.bzl",
    _kt_compiler_plugin = "kt_compiler_plugin",
    _kt_ksp_plugin = "kt_ksp_plugin",
    _kt_plugin_cfg = "kt_plugin_cfg",
)

define_kt_toolchain = _define_kt_toolchain
kt_javac_options = _kt_javac_options
kt_kotlinc_options = _kt_kotlinc_options
kt_compiler_plugin = _kt_compiler_plugin
kt_ksp_plugin = _kt_ksp_plugin
kt_plugin_cfg = _kt_plugin_cfg
