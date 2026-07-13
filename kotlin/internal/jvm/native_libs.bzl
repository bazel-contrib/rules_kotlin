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

"""Native library propagation and launcher support for Kotlin JVM rules."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_java//java:defs.bzl", "JavaInfo")
load("//src/main/starlark/core/compile:common.bzl", "is_windows")

def _dynamic_library(library_to_link):
    for field in [
        "resolved_symlink_dynamic_library",
        "dynamic_library",
    ]:
        artifact = getattr(library_to_link, field, None)
        if artifact:
            return artifact
    return None

def _is_shared_library(artifact):
    basename = artifact.basename.lower()
    return (
        basename.endswith(".dll") or
        basename.endswith(".dylib") or
        basename.endswith(".so") or
        ".so." in basename
    )

def _add_artifact(artifacts, artifact):
    if artifact and _is_shared_library(artifact):
        artifacts[artifact.short_path] = artifact

def _add_target_runfiles(artifacts, target):
    """Adds runtime shared libraries, including DLLs hidden by import libraries.

    On Windows, CcInfo can expose only an import library for a
    cc_binary(linkshared = True). The runtime DLL is still present in
    DefaultInfo, so inspect the files that are actually placed in runfiles.
    """
    if DefaultInfo not in target:
        return

    default_info = target[DefaultInfo]
    for artifact in default_info.files.to_list():
        _add_artifact(artifacts, artifact)

    if default_info.default_runfiles:
        for artifact in default_info.default_runfiles.files.to_list():
            _add_artifact(artifacts, artifact)

def collect_native_lib_jvm_flags(ctx, deps, runtime_deps):
    """Returns java.library.path flags for transitive native dependencies.

    Returns:
        A list containing a java.library.path flag, or an empty list when the
        target has no native dependencies.
    """
    artifacts = {}
    targets = deps + runtime_deps

    # Match rules_java's provider-based collection through the public
    # JavaInfo API. CcInfo.transitive_native_libraries() is private to
    # rules_java on older Bazel versions, so direct C++ deps are recovered
    # from their runfiles below.
    for target in targets:
        if JavaInfo in target:
            for library_to_link in target[JavaInfo].transitive_native_libraries.to_list():
                _add_artifact(artifacts, _dynamic_library(library_to_link))

        # This fallback is required for Windows DLLs and also preserves native
        # libraries propagated through a kt_jvm_library's runfiles.
        _add_target_runfiles(artifacts, target)

    native_dirs = {}
    windows = is_windows(ctx)
    runfiles_prefix = "${JAVA_RUNFILES}/" + ctx.workspace_name
    for artifact in artifacts.values():
        dirname = paths.dirname(artifact.short_path)
        if windows:
            # Bazel starts tests and `bazel run` binaries in their runfiles
            # workspace directory. Keep these paths relative because the
            # Windows native Java launcher does not expand ${JAVA_RUNFILES}
            # inside JVM flags.
            native_dirs[dirname] = None
        else:
            native_dirs[runfiles_prefix if dirname == "." else runfiles_prefix + "/" + dirname] = None

    if not native_dirs:
        return []

    separator = ";" if windows else ":"
    return ["-Djava.library.path=" + separator.join(native_dirs.keys())]

def collect_native_libraries(*attr_lists):
    """Collects CcInfo values for JavaInfo.native_libraries.

    Returns:
        The CcInfo providers found in the supplied attribute lists.
    """
    return [
        target[CcInfo]
        for attr_list in attr_lists
        for target in attr_list
        if CcInfo in target
    ]
