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
# limitations under the License.#
"""Internal constants and provider definitions."""

load(
    "//src/main/starlark/core/compile:common.bzl",
    _JAVA_RUNTIME_TOOLCHAIN_TYPE = "JAVA_RUNTIME_TOOLCHAIN_TYPE",
    _JAVA_TOOLCHAIN_TYPE = "JAVA_TOOLCHAIN_TYPE",
    _KtJvmInfo = "KtJvmInfo",
)
load(
    "//src/main/starlark/core/plugin:providers.bzl",
    _KspPluginInfo = "KspPluginInfo",
    _KtCompilerPluginInfo = "KtCompilerPluginInfo",
    _KtCompilerPluginOption = "KtCompilerPluginOption",
    _KtPluginConfiguration = "KtPluginConfiguration",
)

# The Kotlin Toolchain type.
TOOLCHAIN_TYPE = "%s" % Label("//kotlin/internal:kt_toolchain_type")

# Java toolchains
JAVA_TOOLCHAIN_TYPE = _JAVA_TOOLCHAIN_TYPE
JAVA_RUNTIME_TOOLCHAIN_TYPE = _JAVA_RUNTIME_TOOLCHAIN_TYPE

# The name of the Kotlin compiler workspace.
KT_COMPILER_REPO = "com_github_jetbrains_kotlin"

# The name of the KSP compiler plugin workspace
KSP_COMPILER_PLUGIN_REPO = "com_github_google_ksp"

KtJvmInfo = _KtJvmInfo

KtCompilerPluginInfo = _KtCompilerPluginInfo

KspPluginInfo = _KspPluginInfo

# buildifier: disable=name-conventions
KtCompilerPluginOption = _KtCompilerPluginOption

# buildifier: disable=name-conventions
KtPluginConfiguration = _KtPluginConfiguration
