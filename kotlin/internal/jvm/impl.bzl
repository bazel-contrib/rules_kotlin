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
"""Compatibility exports. Load rule implementations from their individual modules."""

load(
    "//kotlin/internal/jvm:compiler_plugins.bzl",
    _kt_compiler_deps_aspect_impl = "kt_compiler_deps_aspect_impl",
    _kt_compiler_plugin_impl = "kt_compiler_plugin_impl",
    _kt_ksp_plugin_impl = "kt_ksp_plugin_impl",
    _kt_plugin_cfg_impl = "kt_plugin_cfg_impl",
)
load("//kotlin/internal/jvm:kt_jvm_binary.bzl", _kt_jvm_binary_impl = "kt_jvm_binary_impl")
load("//kotlin/internal/jvm:kt_jvm_import.bzl", _kt_jvm_import_impl = "kt_jvm_import_impl")
load("//kotlin/internal/jvm:kt_jvm_library.bzl", _kt_jvm_library_impl = "kt_jvm_library_impl")
load("//kotlin/internal/jvm:kt_jvm_test.bzl", _kt_jvm_test_impl = "kt_jvm_test_impl")

kt_compiler_deps_aspect_impl = _kt_compiler_deps_aspect_impl
kt_compiler_plugin_impl = _kt_compiler_plugin_impl
kt_ksp_plugin_impl = _kt_ksp_plugin_impl
kt_plugin_cfg_impl = _kt_plugin_cfg_impl
kt_jvm_binary_impl = _kt_jvm_binary_impl
kt_jvm_import_impl = _kt_jvm_import_impl
kt_jvm_library_impl = _kt_jvm_library_impl
kt_jvm_junit_test_impl = _kt_jvm_test_impl
