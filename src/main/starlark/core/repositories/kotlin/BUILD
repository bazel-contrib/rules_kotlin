load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("//src/main/starlark/release:packager.bzl", "release_archive")

release_archive(
    name = "pkg",
    srcs = glob([
        "capabilities_*.bzl",
        "templates.bzl",
    ]),
    src_map = {
        "BUILD.release.bazel": "BUILD",
    },
)

bzl_library(
    name = "kotlin",
    srcs = glob(["*.bzl"]),
    visibility = [
        "//visibility:public",
    ],
)
