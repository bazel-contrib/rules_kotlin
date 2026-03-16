load("@rules_java//java:defs.bzl", "java_binary", "java_library")
load("//kotlin:jvm.bzl", "kt_jvm_binary", "kt_jvm_library")

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
package(default_visibility = ["//visibility:private"])

kt_jvm_binary(
    name = "test_module_name_bin",
    srcs = glob(["helloworld/Main.kt"]),
    main_class = "helloworld.Main",
)

kt_jvm_library(
    name = "test_module_name_lib",
    srcs = ["helloworld/Main.kt"],
)

kt_jvm_library(
    name = "test_module_name_attr_lib",
    srcs = glob(["helloworld/Main.kt"]),
    module_name = "hello-module",
)

# a test resource library.
java_library(
    name = "resourcejar",
    resource_strip_prefix = "src/test/data/jvm/basic/resourcejar",
    resources = glob(["resourcejar/**"]),
)

kt_jvm_library(
    name = "test_embed_resources",
    srcs = glob(["testresources/src/*.kt"]),
    resources = glob(["testresources/resources/**/*"]),
    visibility = ["//visibility:public"],
)

kt_jvm_library(
    name = "test_merge_resourcesjar",
    srcs = glob(["testresources/src/*.kt"]),
    resource_jars = [":resourcejar"],
    visibility = ["//visibility:public"],
)

kt_jvm_library(
    name = "test_embed_resources_strip_prefix",
    srcs = glob(["testresources/src/*.kt"]),
    resource_strip_prefix = "src/test/data/jvm/basic/testresources/resources",
    resources = glob(["testresources/resources/**/*"]),
)

kt_jvm_library(
    name = "conventional_strip_resources",
    srcs = glob(["testresources/src/*.kt"]),
    resources = glob([
        "conventional_strip_resources/src/main/java/**/*",
        "conventional_strip_resources/src/test/java/**/*",
        "conventional_strip_resources/src/main/resources/**/*",
        "conventional_strip_resources/src/test/resources/**/*",
    ]),
)

kt_jvm_library(
    name = "propagation_test_exporter_lib",
    srcs = ["propagation/Stub.kt"],
    exports = ["@kotlin_rules_maven//:junit_junit"],
)

kt_jvm_library(
    name = "propagation_test_runtime_lib",
    srcs = ["propagation/Stub.kt"],
    runtime_deps = ["@kotlin_rules_maven//:junit_junit"],
)

java_binary(
    name = "propagation_ct_consumer",
    srcs = ["propagation/CompileTimeDependent.java"],
    main_class = "testing.CompileTimeDependent",
    deps = [":propagation_test_exporter_lib"],
)

java_binary(
    name = "propagation_rt_via_export_consumer",
    srcs = ["propagation/RuntimeDependent.java"],
    main_class = "testing.RuntimeDependent",
    deps = [":propagation_test_exporter_lib"],
)

java_binary(
    name = "propagation_rt_via_runtime_deps_consumer",
    srcs = ["propagation/RuntimeDependent.java"],
    main_class = "testing.RuntimeDependent",
    deps = [":propagation_test_runtime_lib"],
)

kt_jvm_library(
    name = "test_associates_library",
    srcs = ["test_friends/Service.kt"],
    visibility = ["//src/test/kotlin:__subpackages__"],
)

filegroup(
    name = "basic",
    srcs = [
        ":conventional_strip_resources.jar",
        ":propagation_ct_consumer",
        ":propagation_rt_via_export_consumer",
        ":propagation_rt_via_runtime_deps_consumer",
        ":test_embed_resources.jar",
        ":test_embed_resources_strip_prefix.jar",
        ":test_merge_resourcesjar.jar",
        ":test_module_name_attr_lib",
        ":test_module_name_bin",
        ":test_module_name_bin.jar",
        ":test_module_name_lib",
        ":test_module_name_lib-sources.jar",
    ],
    visibility = ["//visibility:public"],
)
