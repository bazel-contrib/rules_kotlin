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

# This file contains logic to integrate with Kover for code coverage, using
# Kover JVM agent and disabling JaCoCo instrumentation, which avoid having to
# re-compile application code. It used from both JVM and Android kotlin tests.
#
#
# How to use?
#
# Supply the version of Kover agent via toolchain (typically from jvm_rules_extrenal),
# and enable Kover. The agent writes its report in the test's runfiles workspace.
#
#
# Notes :
#
# 1. Run the report CLI from the test's runfiles workspace, where both its arguments and
#    the agent's raw report resolve. See examples/kover for a --run_under wrapper that
#    saves the result before the test sandbox is removed.
#
# 2. For mixed sourceset, disabling JaCoCo instrumenation is required. To do this properly,
#    one should add an extra parameter to java_common.compile() API, which require modifying both
#    rules_java and Bazel core. For now, we disabled JaCoCo instrumentation accross the board,
#    you will need to cherry-pick this PR https://github.com/uber-common/bazel/commit/cb9f6f042c64af96bbd77e21fe6fb75936c74f47
#

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

def _source_dir(src):
    return _paths.dirname(src.short_path) or "."

def _runfiles_path(file):
    return file.short_path

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

    # The agent writes this relative name in the test sandbox during execution.
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
        A depset containing the CLI argument file and the sources and JARs it names.
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

    # The CLI reads one literal argument per line, relative to the test's runfiles workspace.
    args = ctx.actions.args()
    args.set_param_file_format("multiline")
    args.add("report")
    args.add(kover_output_file.short_path)
    args.add("--title")
    args.add("Code-Coverage Analysis: %s" % ctx.label)
    args.add_all(
        instrumented_files,
        before_each = "--src",
        map_each = _source_dir,
        uniquify = True,
    )
    args.add_all(
        runtime_jars,
        before_each = "--classfiles",
        map_each = _runfiles_path,
        uniquify = True,
    )
    args.add_all(
        ctx.toolchains[_TOOLCHAIN_TYPE].experimental_kover_exclude,
        before_each = "--exclude",
    )
    args.add_all(
        ctx.toolchains[_TOOLCHAIN_TYPE].experimental_kover_exclude_annotation,
        before_each = "--excludeAnnotation",
    )
    args.add_all(
        ctx.toolchains[_TOOLCHAIN_TYPE].experimental_kover_exclude_inherited_from,
        before_each = "--excludeInheritedFrom",
    )

    ctx.actions.write(kover_output_metadata_file, args)

    return depset([kover_output_metadata_file], transitive = [instrumented_files, runtime_jars])

def create_kover_runtime(ctx):
    """Creates the agent flags and files used by Kotlin test launchers.

    Args:
        ctx: The test rule context.

    Returns:
        The agent jar, JVM flags, and runfiles needed to generate a report.
    """
    agent = get_kover_agent_file(ctx)
    report, args = create_kover_agent_actions(ctx, ctx.label.name)
    report_runfiles = create_kover_metadata_action(ctx, ctx.label.name, ctx.attr.deps + ctx.attr.associates, report)
    return struct(
        agent = agent,
        report_runfiles = depset([args], transitive = [report_runfiles]),
        jvm_flags = get_kover_jvm_flags(agent, args),
    )
