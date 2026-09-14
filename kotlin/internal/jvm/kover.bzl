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

"""Kover helpers adapted from rules_kotlin PR #1729.

This draft preserves that proposal's raw report and CLI metadata layout.
Bazel test-output harvesting and mixed Java/Kotlin instrumentation remain
separate integration work; a generated build artifact is not a test output.
"""

load(
    "@bazel_skylib//lib:paths.bzl",
    _paths = "paths",
)
load("@rules_java//java:defs.bzl", "JavaInfo")
load(
    "//kotlin/internal:defs.bzl",
    _TOOLCHAIN_TYPE = "TOOLCHAIN_TYPE",
)

def is_kover_enabled(ctx):
    return ctx.toolchains[_TOOLCHAIN_TYPE].experimental_kover_enabled

def get_kover_agent_file(ctx):
    """Get the Kover agent runtime file from the toolchain.

    Args:
        ctx: The rule context.

    Returns:
        The Kover agent runtime file.
    """
    kover_agent = ctx.toolchains[_TOOLCHAIN_TYPE].experimental_kover_agent
    if not kover_agent:
        fail("Kover agent wasn't specified in toolchain.")

    return kover_agent

def get_kover_jvm_flags(kover_agent_file, kover_args_file):
    """Compute the jvm flags used to setup Kover agent.

    Args:
        kover_agent_file: The Kover agent file.
        kover_args_file: The Kover arguments file.

    Returns:
        The flags to be passed separately to the test runner JVM.
    """
    jvm_args = [
        "-Xbootclasspath/a:%s" % (kover_agent_file.short_path),
        "-javaagent:%s=file:%s" % (kover_agent_file.short_path, kover_args_file.short_path),
    ]
    return jvm_args

def _source_to_kover_arg(src):
    return "--src\n%s" % _paths.dirname(src.short_path)

def _classfile_to_kover_arg(classfile):
    return "--classfiles\n%s" % classfile.short_path

def _exclude_to_kover_arg(exclude):
    return "--exclude\n%s" % exclude

def _exclude_annotation_to_kover_arg(exclude_annotation):
    return "--excludeAnnotation\n%s" % exclude_annotation

def _exclude_inherited_from_to_kover_arg(exclude_inherited_from):
    return "--excludeInheritedFrom\n%s" % exclude_inherited_from

def create_kover_agent_actions(ctx, name):
    """Generate the actions needed to emit Kover code coverage metadata file.

    Creates the properly populated arguments input file needed by Kover agent.

    Args:
        ctx: The rule context.
        name: The name of the target.

    Returns:
        A tuple of (kover_output_file, kover_args_file).
    """

    # declare code coverage raw data binary output file
    binary_output_name = "%s-kover_report.ic" % name
    kover_output_file = ctx.actions.declare_file(binary_output_name)

    # Declare an initial output without relying on a shell command so this also
    # works on Windows. The Kover agent replaces it when the test runs.
    ctx.actions.write(kover_output_file, "")

    # declare args file - https://kotlin.github.io/kotlinx-kover/jvm-agent/#kover-jvm-arguments-file
    kover_args_file = ctx.actions.declare_file(
        "%s-kover.args.txt" % name,
    )
    ctx.actions.write(
        kover_args_file,
        "report.file=%s" % kover_output_file.short_path,
    )

    return kover_output_file, kover_args_file

def create_kover_metadata_action(
        ctx,
        name,
        deps,
        kover_output_file):
    """Generate kover metadata file needed for invoking kover CLI to generate report.

    More info at: https://kotlin.github.io/kotlinx-kover/cli/

    Args:
        ctx: The rule context.
        name: The name of the target.
        deps: The dependencies to collect coverage for.
        kover_output_file: The Kover output file.

    Returns:
        The kover output metadata file.
    """
    metadata_output_name = "%s-kover_metadata.txt" % name
    kover_output_metadata_file = ctx.actions.declare_file(metadata_output_name)

    instrumented_files = depset(transitive = [
        dep[InstrumentedFilesInfo].instrumented_files
        for dep in deps
        if InstrumentedFilesInfo in dep
    ])
    runtime_jars = depset(transitive = [
        dep[JavaInfo].transitive_runtime_jars
        for dep in deps
        if JavaInfo in dep
    ])

    args = ctx.actions.args()
    args.add("report")
    args.add(kover_output_file.short_path)
    args.add("--title")
    args.add("Code-Coverage Analysis: %s" % ctx.label)
    args.add_joined(
        instrumented_files,
        join_with = "\n",
        map_each = _source_to_kover_arg,
        uniquify = True,
    )
    args.add_joined(
        runtime_jars,
        join_with = "\n",
        map_each = _classfile_to_kover_arg,
        uniquify = True,
    )
    args.add_joined(
        ctx.toolchains[_TOOLCHAIN_TYPE].experimental_kover_exclude,
        join_with = "\n",
        map_each = _exclude_to_kover_arg,
    )
    args.add_joined(
        ctx.toolchains[_TOOLCHAIN_TYPE].experimental_kover_exclude_annotation,
        join_with = "\n",
        map_each = _exclude_annotation_to_kover_arg,
    )
    args.add_joined(
        ctx.toolchains[_TOOLCHAIN_TYPE].experimental_kover_exclude_inherited_from,
        join_with = "\n",
        map_each = _exclude_inherited_from_to_kover_arg,
    )

    ctx.actions.write(kover_output_metadata_file, args)

    return kover_output_metadata_file
