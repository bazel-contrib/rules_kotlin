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
load("@rules_java//java:defs.bzl", "JavaInfo")

def collect_native_libraries(*attr_lists):
    """Collects CcInfo providers for JavaInfo.native_libraries."""
    return [target[CcInfo] for targets in attr_lists for target in targets if CcInfo in target]

def _java_native_libraries(java_info):
    """Returns runtime shared objects, never Windows import libraries."""
    return depset([
        library.dynamic_library
        for library in java_info.transitive_native_libraries.to_list()
        if library.dynamic_library
    ])

_NativeLibrariesInfo = provider("Runtime native libraries, including Windows DLL outputs.", fields = ["libraries"])

def _native_libraries_aspect_impl(target, ctx):
    # Bazel 8's Windows cc_binary exposes its import library in CcInfo but
    # omits the DLL. Follow dependency edges to the C++ target that owns it;
    # scanning Java runfiles would also pick up unrelated DLLs in data.
    if getattr(ctx.rule.attr, "neverlink", False):
        return [_NativeLibrariesInfo(libraries = depset())]
    transitive = [
        dep[_NativeLibrariesInfo].libraries
        for attr in ["deps", "runtime_deps", "exports"]
        for dep in getattr(ctx.rule.attr, attr, [])
        if _NativeLibrariesInfo in dep
    ]
    if JavaInfo in target:
        transitive.append(_java_native_libraries(target[JavaInfo]))
    dlls = [f for f in target[DefaultInfo].files.to_list() if f.extension.lower() == "dll"] if CcInfo in target else []
    return [_NativeLibrariesInfo(libraries = depset(dlls, transitive = transitive))]

native_libraries_aspect = aspect(
    implementation = _native_libraries_aspect_impl,
    attr_aspects = ["deps", "runtime_deps", "exports"],
)

def runtime_native_libraries(ctx, java_info):
    """Collects runtime shared objects, including Windows cc_binary DLLs."""
    return depset(transitive = [_java_native_libraries(java_info)] + [
        dep[_NativeLibrariesInfo].libraries
        for dep in ctx.attr.deps + ctx.attr.runtime_deps
        if _NativeLibrariesInfo in dep
    ])
