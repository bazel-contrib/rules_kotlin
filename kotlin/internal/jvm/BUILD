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
load("//src/main/starlark/release:packager.bzl", "release_archive")

exports_files(["kotlin-compiler-reshade.jarjar"])

release_archive(
    name = "pkg",
    srcs = glob(["*.bzl"]) + ["kotlin-compiler-reshade.jarjar"],
    src_map = {
        "BUILD.release.bazel": "BUILD.bazel",
    },
)

bzl_library(
    name = "jvm",
    srcs = glob(["*.bzl"]),
    visibility = ["//kotlin:__subpackages__"],
    deps = [
        "@bazel_skylib//lib:sets",
        "@bazel_skylib//rules:common_settings",
        "@rules_java//java:rules",
    ],
)
