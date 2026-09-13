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
"""Native dependencies shared by Kotlin libraries and launchers."""

load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

def collect_native_libraries(*attr_lists):
    """Collects CcInfo providers for JavaInfo.native_libraries."""
    return [target[CcInfo] for targets in attr_lists for target in targets if CcInfo in target]

def runtime_native_libraries(java_info):
    """Returns runtime shared objects, never Windows import libraries."""
    return depset([
        library.dynamic_library
        for library in java_info.transitive_native_libraries.to_list()
        if library.dynamic_library
    ])
