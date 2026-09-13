load("@rules_cc//cc:cc_test.bzl", "cc_test")
load("@rules_cc//cc:defs.bzl", "cc_binary")
load("@rules_java//java:defs.bzl", "java_library", "java_test")
load("//kotlin:jvm.bzl", "kt_jvm_binary", "kt_jvm_import", "kt_jvm_library", "kt_jvm_test")

[
    cc_binary(
        name = filename,
        srcs = ["native_lib.cc"],
        linkshared = True,
        tags = ["manual"],
        deps = ["@bazel_tools//tools/jdk:jni"],
    )
    for filename in [
        "libnative_lib.so",
        "libnative_lib.dylib",
        "native_lib.dll",
    ]
]

alias(
    name = "native_lib",
    actual = select({
        "@platforms//os:macos": ":libnative_lib.dylib",
        "@platforms//os:windows": ":native_lib.dll",
        "//conditions:default": ":libnative_lib.so",
    }),
)

kt_jvm_library(
    name = "native_lib_kt",
    srcs = ["NativeLib.kt"],
    runtime_deps = [":native_lib"],
)

kt_jvm_binary(
    name = "NativeLibraryPathBin",
    main_class = "native_lib.NativeLibKt",
    runtime_deps = [":native_lib_kt"],
)

kt_jvm_test(
    name = "NativeLibraryPathTest",
    srcs = ["NativeLibTest.kt"],
    test_class = "native_lib.NativeLibTest",
    deps = [
        ":native_lib_kt",
        "//kotlin/compiler:kotlin-test",
        "@kotlin_rules_maven_test//:junit_junit",
    ],
)

java_library(
    name = "java_bridge",
    runtime_deps = [":native_lib"],
)

kt_jvm_library(
    name = "export_only",
    exports = [":native_lib"],
)

kt_jvm_library(
    name = "runtime_only",
    runtime_deps = [":native_lib"],
)

kt_jvm_import(
    name = "imported",
    jar = "//third_party:empty.jar",
    runtime_deps = [":native_lib"],
)

[
    kt_jvm_test(
        name = "loads_" + name,
        srcs = [
            "NativeLib.kt",
            "NativeLibTest.kt",
        ],
        test_class = "native_lib.NativeLibTest",
        runtime_deps = [] if name == "direct_deps" else [dep],
        deps = [
            "//kotlin/compiler:kotlin-test",
            "@kotlin_rules_maven_test//:junit_junit",
        ] + ([dep] if name == "direct_deps" else []),
    )
    for name, dep in {
        "direct_deps": ":native_lib",
        "direct_runtime_deps": ":native_lib",
        "through_exports": ":export_only",
        "through_import": ":imported",
        "through_java": ":java_bridge",
        "through_runtime_only": ":runtime_only",
    }.items()
]

kt_jvm_library(
    name = "test_library",
    srcs = ["NativeLibTest.kt"],
    deps = [
        ":native_lib_kt",
        "//kotlin/compiler:kotlin-test",
        "@kotlin_rules_maven_test//:junit_junit",
    ],
)

java_test(
    name = "java_loads_kotlin_native_dependency",
    target_compatible_with = select({
        # rules_java's Windows launcher does not resolve java.library.path.
        "@platforms//os:windows": ["@platforms//:incompatible"],
        "//conditions:default": [],
    }),
    test_class = "native_lib.NativeLibTest",
    runtime_deps = [":test_library"],
)

kt_jvm_test(
    name = "user_library_path_overrides_default",
    srcs = ["LibraryPathOverride.kt"],
    jvm_flags = ['-Djava.library.path="user supplied path"'],
    main_class = "native_lib.LibraryPathOverride",
    test_class = "native_lib.LibraryPathOverride",
    runtime_deps = [":native_lib"],
)

cc_test(
    name = "native_java_launcher_test",
    srcs = ["NativeLauncherTest.cc"],
    copts = select({
        "@platforms//os:windows": [
            "/std:c++17",
            "/UNDEBUG",
        ],
        "//conditions:default": [
            "-std=c++17",
            "-UNDEBUG",
        ],
    }),
    deps = ["//kotlin/internal/jvm:native_java_launcher_lib"],
)
