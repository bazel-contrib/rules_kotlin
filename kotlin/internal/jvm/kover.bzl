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
# and enable Kover. For Unix JVM tests, also supply a matching CLI JAR to produce LCOV.
#
#
# Notes :
#
# 1. With the CLI configured, the test wrapper converts the raw report to LCOV before
#    Bazel collects coverage fragments. Agent-only toolchains retain their raw-report setup.
#
# 2. For mixed sourceset, disabling JaCoCo instrumenation is required. To do this properly,
#    one should add an extra parameter to java_common.compile() API, which require modifying both
#    rules_java and Bazel core. For now, we disabled JaCoCo instrumentation accross the board,
#    you will need to cherry-pick this PR https://github.com/uber-common/bazel/commit/cb9f6f042c64af96bbd77e21fe6fb75936c74f47
#
# 3. Code in `kt_android_local_test_impl.bzl` needs to be kept in sync with rules_android. There is ongoing
#    conversation with google to simply of to extend rules_android, and override pipeline's behavior without
#    duplicating their code, we should be able to simplify this soon.
#

load(
    "@bazel_skylib//lib:paths.bzl",
    _paths = "paths",
)
load("@bazel_skylib//lib:shell.bzl", "shell")
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

def create_kover_agent_files(ctx, deps):
    """Write the agent settings and CLI metadata for an agent-only toolchain.

    Args:
        ctx: The test rule context.
        deps: The targets whose sources and runtime JARs the CLI needs.

    Returns:
        The agent settings file and a depset of the required runfiles.
    """
    name = ctx.label.name
    args_file = ctx.actions.declare_file(name + "-kover.args.txt")

    # The JVM creates the report at test time, beside the settings file in runfiles.
    report_path = args_file.short_path.removesuffix("-kover.args.txt") + "-kover_report.ic"
    ctx.actions.write(args_file, "report.file=" + report_path)

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

    metadata = _write_metadata(ctx, name, instrumented_files, runtime_jars, report_path)
    return args_file, depset([args_file, metadata], transitive = [instrumented_files, runtime_jars])

def _write_metadata(ctx, name, instrumented_files, runtime_jars, report_path = None):
    metadata = ctx.actions.declare_file("%s-kover_metadata.txt" % name)

    # The CLI reads one literal argument per line, relative to the test's runfiles workspace.
    args = ctx.actions.args()
    args.set_param_file_format("multiline")
    args.add("report")
    if report_path:
        args.add(report_path)
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

    ctx.actions.write(metadata, args)
    return metadata

def _source_paths(src):
    # The merger matches exec paths; the reporter reads sources from runfiles.
    return [src.path, src.short_path]

def create_kover_lcov_launcher(ctx, providers):
    """Write the Unix test wrapper that reports Kover line coverage to Bazel."""
    toolchain = ctx.toolchains[_TOOLCHAIN_TYPE]
    agent = get_kover_agent_file(ctx)
    sources = providers.instrumented_files.instrumented_files
    jars = providers.java.transitive_runtime_jars
    metadata = _write_metadata(ctx, ctx.label.name, sources, jars)
    source_map = ctx.actions.declare_file(ctx.label.name + "-kover_sources.txt")
    args = ctx.actions.args()
    args.set_param_file_format("multiline")
    args.add_all(sources, map_each = _source_paths)
    ctx.actions.write(source_map, args)

    child = ctx.actions.declare_file(ctx.label.name + ".kover-jvm")
    java = ctx.toolchains["@bazel_tools//tools/jdk:runtime_toolchain_type"].java_runtime
    ctx.actions.expand_template(
        template = ctx.file._kover_lcov_template,
        output = ctx.outputs.executable,
        substitutions = {
            "%agent%": shell.quote(agent.short_path),
            "%child%": shell.quote(child.basename),
            "%cli%": shell.quote(toolchain.experimental_kover_cli.short_path),
            "%java%": shell.quote(java.java_executable_runfiles_path),
            "%metadata%": shell.quote("@" + metadata.short_path),
            "%sources%": shell.quote(source_map.short_path),
            "%writer%": shell.quote(toolchain.kover_lcov_writer.short_path),
        },
        is_executable = True,
    )
    return child, depset(
        [child, agent, metadata, source_map, toolchain.experimental_kover_cli, toolchain.kover_lcov_writer],
        transitive = [sources, jars],
    )
