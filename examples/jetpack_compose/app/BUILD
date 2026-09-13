load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@rules_android//android:rules.bzl", "android_binary")

# An app that consumes android-kt deps
android_binary(
    name = "compose_example_app",
    custom_package = "cm.ben.android.bazel.compose.example",
    dex_shards = 5,
    incremental_dexing = 1,
    manifest = "AndroidManifest.xml",
    visibility = ["//visibility:public"],
    deps = [
        "//compose-ui:lib",
    ],
)

build_test(
    name = "force_build_apks_test",
    targets = [
        ":compose_example_app",
    ],
)
