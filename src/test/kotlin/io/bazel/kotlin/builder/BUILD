load("@rules_java//java:defs.bzl", "java_library")

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
package(default_visibility = ["//src:__subpackages__"])

_COMMON_DEPS = [
    "//src/main/kotlin/io/bazel/kotlin/builder/toolchain",
    "//src/main/kotlin/io/bazel/kotlin/builder/utils:utils",
    "//src/main/protobuf:kotlin_model_java_proto",
    "//src/main/protobuf:deps_java_proto",
    "@rules_kotlin_maven_dev//:com_google_truth_truth",
    "@rules_kotlin_maven_dev//:junit_junit",
    "@rules_kotlin_maven_dev//:com_google_guava_guava",
    "@rules_kotlin_maven_dev//:com_google_code_findbugs_jsr305",
]

java_library(
    name = "test_lib",
    testonly = 1,
    srcs = [
        "Deps.java",
        "DirectoryType.java",
        "KotlinAbstractTestBuilder.java",
        "KotlinJvmTestBuilder.java",
    ],
    data = [
        "@rules_kotlin_maven//:org_jetbrains_kotlin_kotlin_compiler_embeddable",
        "@rules_kotlin_maven//:org_jetbrains_kotlin_kotlin_daemon_client",
    ],
    exports = _COMMON_DEPS,
    runtime_deps = [
        "//kotlin/compiler:kotlin-stdlib",
        "@bazel_tools//tools/jdk:JacocoCoverage",
    ],
    deps = _COMMON_DEPS + [
        "//kotlin/compiler:kotlin-reflect",
        "//src/main/kotlin/io/bazel/kotlin/builder/tasks",
        "//third_party:autovalue",
    ],
)

test_suite(
    name = "builder_tests",
    tests = [
        "//src/test/kotlin/io/bazel/kotlin/builder/tasks:tasks_tests",
        "//src/test/kotlin/io/bazel/kotlin/builder/utils:utils_tests",
    ],
    visibility = ["//visibility:public"],
)
