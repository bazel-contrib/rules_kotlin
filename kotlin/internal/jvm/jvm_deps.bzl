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

def _java_info(target):
    return target[JavaInfo] if JavaInfo in target else None

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

    # Reduced classpath, exclude transitive deps from compilation
    if (toolchains.kt.experimental_prune_transitive_deps and
        not "kt_experimental_prune_transitive_deps_incompatible" in ctx.attr.tags):
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

    compile_depset_list = depset(transitive = transitive + [associates.jars]).to_list()
    compile_depset_list_filtered = [jar for jar in compile_depset_list if not _sets.contains(associates.abi_jar_set, jar)]

    return struct(
        module_name = associates.module_name,
        deps = dep_infos,
        exports = [_java_info(d) for d in exports],
        associate_jars = associates.jars,
        compile_jars = depset(direct = compile_depset_list_filtered),
        runtime_deps = [_java_info(d) for d in runtime_deps],
    )

jvm_deps_utils = struct(
    jvm_deps = _jvm_deps,
)
