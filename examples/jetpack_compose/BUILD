load("@bazel_tools//tools/jdk:default_java_toolchain.bzl", "default_java_toolchain")
load("@rules_kotlin//kotlin:core.bzl", "define_kt_toolchain", "kt_compiler_plugin")

# Java Toolchain

default_java_toolchain(
    name = "java_toolchain",
    visibility = ["//visibility:public"],
)

define_kt_toolchain(
    name = "kotlin_toolchain",
    jvm_target = "11",
)

# Define the compose compiler plugin
# Used by referencing //:jetpack_compose_compiler_plugin

kt_compiler_plugin(
    name = "jetpack_compose_compiler_plugin",
    data = [":stability_config"],
    id = "androidx.compose.compiler.plugins.kotlin",
    options = {
        "sourceInformation": ["true"],  # Required for AS Layout Inspector, disable for release builds
        "stabilityConfigurationPath": ["$(locations :stability_config)"],
    },
    target_embedded_compiler = True,
    visibility = ["//visibility:public"],
    deps = [
        "@maven_rules_kotlin_example//:org_jetbrains_kotlin_kotlin_compose_compiler_plugin_embeddable",
    ],
)

filegroup(
    name = "stability_config",
    srcs = ["stability.conf"],
)

platform(
    name = "arm64-v8a",
    constraint_values = [
        "@platforms//cpu:arm64",
        "@platforms//os:android",
    ],
)

platform(
    name = "x86_64",
    constraint_values = [
        "@platforms//cpu:x86_64",
        "@platforms//os:android",
    ],
)
