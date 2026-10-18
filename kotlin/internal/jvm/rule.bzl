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
"""Shared outputs and toolchains for Kotlin JVM compilation rules."""

load("@bazel_features//:features.bzl", "bazel_features")
load(
    "//kotlin/internal:defs.bzl",
    _JAVA_RUNTIME_TOOLCHAIN_TYPE = "JAVA_RUNTIME_TOOLCHAIN_TYPE",
    _JAVA_TOOLCHAIN_TYPE = "JAVA_TOOLCHAIN_TYPE",
    _TOOLCHAIN_TYPE = "TOOLCHAIN_TYPE",
)

# Toolchain type for the Windows launcher maker
_LAUNCHER_MAKER_TOOLCHAIN_TYPE = "@bazel_tools//tools/launcher:launcher_maker_toolchain_type"

COMMON_OUTPUTS = dict(
    jar = "%{name}.jar",
    # The params file, declared here so that validate it can be validated for testing.
    #    jar_2_params = "%{name}.jar-2.params",
    srcjar = "%{name}-sources.jar",
)

COMMON_TOOLCHAINS = [
    _TOOLCHAIN_TYPE,
    _JAVA_TOOLCHAIN_TYPE,
]

RUNNABLE_COMMON_TOOLCHAINS = [
    _JAVA_RUNTIME_TOOLCHAIN_TYPE,
] + ([config_common.toolchain_type(_LAUNCHER_MAKER_TOOLCHAIN_TYPE, mandatory = False)] if bazel_features.rules._has_launcher_maker_toolchain else [])
