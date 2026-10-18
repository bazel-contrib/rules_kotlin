"""Public Kotlin/JVM rule API."""

load(
    "//kotlin/internal:opts.bzl",
    _kt_javac_options = "kt_javac_options",
)
load(
    "//kotlin/internal/jvm:kt_jvm_binary.bzl",
    _kt_jvm_binary = "kt_jvm_binary",
)
load(
    "//kotlin/internal/jvm:kt_jvm_import.bzl",
    _kt_jvm_import = "kt_jvm_import",
)
load(
    "//kotlin/internal/jvm:kt_jvm_library.bzl",
    _kt_jvm_library = "kt_jvm_library",
)
load(
    "//kotlin/internal/jvm:kt_jvm_test.bzl",
    _kt_jvm_test = "kt_jvm_test",
)

kt_javac_options = _kt_javac_options
kt_jvm_binary = _kt_jvm_binary
kt_jvm_import = _kt_jvm_import
kt_jvm_library = _kt_jvm_library
kt_jvm_test = _kt_jvm_test
