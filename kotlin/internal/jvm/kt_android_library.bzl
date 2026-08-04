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
"""Declaration of kt_android_library rule."""

load(
    "@rules_android//rules/android_library:attrs.bzl",
    _BASE_ATTRS = "ATTRS",
)
load(
    "@rules_android//rules/android_library:rule.bzl",
    _make_rule = "make_rule",
)
load(
    "//kotlin/internal:defs.bzl",
    _KtJvmInfo = "KtJvmInfo",
    _TOOLCHAIN_TYPE = "TOOLCHAIN_TYPE",
)
load(
    "//kotlin/internal/jvm:jvm.bzl",
    _attrs = "attrs",
)
load(
    "//kotlin/internal/jvm:kt_android_library_impl.bzl",
    _kt_android_library_impl = "kt_android_library_impl",
)
load(
    "//kotlin/internal/utils:utils.bzl",
    _utils = "utils",
)

_ATTRS = _utils.add_dicts(_BASE_ATTRS, _attrs.lib_common_attr, {
    # Pass or override any attributes needed here
})

kt_android_library = _make_rule(
    implementation = _kt_android_library_impl,
    attrs = _ATTRS,
    additional_toolchains = [
        _TOOLCHAIN_TYPE,
    ],
    additional_providers = [
        _KtJvmInfo,
    ],
)
