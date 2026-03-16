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

def _get_lib_dir(lib):
    """Returns the root-relative directory of a LibraryToLink, or None."""
    f = lib.dynamic_library
    if f == None:
        f = lib.resolved_symlink_dynamic_library
    if f == None:
        f = lib.static_library
    if f == None:
        f = lib.pic_static_library
    if f == None:
        return None
    return f.short_path.rsplit("/", 1)[0] if "/" in f.short_path else ""

def collect_native_lib_jvm_flags(ctx, deps, runtime_deps):
    """Collects native library paths and returns JVM flags.

    Collects transitive native libraries from JavaInfo providers in deps and
    runtime_deps, plus CcInfo linking_context from runtime_deps (for direct
    cc_binary(linkshared=1) dependencies). Produces a -Djava.library.path flag
    using ${JAVA_RUNFILES}/workspace_name/ prefix.

    Args:
        ctx: The rule context.
        deps: List of compile dependency targets.
        runtime_deps: List of runtime dependency targets.

    Returns:
        A list containing a single -Djava.library.path flag, or an empty list.
    """
    dirs = {}

    # Collect from JavaInfo.transitive_native_libraries (public API) across
    # both deps and runtime_deps. This picks up native libraries that were
    # propagated transitively via the native_libraries param on JavaInfo.
    for dep in deps + runtime_deps:
        if JavaInfo in dep:
            for lib in dep[JavaInfo].transitive_native_libraries.to_list():
                d = _get_lib_dir(lib)
                if d:
                    dirs[d] = True

    # Also collect from CcInfo.linking_context on runtime_deps for direct
    # cc_binary/cc_library dependencies that don't provide JavaInfo.
    for dep in runtime_deps:
        if CcInfo in dep and JavaInfo not in dep:
            for linker_input in dep[CcInfo].linking_context.linker_inputs.to_list():
                for lib in linker_input.libraries:
                    d = _get_lib_dir(lib)
                    if d:
                        dirs[d] = True

    if not dirs:
        return []

    prefix = "${JAVA_RUNFILES}/" + ctx.workspace_name + "/"
    return ["-Djava.library.path=" + ":".join([prefix + d for d in dirs.keys()])]

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
