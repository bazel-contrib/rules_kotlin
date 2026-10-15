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
"""Shared helpers for the Kotlin/JVM processing pipelines."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load(
    "//kotlin/internal:defs.bzl",
    _TOOLCHAIN_TYPE = "TOOLCHAIN_TYPE",
)
load(
    "//src/main/starlark/core/compile:common.bzl",
    "find_launcher_maker",
    "get_executable",
    "get_launcher_maker_toolchain_for_action",
    "is_windows",
)

def _artifact_short_path(artifact):
    return artifact.short_path

def make_providers(ctx, providers, runfiles_targets, transitive_files = depset(order = "default"), executable = None, *additional_providers):
    files = [ctx.outputs.jar]
    if providers.java.outputs.jdeps:
        files.append(providers.java.outputs.jdeps)

    return [
        providers.java,
        providers.kt,
        providers.instrumented_files,
        DefaultInfo(
            files = depset(files),
            runfiles = ctx.runfiles(
                files = ctx.files.data,
                transitive_files = transitive_files,
            ).merge_all([
                d[DefaultInfo].default_runfiles
                for d in runfiles_targets
                if DefaultInfo in d and d[DefaultInfo].default_runfiles
            ]),
            executable = executable,
        ),
    ] + list(additional_providers)

def expand_env(ctx):
    return {
        key: ctx.expand_make_variables(
            "env",
            ctx.expand_location(value, ctx.attr.data),
            {},
        )
        for key, value in ctx.attr.env.items()
    }

def _is_absolute_target_platform_path(ctx, path):
    """Check if path is absolute, accounting for Windows drive letters."""
    if is_windows(ctx):
        return len(path) > 2 and path[1] == ":"
    return path.startswith("/")

def _create_windows_exe_launcher(ctx, executable, java_executable, classpath, main_class, jvm_flags_for_launcher, runfiles_enabled, coverage_main_class = None):
    """Create a Windows exe launcher using the launcher_maker tool."""
    java_runtime = ctx.toolchains["@bazel_tools//tools/jdk:runtime_toolchain_type"].java_runtime

    # Tokenize JVM flags for Windows launcher (handles quoted arguments properly)
    tokenized_jvm_flags = []
    for flag in jvm_flags_for_launcher:
        tokenized_jvm_flags.extend(ctx.tokenize(flag))

    launch_info = ctx.actions.args().use_param_file("%s", use_always = True).set_param_file_format("multiline")
    launch_info.add("binary_type=Java")
    launch_info.add(ctx.workspace_name, format = "workspace_name=%s")
    launch_info.add("1" if runfiles_enabled else "0", format = "symlink_runfiles_enabled=%s")
    launch_info.add(java_executable, format = "java_bin_path=%s")
    launch_info.add(main_class, format = "java_start_class=%s")
    if coverage_main_class:
        launch_info.add(coverage_main_class, format = "jacoco_main_class=%s")
    launch_info.add_joined(
        classpath,
        map_each = _artifact_short_path,
        join_with = ";",
        format_joined = "classpath=%s",
        omit_if_empty = False,
    )
    launch_info.add_joined(tokenized_jvm_flags, join_with = "\t", format_joined = "jvm_flags=%s", omit_if_empty = False)

    # Use java_home_runfiles_path directly (same as rules_java)
    launch_info.add(java_runtime.java_home_runfiles_path, format = "jar_bin_path=%s/bin/jar.exe")

    launcher_artifact = ctx.executable._launcher
    ctx.actions.run(
        executable = find_launcher_maker(ctx),
        inputs = [launcher_artifact],
        outputs = [executable],
        arguments = [launcher_artifact.path, launch_info, executable.path],
        use_default_shell_env = True,
        toolchain = get_launcher_maker_toolchain_for_action(),
        mnemonic = "JavaLauncherMaker",
    )

def write_launcher_action(ctx, rjars, main_class, jvm_flags, is_test = False):
    """Writes out a launcher shell script for a java target.

    Args:
      ctx: the rule context used to declare the launcher file and read toolchains.
      rjars: All of the runtime jars required to launch this java target.
      main_class: the main class to launch.
      jvm_flags: The flags that should be passed to the jvm.
      is_test: Whether this is a test target (enables security manager for test runner).

    Returns:
      A struct with:
        - coverage_metadata: List of coverage metadata files (may be empty)
        - executable: The declared executable file (only set on Windows, None otherwise)
    """
    java_runtime = ctx.toolchains["@bazel_tools//tools/jdk:runtime_toolchain_type"].java_runtime
    java_bin_path = java_runtime.java_executable_runfiles_path

    # Normalize java_bin_path (same logic as rules_java's _get_java_executable)
    if not _is_absolute_target_platform_path(ctx, java_bin_path):
        java_bin_path = ctx.workspace_name + "/" + java_bin_path
    java_bin_path = paths.normalize(java_bin_path)

    # Following rules_java: enable security manager for tests on Java 17-23
    # See https://github.com/bazelbuild/rules_java/blob/7ff9193af58807c9b77f3b7cd56063c9b8a9f028/java/bazel/rules/bazel_java_binary.bzl#L78-L81
    _java_runtime_version = getattr(java_runtime, "version", 0)
    jvm_flags_list = [ctx.expand_location(f, ctx.attr.data) for f in jvm_flags]
    if is_test and _java_runtime_version >= 17 and _java_runtime_version < 24:
        jvm_flags_list.append("-Djava.security.manager=allow")

    # Windows: use native exe launcher with explicitly declared executable
    if is_windows(ctx):
        # Explicitly declare the executable with .exe extension (required for Windows)
        executable = get_executable(ctx)

        # On Windows, symlink runfiles are typically disabled (manifest-based runfiles are used instead).
        # ctx.configuration.runfiles_enabled() is internal to rules_java and not available here.
        runfiles_enabled = True
        coverage_enabled = ctx.configuration.coverage_enabled
        if coverage_enabled:
            jacocorunner = ctx.toolchains[_TOOLCHAIN_TYPE].jacocorunner
            classpath = rjars.to_list() + jacocorunner.files.to_list()
            jacoco_metadata_file = ctx.actions.declare_file(
                "%s.jacoco_metadata.txt" % ctx.attr.name,
                sibling = executable,
            )
            ctx.actions.write(jacoco_metadata_file, "\n".join([
                jar.short_path.replace("../", "external/")
                for jar in rjars.to_list()
            ]))
            jvm_flags_list.extend([
                "-ea",
                "-Dbazel.test_suite=" + main_class,
            ])
            _create_windows_exe_launcher(
                ctx,
                executable = executable,
                java_executable = java_bin_path,
                classpath = classpath,
                main_class = "com.google.testing.coverage.JacocoCoverageRunner",
                jvm_flags_for_launcher = jvm_flags_list,
                runfiles_enabled = runfiles_enabled,
                coverage_main_class = main_class,
            )
            return struct(coverage_metadata = [jacoco_metadata_file], executable = executable)

        _create_windows_exe_launcher(
            ctx,
            executable = executable,
            java_executable = java_bin_path,
            classpath = rjars.to_list(),
            main_class = main_class,
            jvm_flags_for_launcher = jvm_flags_list,
            runfiles_enabled = runfiles_enabled,
        )
        return struct(coverage_metadata = [], executable = executable)

    # Unix: use shell script template
    jvm_flags_str = " ".join(jvm_flags_list)
    template = ctx.attr.java_stub_template.files.to_list()[0]

    # Construct JAVABIN substitution with ${JAVA_RUNFILES}/ prefix for relative paths
    # This works in both runfiles-enabled and manifest-only modes
    prefix = "" if _is_absolute_target_platform_path(ctx, java_bin_path) else "${JAVA_RUNFILES}/"
    java_bin = "JAVABIN=${JAVABIN:-" + prefix + java_bin_path + "}"

    if ctx.configuration.coverage_enabled:
        jacocorunner = ctx.toolchains[_TOOLCHAIN_TYPE].jacocorunner
        classpath = ctx.configuration.host_path_separator.join(
            ["${RUNPATH}%s" % (j.short_path) for j in rjars.to_list() + jacocorunner.files.to_list()],
        )
        jacoco_metadata_file = ctx.actions.declare_file(
            "%s.jacoco_metadata.txt" % ctx.attr.name,
            sibling = ctx.outputs.executable,
        )
        ctx.actions.write(jacoco_metadata_file, "\n".join([
            jar.short_path.replace("../", "external/")
            for jar in rjars.to_list()
        ]))
        ctx.actions.expand_template(
            template = template,
            output = ctx.outputs.executable,
            substitutions = {
                "%classpath%": classpath,
                "%java_start_class%": "com.google.testing.coverage.JacocoCoverageRunner",
                "%javabin%": java_bin,
                "%jvm_flags%": jvm_flags_str,
                "%needs_runfiles%": "0" if _is_absolute_target_platform_path(ctx, java_runtime.java_executable_exec_path) else "1",
                "%runfiles_manifest_only%": "",
                "%set_jacoco_java_runfiles_root%": """export JACOCO_JAVA_RUNFILES_ROOT=$JAVA_RUNFILES/{}/""".format(ctx.workspace_name),
                "%set_jacoco_main_class%": """export JACOCO_MAIN_CLASS={}""".format(main_class),
                "%set_jacoco_metadata%": "export JACOCO_METADATA_JAR=\"$JAVA_RUNFILES/{}/{}\"".format(ctx.workspace_name, jacoco_metadata_file.short_path),
                "%set_java_coverage_new_implementation%": """export JAVA_COVERAGE_NEW_IMPLEMENTATION=YES""",
                "%test_runtime_classpath_file%": "export TEST_RUNTIME_CLASSPATH_FILE=${JAVA_RUNFILES}",
                "%workspace_prefix%": ctx.workspace_name + "/",
            },
            is_executable = True,
        )
        return struct(coverage_metadata = [jacoco_metadata_file], executable = None)

    classpath = ctx.configuration.host_path_separator.join(
        ["${RUNPATH}%s" % (j.short_path) for j in rjars.to_list()],
    )

    ctx.actions.expand_template(
        template = template,
        output = ctx.outputs.executable,
        substitutions = {
            "%classpath%": classpath,
            "%java_start_class%": main_class,
            "%javabin%": java_bin,
            "%jvm_flags%": jvm_flags_str,
            "%needs_runfiles%": "0" if _is_absolute_target_platform_path(ctx, java_runtime.java_executable_exec_path) else "1",
            "%runfiles_manifest_only%": "",
            "%set_jacoco_java_runfiles_root%": "",
            "%set_jacoco_main_class%": "",
            "%set_jacoco_metadata%": "",
            "%set_java_coverage_new_implementation%": """export JAVA_COVERAGE_NEW_IMPLEMENTATION=NO""",
            "%test_runtime_classpath_file%": "export TEST_RUNTIME_CLASSPATH_FILE=${JAVA_RUNFILES}",
            "%workspace_prefix%": ctx.workspace_name + "/",
        },
        is_executable = True,
    )
    return struct(coverage_metadata = [], executable = None)

_SPLIT_STRINGS = [
    "src/test/java/",
    "src/test/kotlin/",
    "javatests/",
    "kotlin/",
    "java/",
    "test/",
]

def infer_test_class(ctx):
    """Return the explicit test_class, else best-effort infer one from the srcs.

    Args:
      ctx: the rule context, read for attr.test_class, attr.name, files.srcs and label.

    Returns:
      The test class name as a string, or the empty string if none could be inferred.
    """
    test_class = ctx.attr.test_class
    if not bool(ctx.attr.test_class):
        for file in ctx.files.srcs:
            package_relative_path = file.path.replace(ctx.label.package + "/", "")
            if package_relative_path.split(".")[0] == ctx.attr.name:
                for splitter in _SPLIT_STRINGS:
                    elements = file.short_path.split(splitter, 1)
                    if len(elements) == 2:
                        test_class = elements[1].split(".")[0].replace("/", ".")
                        break
    return test_class
