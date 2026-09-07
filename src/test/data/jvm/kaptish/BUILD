# Copyright 2026 The Bazel Authors. All rights reserved.
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

load("@rules_java//java:defs.bzl", "java_plugin")
load("//kotlin:core.bzl", "define_kt_toolchain")
load("//kotlin:jvm.bzl", "kt_jvm_library")

package(default_visibility = ["//visibility:private"])

# Define a kaptish-enabled toolchain for testing
define_kt_toolchain(
    name = "kaptish_toolchain",
    experimental_kaptish_enabled = True,
)

java_plugin(
    name = "autovalue",
    generates_api = 1,
    processor_class = "com.google.auto.value.processor.AutoValueProcessor",
    deps = ["@kotlin_rules_maven//:com_google_auto_value_auto_value"],
)

java_plugin(
    name = "autoservice",
    generates_api = 0,
    processor_class = "com.google.auto.service.processor.AutoServiceProcessor",
    deps = ["@kotlin_rules_maven_test//:com_google_auto_service_auto_service"],
)

# Kaptish test: Kotlin-only with AutoValue
kt_jvm_library(
    name = "kaptish_kotlin",
    srcs = ["kotlin/TestKaptishValue.kt"],
    plugins = [":autovalue"],
    deps = ["@kotlin_rules_maven//:com_google_auto_value_auto_value_annotations"],
)

# Kaptish test: Kotlin-only with AutoService (resource generation)
kt_jvm_library(
    name = "kaptish_kotlin_resources",
    srcs = ["kotlin/TestKaptishService.kt"],
    plugins = [":autoservice"],
    deps = ["@kotlin_rules_maven_test//:com_google_auto_service_auto_service_annotations"],
)

# Kaptish disabled test: should use KAPT instead
kt_jvm_library(
    name = "kaptish_disabled",
    srcs = ["kotlin/TestKaptishValue.kt"],
    plugins = [":autovalue"],
    tags = ["kaptish_disabled"],
    deps = ["@kotlin_rules_maven//:com_google_auto_value_auto_value_annotations"],
)

filegroup(
    name = "kaptish",
    srcs = [
        ":kaptish_disabled.jar",
        ":kaptish_kotlin.jar",
        ":kaptish_kotlin_resources.jar",
    ],
    visibility = ["//visibility:public"],
)
