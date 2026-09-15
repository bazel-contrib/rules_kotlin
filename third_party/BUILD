load("@bazel_lib//lib:copy_file.bzl", "copy_file")
load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("@rules_java//java:defs.bzl", "java_binary")

filegroup(
    name = "all_files",
    srcs = glob(["*"]),
    visibility = ["//:__subpackages__"],
)

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
package(default_visibility = ["//visibility:public"])

exports_files([
    "empty.jdeps",
    "java_stub_template.txt",
])

copy_file(
    name = "empty",
    src = "empty-definately-not-binary-jar.txt",
    out = "empty.jar",
)

java_binary(
    name = "jarjar_runner",
    main_class = "com.eed3si9n.jarjar.Main",
    visibility = ["//visibility:public"],
    runtime_deps = ["@kotlin_rules_maven//:com_eed3si9n_jarjar_jarjar"],
)

bzl_library(
    name = "bzl",
    srcs = [
        "jarjar.bzl",
        "@bazel_tools//tools:bzl_srcs",
    ],
)
