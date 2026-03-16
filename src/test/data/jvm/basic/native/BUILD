load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("//kotlin:jvm.bzl", "kt_jvm_binary", "kt_jvm_library", "kt_jvm_test")

package(default_visibility = ["//visibility:private"])

cc_binary(
    name = "native_lib",
    srcs = ["native_lib.cc"],
    linkshared = True,
    deps = ["@bazel_tools//tools/jdk:jni"],
)

kt_jvm_library(
    name = "native_lib_kt",
    srcs = ["NativeLib.kt"],
    runtime_deps = [":native_lib"],
)

kt_jvm_binary(
    name = "NativeLibraryPathBin",
    main_class = "native_lib.NativeLibKt",
    runtime_deps = [
        ":native_lib",
        ":native_lib_kt",
    ],
)

kt_jvm_test(
    name = "NativeLibraryPathTest",
    srcs = ["NativeLibTest.kt"],
    test_class = "native_lib.NativeLibTest",
    runtime_deps = [":native_lib"],
    deps = [
        ":native_lib_kt",
        "//kotlin/compiler:kotlin-test",
        "@kotlin_rules_maven//:junit_junit",
    ],
)
