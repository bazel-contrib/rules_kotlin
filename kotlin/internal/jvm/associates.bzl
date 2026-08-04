# Copyright 2020 The Bazel Authors. All rights reserved.
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
"""Utilities for collecting associates dependencies."""

load(
    "@bazel_skylib//lib:sets.bzl",
    _sets = "sets",
)
load("@rules_java//java:defs.bzl", "JavaInfo")
load(
    "//kotlin/internal:defs.bzl",
    _KtJvmInfo = "KtJvmInfo",
)
load(
    "//kotlin/internal/utils:utils.bzl",
    _utils = "utils",
)

def _collect_associates(ctx, toolchains, associate):
    """Collects the associate jars from a dependency and returns them as a depset.

    There are three outcomes for this marco:
    1. When `experimental_treat_internal_as_private_in_abi_jars` is effective (together with
        `experimental_remove_private_classes_in_abi_jars`, which it requires) and the tag overrides have not been
        provided, only the direct java_output CLASS jars will be collected for each associate target. Internal symbols
        are stripped from the compile jars in that configuration, so the class jar is the only one that contains the
        internal symbols an associate has access to. With `experimental_remove_private_classes_in_abi_jars` alone,
        internal symbols remain available in abi jars, so it is still possible to collect COMPILE jars
    2. When `experimental_strict_associate_dependencies` is enabled and the tag override has not been provided, only the
        direct java_output COMPILE jars will be collected for each associate target.
    3. When `experimental_strict_associate_dependencies` is disabled, the complete transitive set of compile jars will
        be collected for each assoicate target.

    Args:
        ctx: the rule context used to read tags and toolchain configuration.
        toolchains: the resolved toolchains providing the Kotlin experimental flags.
        associate: the associate target whose JavaInfo jars are collected.

    Returns:
        A struct with `jars` (a depset of compile/class jars) and `abi_jars_set` (a set of ABI jars).
    """
    internals_stripped_from_abi_jars = (
        toolchains.kt.experimental_treat_internal_as_private_in_abi_jars and
        "kt_treat_internal_as_private_in_abi_plugin_incompatible" not in ctx.attr.tags and
        toolchains.kt.experimental_remove_private_classes_in_abi_jars and
        "kt_remove_private_classes_in_abi_plugin_incompatible" not in ctx.attr.tags
    )
    jars_depset = None
    abi_jars_set = _sets.make()
    if internals_stripped_from_abi_jars:
        jars_depset = depset(direct = [a.class_jar for a in associate[JavaInfo].java_outputs])
        abi_jars_set = _sets.union(abi_jars_set, _sets.make([a.compile_jar for a in associate[JavaInfo].java_outputs]))
    elif (toolchains.kt.experimental_strict_associate_dependencies and
          "kt_experimental_strict_associate_dependencies_incompatible" not in ctx.attr.tags):
        jars_depset = depset(direct = [a.compile_jar for a in associate[JavaInfo].java_outputs])
    else:
        jars_depset = depset(transitive = [associate[JavaInfo].compile_jars])
    return struct(
        jars = jars_depset,
        abi_jars_set = abi_jars_set,
    )

def _java_info(target):
    return target[JavaInfo] if JavaInfo in target else None

def _get_associates(ctx, toolchains, associates):
    """Creates a struct of associates meta data"""
    if not associates:
        return struct(
            module_name = _utils.derive_module_name(ctx),
            jars = depset(),
            abi_jar_set = _sets.make(),
            dep_infos = [],
        )
    elif ctx.attr.module_name:
        fail("If associates have been set then module_name cannot be provided")
    else:
        jars = []
        abi_jar_set = _sets.make()
        module_names = []
        java_infos = []
        for a in associates:
            jar_bundle = _collect_associates(ctx = ctx, toolchains = toolchains, associate = a)
            jars.append(jar_bundle.jars)
            abi_jar_set = _sets.union(abi_jar_set, jar_bundle.abi_jars_set)
            module_names.append(a[_KtJvmInfo].module_name)
            java_infos.append(_java_info(a))
        module_names = _sets.to_list(_sets.make(module_names))

        if len(module_names) > 1:
            fail("Dependencies from several different kotlin modules cannot be associated. " +
                 "Associates can see each other's \"internal\" members, and so must only be " +
                 "used with other targets in the same module: \n%s" % module_names)
        if len(module_names) < 1:
            # This should be impossible
            fail("Error in rules - a KtJvmInfo was found which did not have a module_name")
        return struct(
            jars = depset(transitive = jars),
            abi_jar_set = abi_jar_set,
            module_name = module_names[0],
            dep_infos = java_infos,
        )

associate_utils = struct(
    get_associates = _get_associates,
)
