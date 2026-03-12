load("@buildifier_prebuilt//:rules.bzl", "buildifier")
load("@rules_multirun//:defs.bzl", "multirun")
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
load("//src/main/starlark/release:packager.bzl", "release_archive")

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

# The entire test suite excluding local tests.
test_suite(
    name = "all_tests",
    tests = [
        "//src/test/kotlin/io/bazel/kotlin:assertion_tests",
        "//src/test/kotlin/io/bazel/kotlin/builder:builder_tests",
        "//src/test/kotlin/io/bazel/worker:worker_tests",
        "//src/test/starlark:convert_tests",
        "//src/test/starlark:resource_strip_prefix_tests",
    ],
)

#  Local tests. Tests that shouldn't be run on the CI server.
test_suite(
    name = "all_local_tests",
    tests = [
        ":all_tests",
        "//src/test/kotlin/io/bazel/kotlin:local_assertion_tests",
        "//src/test/kotlin/io/bazel/worker:local_worker_tests",
        "//src/test/starlark:convert_tests",
        "//src/test/starlark:resource_strip_prefix_tests",
    ],
)

# Release target.
release_archive(
    name = "rules_kotlin_release",
    srcs = [
        "rules_kotlin_maven_install.json",
    ],
    src_map = {
        "BUILD.release.bazel": "BUILD.bazel",
        "MODULE.release.bazel": "MODULE.bazel",
    },
    deps = [
        "//kotlin:pkg",
        "//src/main/kotlin:pkg",
        "//src/main/starlark:pkg",
        "//third_party:pkg",
    ],
)

# This target collects all of the parent workspace files needed by the child workspaces.
filegroup(
    name = "release_repositories",
    # Include every package that is required by the child workspaces.
    srcs = [
        ":rules_kotlin_release",
    ],
    visibility = ["//:__subpackages__"],
)

multirun(
    name = "ktlint_fix_all",
    commands = [
        "//src/main/kotlin/io/bazel/kotlin/builder/cmd:build_lib_ktlint_fix",
        "//src/main/kotlin/io/bazel/kotlin/builder/cmd:ksp2_lib_ktlint_fix",
        "//src/main/kotlin/io/bazel/kotlin/builder/cmd:merge_jdeps_lib_ktlint_fix",
        "//src/main/kotlin/io/bazel/kotlin/builder/tasks:tasks_ktlint_fix",
        "//src/main/kotlin/io/bazel/kotlin/builder/toolchain:toolchain_ktlint_fix",
        "//src/main/kotlin/io/bazel/kotlin/builder/utils:utils_ktlint_fix",
        "//src/main/kotlin/io/bazel/kotlin/builder/utils/jars:jars_ktlint_fix",
        "//src/main/kotlin/io/bazel/kotlin/compiler:compiler_ktlint_fix",
        "//src/main/kotlin/io/bazel/kotlin/ksp2:ksp2_ktlint_fix",
        "//src/main/kotlin/io/bazel/kotlin/plugin:skip-code-gen-lib_ktlint_fix",
        "//src/main/kotlin/io/bazel/kotlin/plugin/jdeps:jdeps-gen-lib_ktlint_fix",
        "//src/main/kotlin/io/bazel/worker:worker_ktlint_fix",
    ],
    jobs = 0,
)

# TODO[https://github.com/bazelbuild/rules_kotlin/issues/1395]: Must be run with `--config=deprecated`
buildifier(
    name = "buildifier.check",
    exclude_patterns = [
        "./.git/*",
        "./.ijwb/*",
    ],
    lint_mode = "warn",
    lint_warnings = [
        "+unsorted-dict-items",
        "-confusing-name",
        "-constant-glob",
        "-duplicated-name",
        "-function-docstring",
        "-function-docstring-args",
        "-function-docstring-header",
        "-module-docstring",
        "-name-conventions",
        "-no-effect",
        "-constant-glob",
        "-provider-params",
        "-print",
        "-rule-impl-return",
        "-bzl-visibility",
        "-unnamed-macro",
        "-uninitialized",
        "-unreachable",
    ],
)

buildifier(
    name = "buildifier.fix",
    exclude_patterns = [
        "./.git/*",
    ],
    lint_mode = "fix",
    lint_warnings = [
        "+unsorted-dict-items",
    ],
)
