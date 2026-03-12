load("@rules_java//java:defs.bzl", "java_library", "java_plugin")
load("//kotlin:core.bzl", "kt_plugin_cfg")
load("//kotlin:jvm.bzl", "kt_jvm_library")

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

java_plugin(
    name = "autovalue",
    generates_api = 1,
    processor_class = "com.google.auto.value.processor.AutoValueProcessor",
    deps = ["@rules_kotlin_maven_dev//:com_google_auto_value_auto_value"],
)

java_plugin(
    name = "autoservice",
    generates_api = 0,
    processor_class = "com.google.auto.service.processor.AutoServiceProcessor",
    deps = ["@rules_kotlin_maven_dev//:com_google_auto_service_auto_service"],
)

java_plugin(
    name = "autovalue_no_processor_class",
    generates_api = 1,
    deps = ["@rules_kotlin_maven_dev//:com_google_auto_value_auto_value_annotations"],
)

kt_jvm_library(
    name = "ap_kotlin",
    srcs = ["kotlin/TestKtValue.kt"],
    plugins = [":autovalue"],
    deps = ["@rules_kotlin_maven_dev//:com_google_auto_value_auto_value_annotations"],
)

kt_jvm_library(
    name = "ap_kotlin_mixed_no_plugin",
    srcs = [
        "java/TestAPNoGenReferences.java",
        "kotlin/TestKtAPNoGenReference.kt",
    ],
    deps = ["@rules_kotlin_maven_dev//:com_google_auto_value_auto_value_annotations"],
)

kt_jvm_library(
    name = "ap_kotlin_mixed",
    srcs = [
        "java/TestAutoValue.java",
        "kotlin/TestKtValue.kt",
    ],
    plugins = [":autovalue"],
    deps = ["@rules_kotlin_maven_dev//:com_google_auto_value_auto_value_annotations"],
)

kt_plugin_cfg(
    name = "autovalue_no_identifiers",
    options = {
        "com.google.auto.value.OmitIdentifiers": ["true"],
    },
    plugin = "//kotlin/compiler:kapt",
    deps = [
        ":autovalue",
    ],
)

kt_jvm_library(
    name = "ap_kotlin_mixed_no_identifier",
    srcs = [
        "java/TestAutoValueNoIdentifiers.java",
        "kotlin/TestKtValueNoIdentifier.kt",
    ],
    plugins = [
        ":autovalue_no_identifiers",
    ],
    tags = [
        "trace",
    ],
    visibility = [
        "//src/test:__subpackages__",
    ],
    deps = ["@rules_kotlin_maven_dev//:com_google_auto_value_auto_value_annotations"],
)

kt_jvm_library(
    name = "ap_kotlin_resources",
    srcs = ["kotlin/TestKtService.kt"],
    plugins = [":autoservice"],
    deps = ["@rules_kotlin_maven_dev//:com_google_auto_service_auto_service_annotations"],
)

kt_jvm_library(
    name = "ap_kotlin_resources_mixed",
    srcs = [
        "java/TestJavaService.java",
        "kotlin/TestKtService.kt",
    ],
    plugins = [":autoservice"],
    deps = ["@rules_kotlin_maven_dev//:com_google_auto_service_auto_service_annotations"],
)

kt_jvm_library(
    name = "ap_kotlin_mixed_multiple_plugins",
    srcs = [
        "java/TestAutoValue.java",
        "java/TestJavaService.java",
        "kotlin/TestKtService.kt",
        "kotlin/TestKtValue.kt",
    ],
    plugins = [
        ":autoservice",
        ":autovalue",
    ],
    deps = [
        "@rules_kotlin_maven_dev//:com_google_auto_service_auto_service_annotations",
        "@rules_kotlin_maven_dev//:com_google_auto_value_auto_value_annotations",
    ],
)

kt_jvm_library(
    name = "ap_kotlin_mixed_multiple_plugins_one_without_processor_class",
    srcs = [
        "java/TestAPNoGenReferences.java",
        "java/TestJavaService.java",
        "kotlin/TestKtAPNoGenReference.kt",
        "kotlin/TestKtService.kt",
    ],
    plugins = [
        ":autoservice",
        ":autovalue_no_processor_class",
    ],
    deps = [
        "@rules_kotlin_maven_dev//:com_google_auto_service_auto_service_annotations",
        "@rules_kotlin_maven_dev//:com_google_auto_value_auto_value_annotations",
    ],
)

java_library(
    name = "library_exporting_autovalue_and_junit",
    exported_plugins = [
        ":autovalue",
        ":autoservice",
    ],
)

kt_jvm_library(
    name = "ap_kotlin_mixed_inherit_plugin_via_exported_deps",
    srcs = [
        "java/TestAutoValue.java",
        "java/TestJavaService.java",
        "kotlin/TestKtService.kt",
        "kotlin/TestKtValue.kt",
    ],
    plugins = [":autovalue"],
    deps = [
        "library_exporting_autovalue_and_junit",
        "@rules_kotlin_maven_dev//:com_google_auto_service_auto_service_annotations",
        "@rules_kotlin_maven_dev//:com_google_auto_value_auto_value_annotations",
    ],
)

filegroup(
    name = "kapt",
    srcs = [
        ":ap_kotlin.jar",
        ":ap_kotlin_mixed",
        ":ap_kotlin_mixed_inherit_plugin_via_exported_deps",
        ":ap_kotlin_mixed_multiple_plugins",
        ":ap_kotlin_mixed_multiple_plugins-sources.jar",
        ":ap_kotlin_mixed_multiple_plugins_one_without_processor_class",
        ":ap_kotlin_mixed_no_plugin",
        ":ap_kotlin_resources",
        ":ap_kotlin_resources_mixed",
    ],
    visibility = ["//visibility:public"],
)
