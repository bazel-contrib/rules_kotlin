load("@rules_java//java:defs.bzl", "java_library", "java_plugin")
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

genrule(
    name = "empty",
    srcs = [
        "empty-definately-not-binary-jar.txt",
    ],
    outs = [
        "empty.jar",
    ],
    cmd = "cp $(location empty-definately-not-binary-jar.txt) $@",
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
        "@kotlin_rules_maven//:com_google_dagger_dagger_compiler",
    ],
)

java_library(
    name = "dagger",
    exported_plugins = [":dagger_component_plugin"],
    exports = [
        "@kotlin_rules_maven//:com_google_dagger_dagger",
        "@kotlin_rules_maven//:javax_inject_javax_inject",
    ],
)

release_archive(
    name = "pkg",
    srcs = [
        "empty.jar",
        "empty.jdeps",
        "java_stub_template.txt",
    ],
    src_map = {
        "BUILD.release.bazel": "BUILD.bazel",
    },
)
