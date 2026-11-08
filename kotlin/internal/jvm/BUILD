load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

# Copyright 2018 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("//src/main/starlark/release:packager.bzl", "release_archive")

exports_files([
    "kotlin-compiler-embeddable-reshade.jarjar",
    "kotlin-compiler-reshade.jarjar",
])

release_archive(
    name = "pkg",
    srcs = glob(["*.bzl"]) + [
        "kotlin-compiler-embeddable-reshade.jarjar",
        "kotlin-compiler-reshade.jarjar",
        "native_java_launcher.cc",
    ],
    src_map = {
        "BUILD.release.bazel": "BUILD.bazel",
    },
)

bzl_library(
    name = "jvm",
    srcs = glob(["*.bzl"]),
    visibility = ["//kotlin:__subpackages__"],
    deps = [
        "//src/main/starlark/core/pipeline",
        "//third_party:bzl",
        "@bazel_skylib//lib:sets",
        "@bazel_skylib//lib:shell",
        "@bazel_skylib//rules:common_settings",
        "@rules_cc//cc/common",
        "@rules_java//java:rules",
    ],
)

# Kotlin binaries and tests depend on this on every platform. Only Windows needs it: elsewhere the
# shell launcher sets java.library.path itself.
alias(
    name = "native_java_launcher",
    actual = select({
        "@platforms//os:windows": ":native_java",
        "//conditions:default": ":no_native_java_launcher",
    }),
    visibility = ["//visibility:public"],
)

# A short name: it is part of the object file paths, which cl.exe can't open past 259 characters.
cc_binary(
    name = "native_java",
    srcs = ["native_java_launcher.cc"],
    target_compatible_with = ["@platforms//os:windows"],
    deps = ["@rules_cc//cc/runfiles"],
)

filegroup(name = "no_native_java_launcher")
