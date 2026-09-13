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

load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc:cc_test.bzl", "cc_test")
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
        "native_java_launcher.h",
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
        "//third_party:bzl",
        "@bazel_skylib//lib:sets",
        "@bazel_skylib//rules:common_settings",
        "@rules_cc//cc/common",
        "@rules_java//java:rules",
    ],
)

cc_binary(
    name = "native_java_launcher",
    srcs = ["native_java_launcher.cc"],
    copts = select({
        "@platforms//os:windows": ["/std:c++17"],
        "//conditions:default": ["-std=c++17"],
    }),
    visibility = ["//visibility:public"],
    deps = [":native_java_launcher_lib"],
)

cc_test(
    name = "native_java_launcher_test",
    srcs = ["native_java_launcher_test.cc"],
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
    deps = [":native_java_launcher_lib"],
)

cc_library(
    name = "native_java_launcher_lib",
    hdrs = ["native_java_launcher.h"],
    deps = ["@rules_cc//cc/runfiles"],
)
