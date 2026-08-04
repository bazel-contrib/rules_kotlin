load("@bazel_lib//lib:copy_file.bzl", "copy_file")
load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("@rules_java//java:defs.bzl", "java_binary", "java_library", "java_plugin")
load("//src/main/starlark/release:packager.bzl", "release_archive")

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

java_plugin(
    name = "autovalue_plugin",
    generates_api = 1,
    processor_class = "com.google.auto.value.processor.AutoValueProcessor",
    visibility = ["//visibility:private"],
    deps = ["@kotlin_rules_maven//:com_google_auto_value_auto_value"],
)

java_library(
    name = "autovalue",
    exported_plugins = [":autovalue_plugin"],
    neverlink = 1,
    exports = ["@kotlin_rules_maven//:com_google_auto_value_auto_value_annotations"],
)

java_plugin(
    name = "dagger_component_plugin",
    generates_api = 1,
    processor_class = "dagger.internal.codegen.ComponentProcessor",
    visibility = ["//visibility:private"],
    deps = [
        "@kotlin_rules_maven_test//:com_google_dagger_dagger_compiler",
    ],
)

java_library(
    name = "dagger",
    exported_plugins = [":dagger_component_plugin"],
    exports = [
        "@kotlin_rules_maven_test//:com_google_dagger_dagger",
        "@kotlin_rules_maven_test//:javax_inject_javax_inject",
    ],
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

release_archive(
    name = "pkg",
    srcs = [
        "empty.jar",
        "empty.jdeps",
        "jarjar.bzl",
        "java_stub_template.txt",
    ],
    src_map = {
        "BUILD.release.bazel": "BUILD.bazel",
        "jarjar_runner_deploy.jar": "jarjar.jar",
    },
)
