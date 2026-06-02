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
load("@bazel_skylib//lib:sets.bzl", _sets = "sets")
load(
    "@rules_java//java:defs.bzl",
    "JavaInfo",
)
load("//kotlin/internal/jvm:associates.bzl", _associate_utils = "associate_utils")
load("//src/main/starlark/core/compile:common.bzl", "KtJvmInfo")

def _java_info(target):
    return target[JavaInfo] if JavaInfo in target else None

def _java_info_snapshot_jars(target):
    java_info = _java_info(target)
    if java_info == None:
        return depset()
    return java_info.compile_jars

def _jvm_deps(ctx, toolchains, associate_deps, deps = [], deps_java_infos = [], exports = [], runtime_deps = []):
    """Encapsulates jvm dependency metadata."""
    associates = _associate_utils.get_associates(
        ctx,
        toolchains = toolchains,
        associates = associate_deps,
    )
    dep_infos = (
        deps_java_infos +
        [_java_info(d) for d in deps] +
        associates.dep_infos +
        [toolchains.kt.jvm_stdlibs]
    )

    prune_transitive_deps = (toolchains.kt.experimental_prune_transitive_deps and
                             not "kt_experimental_prune_transitive_deps_incompatible" in ctx.attr.tags)

    # Reduced classpath, exclude transitive deps from compilation
    if prune_transitive_deps:
        transitive = [
            d.compile_jars
            for d in dep_infos
        ]
    else:
        transitive = [
            d.compile_jars
            for d in dep_infos
        ] + [
            d.transitive_compile_time_jars
            for d in dep_infos
        ]

    # Put associate jars FIRST (as direct) so they appear first on the classpath.
    # This ensures that when the same class exists in both an associate jar and a regular dep,
    # the associate's version is found first. This is critical for internal visibility to work
    # correctly when there are split packages across modules.
    compile_depset_list = depset(direct = associates.jars.to_list(), transitive = transitive).to_list()
    compile_depset_list_filtered = [jar for jar in compile_depset_list if not _sets.contains(associates.abi_jar_set, jar)]

    # Note: We intentionally do NOT prune deps for Java compilation.
    # While Kotlin can compile with a pruned classpath, javac needs to resolve all types
    # referenced in class file signatures and annotations from dependencies.
    # When javac reads an ABI jar containing a method like `foo(SomeType param)`,
    # it needs SomeType on the classpath even if the source code doesn't use it directly.
    # This differs from rules_jvm which uses jvm-inc-builder for Java compilation.
    pruned_deps_for_java = None

    # Collect classpath snapshots from the dependency graph that contributes snapshots.
    # This includes deps, associates, and exports because exported jars participate in downstream
    # compile classpaths and must invalidate incremental compilation when their ABI changes.
    snapshot_sources = deps + associate_deps + exports
    classpath_snapshots = depset(
        direct = [
            getattr(d[KtJvmInfo], "classpath_snapshot", None)
            for d in snapshot_sources
            if KtJvmInfo in d and getattr(d[KtJvmInfo], "classpath_snapshot", None) != None
        ],
        transitive = [
            getattr(d[KtJvmInfo], "transitive_classpath_snapshots", None)
            for d in snapshot_sources
            if KtJvmInfo in d and getattr(d[KtJvmInfo], "transitive_classpath_snapshots", None) != None
        ],
    ).to_list()

    # Non-Kotlin Java dependencies don't publish classpath snapshots via KtJvmInfo.
    # Return their compile jars so snapshot actions can be generated locally by compile.bzl.
    non_kotlin_classpath_snapshot_jars = depset(
        transitive = [
            _java_info_snapshot_jars(d)
            for d in snapshot_sources
            if JavaInfo in d and KtJvmInfo not in d
        ] + [
            getattr(d[KtJvmInfo], "transitive_non_kotlin_classpath_snapshot_jars", depset())
            for d in snapshot_sources
            if KtJvmInfo in d and getattr(d[KtJvmInfo], "transitive_non_kotlin_classpath_snapshot_jars", None) != None
        ],
    ).to_list()

    return struct(
        module_name = associates.module_name,
        deps = dep_infos,
        pruned_deps_for_java = pruned_deps_for_java,
        exports = [_java_info(d) for d in exports],
        associate_jars = associates.jars,
        compile_jars = depset(direct = compile_depset_list_filtered),
        runtime_deps = [_java_info(d) for d in runtime_deps],
        classpath_snapshots = classpath_snapshots,
        non_kotlin_classpath_snapshot_jars = non_kotlin_classpath_snapshot_jars,
    )

jvm_deps_utils = struct(
    jvm_deps = _jvm_deps,
)
