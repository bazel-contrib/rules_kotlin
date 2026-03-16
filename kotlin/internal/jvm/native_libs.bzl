# Copyright 2024 The Bazel Authors. All rights reserved.
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

"""Utilities for collecting native library paths for kt_jvm_binary/kt_jvm_test."""

load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_java//java:defs.bzl", "JavaInfo")

def _collect_native_deps_dirs(libraries):
    """Extracts unique directory paths from a depset of LibraryToLink.

    Args:
        libraries: depset of LibraryToLink objects

    Returns:
        A list of unique root-relative directory paths containing native libraries.
    """
    dirs = {}
    for lib in libraries.to_list():
        f = lib.dynamic_library
        if f == None:
            f = lib.resolved_symlink_dynamic_library
        if f == None:
            f = lib.static_library
        if f == None:
            f = lib.pic_static_library
        if f != None:
            dirs[f.short_path.rsplit("/", 1)[0] if "/" in f.short_path else ""] = True
    return [d for d in dirs.keys() if d]

def collect_native_lib_jvm_flags(ctx, runtime_deps):
    """Collects native library paths from runtime_deps and returns JVM flags.

    Mirrors rules_java's behavior: collects transitive native libraries from both
    JavaInfo and CcInfo providers in runtime_deps, and produces a
    -Djava.library.path flag using ${JAVA_RUNFILES}/workspace_name/ prefix.

    Args:
        ctx: The rule context.
        runtime_deps: List of runtime dependency targets.

    Returns:
        A list containing a single -Djava.library.path flag, or an empty list.
    """
    native_libs_depsets = []
    for dep in runtime_deps:
        if JavaInfo in dep:
            native_libs_depsets.append(dep[JavaInfo].transitive_native_libraries)
        if CcInfo in dep:
            cc_info = dep[CcInfo]
            if hasattr(cc_info, "_legacy_transitive_native_libraries"):
                native_libs_depsets.append(cc_info._legacy_transitive_native_libraries)
            else:
                native_libs_depsets.append(cc_info.transitive_native_libraries())

    if not native_libs_depsets:
        return []

    native_libs_dirs = _collect_native_deps_dirs(depset(transitive = native_libs_depsets))
    if not native_libs_dirs:
        return []

    prefix = "${JAVA_RUNFILES}/" + ctx.workspace_name + "/"
    return ["-Djava.library.path=" + ":".join([prefix + d for d in native_libs_dirs])]

def collect_native_libraries(*attr_lists):
    """Collects CcInfo providers from dependency attribute lists for JavaInfo's native_libraries param.

    Args:
        *attr_lists: Variable number of dependency target lists (e.g., deps, runtime_deps, exports).

    Returns:
        A list of CcInfo providers, or an empty list.
    """
    cc_infos = []
    for attr_list in attr_lists:
        for dep in attr_list:
            if CcInfo in dep:
                cc_infos.append(dep[CcInfo])
    return cc_infos
