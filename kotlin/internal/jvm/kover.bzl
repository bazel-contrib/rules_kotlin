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
# and enable Kover. Then run `bazel coverage //your/kotlin/test_target`. Output files
# are created in working module directory (along test/library explicity outputs).
#
#
# Notes :
#
# 1. Because Bazel test/coverage are 'terminal' and actions or aspects can't reuse the output
#    of these, the generation of the report is done outside bazel (typically
#    from Bazel wrapper). The logic here will generate both raw output (*.ic file) and
#    a metadata file ready to provide to Kover CLI, so that one can generate report simply by
#    running : `java -jar kover-cli.jar report @path_to_metadat_file <options>`
#
#    We could possibly generate the report by hijacking test runner shell script template
#    and injecting this command to executed after tests are run. This is rather hacky
#    and is likely to require changes to Bazel project.
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
load("@rules_java//java:defs.bzl", "JavaInfo")
load(
    "//kotlin/internal:defs.bzl",
    _TOOLCHAIN_TYPE = "TOOLCHAIN_TYPE",
)

def is_kover_enabled(ctx):
    return ctx.toolchains[_TOOLCHAIN_TYPE].experimental_kover_enabled

def get_kover_agent_file(ctx):
    """Get the Kover agent runtime files, extracted from toolchain.

    Args:
        ctx: The rule context.

    Returns:
        The Kover agent runtime files as a list.
    """
    kover_agent = ctx.toolchains[_TOOLCHAIN_TYPE].experimental_kover_agent
    if not kover_agent:
        fail("Kover agent wasn't specified in toolchain.")

    kover_agent_info = kover_agent[DefaultInfo]
    return kover_agent_info.files.to_list()

def get_kover_jvm_flags(kover_agent_files, kover_args_file):
    """Compute the jvm flags used to setup Kover agent.

    Args:
        kover_agent_files: List of Kover agent files.
        kover_args_file: The Kover arguments file.

    Returns:
        The flag string to be used by test runner JVM.
    """
    jvm_args = [
        "-Xbootclasspath/a:%s" % (kover_agent_files[0].short_path),
        "-javaagent:%s=file:%s" % (kover_agent_files[0].short_path, kover_args_file.short_path),
    ]
    return " ".join(jvm_args)

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

    # Hack: there is curently no way to indicate this file will be created Kover agent
    ctx.actions.run_shell(
        outputs = [kover_output_file],
        command = "touch {}".format(kover_output_file.path),
    )

    # declare args file - https://kotlin.github.io/kotlinx-kover/jvm-agent/#kover-jvm-arguments-file
    kover_args_file = ctx.actions.declare_file(
        "%s-kover.args.txt" % name,
    )
    ctx.actions.write(
        kover_args_file,
        "report.file=../../%s" % binary_output_name,  # Kotlin compiler runs in runfiles folder, make sure file is created is correct location
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

    srcs = []
    classfiles = []
    excludes = []

    for dep in deps:
        if dep.label.package != ctx.label.package:
            continue

        if InstrumentedFilesInfo in dep:
            for src in dep[InstrumentedFilesInfo].instrumented_files.to_list():
                if src.short_path.startswith(ctx.label.package + "/"):
                    path = _paths.dirname(src.short_path)
                    if path not in srcs:
                        srcs.extend(["--src", path])

        if JavaInfo in dep:
            for classfile in dep[JavaInfo].transitive_runtime_jars.to_list():
                if classfile.short_path.startswith(ctx.label.package + "/"):
                    if classfile.path not in classfiles:
                        classfiles.extend(["--classfiles", classfile.path])

    for exclude in ctx.toolchains[_TOOLCHAIN_TYPE].experimental_kover_exclude:
        excludes.extend(["--exclude", exclude])

    for exclude_annotation in ctx.toolchains[_TOOLCHAIN_TYPE].experimental_kover_exclude_annotation:
        excludes.extend(["--excludeAnnotation", exclude_annotation])

    for exclude_inherited_from in ctx.toolchains[_TOOLCHAIN_TYPE].experimental_kover_exclude_inherited_from:
        excludes.extend(["--excludeInheritedFrom", exclude_inherited_from])

    ctx.actions.write(kover_output_metadata_file, "\n".join([
        "report",
        kover_output_file.path,
        "--title",
        "Code-Coverage Analysis: %s" % ctx.label,
    ] + srcs + classfiles + excludes))

    return kover_output_metadata_file
