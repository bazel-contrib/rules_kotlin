load("@rules_license//rules:license.bzl", "license")
load("//kotlin:lint.bzl", "ktlint_config")

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
package(default_applicable_licenses = [":license"])

exports_files(["MODULE.bazel"])

# Integration tests reference this repository with paths relative to their fixture workspace.
# Keep the repository sources as declared test inputs so those paths resolve within runfiles.
filegroup(
    name = "local_repository_files",
    srcs = [
        ".bazelignore",
        ".bazelrc",
        ".bazelversion",
        "BUILD",
        "LICENSE",
        "MODULE.bazel",
        "MODULE.bazel.lock",
        "kotlin_rules_maven_install.json",
        "//kotlin:all_files",
        "//kotlin/compiler:all_files",
        "//kotlin/internal:all_files",
        "//kotlin/internal/jvm:all_files",
        "//kotlin/internal/lint:all_files",
        "//kotlin/internal/utils:all_files",
        "//kotlin/settings:all_files",
        "//src/main/kotlin:all_files",
        "//src/main/kotlin/io/bazel/kotlin/builder/cmd:all_files",
        "//src/main/kotlin/io/bazel/kotlin/builder/tasks:all_files",
        "//src/main/kotlin/io/bazel/kotlin/builder/toolchain:all_files",
        "//src/main/kotlin/io/bazel/kotlin/builder/utils:all_files",
        "//src/main/kotlin/io/bazel/kotlin/builder/utils/jars:all_files",
        "//src/main/kotlin/io/bazel/kotlin/compiler:all_files",
        "//src/main/kotlin/io/bazel/kotlin/ksp2:all_files",
        "//src/main/kotlin/io/bazel/kotlin/plugin:all_files",
        "//src/main/kotlin/io/bazel/kotlin/plugin/jdeps:all_files",
        "//src/main/kotlin/io/bazel/worker:all_files",
        "//src/main/protobuf:all_files",
        "//src/main/starlark:all_files",
        "//src/main/starlark/core:all_files",
        "//src/main/starlark/core/compile:all_files",
        "//src/main/starlark/core/compile/cli:all_files",
        "//src/main/starlark/core/options:all_files",
        "//src/main/starlark/core/plugin:all_files",
        "//src/main/starlark/core/repositories:all_files",
        "//src/main/starlark/core/repositories/kotlin:all_files",
        "//third_party:all_files",
    ],
    visibility = ["//:__subpackages__"],
)

license(
    name = "license",
    package_name = "rules_kotlin",
    license_kinds = ["@rules_license//licenses/spdx:Apache-2.0"],
    license_text = "LICENSE",
    visibility = ["//visibility:public"],
)

filegroup(
    name = "editorconfig",
    srcs = [".editorconfig"],
)

ktlint_config(
    name = "ktlint_editorconfig",
    android_rules_enabled = False,
    editorconfig = "//:editorconfig",
    experimental_rules_enabled = False,
    visibility = ["//visibility:public"],
)
