# Copyright 2020 The Bazel Authors. All rights reserved.
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
load(":compiler.bzl", "kt_configure_compiler")
load(":kapt.bzl", "kapt_compiler_plugin")
load(":ksp.bzl", "kt_configure_ksp")

filegroup(
    name = "all_files",
    srcs = glob(["*"]),
    visibility = ["//:__subpackages__"],
)

package(default_visibility = ["//visibility:public"])

# Configures the compiler
kt_configure_compiler()

# Configures the KSP plugins
kt_configure_ksp()

kapt_compiler_plugin(
    name = "kapt",
    id = "org.jetbrains.kotlin.kapt3",
)
