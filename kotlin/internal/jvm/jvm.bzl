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
"""Compatibility exports. Load rule declarations from their individual modules."""

load("//kotlin/internal/jvm:attrs.bzl", _attrs = "attrs")
load(
    "//kotlin/internal/jvm:compiler_plugins.bzl",
    _kt_compiler_plugin = "kt_compiler_plugin",
    _kt_ksp_plugin = "kt_ksp_plugin",
    _kt_plugin_cfg = "kt_plugin_cfg",
)
load("//kotlin/internal/jvm:kt_jvm_binary.bzl", _kt_jvm_binary = "kt_jvm_binary")
load("//kotlin/internal/jvm:kt_jvm_import.bzl", _kt_jvm_import = "kt_jvm_import")
load("//kotlin/internal/jvm:kt_jvm_library.bzl", _kt_jvm_library = "kt_jvm_library")
load("//kotlin/internal/jvm:kt_jvm_test.bzl", _kt_jvm_test = "kt_jvm_test")

attrs = _attrs
kt_compiler_plugin = _kt_compiler_plugin
kt_ksp_plugin = _kt_ksp_plugin
kt_plugin_cfg = _kt_plugin_cfg
kt_jvm_binary = _kt_jvm_binary
kt_jvm_import = _kt_jvm_import
kt_jvm_library = _kt_jvm_library
kt_jvm_test = _kt_jvm_test
