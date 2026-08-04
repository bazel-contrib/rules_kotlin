"""CLI-toolchain Kotlin/JVM compilation utilities."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load(
    "//src/main/starlark/core/compile:common.bzl",
    "TYPE",
    "find_launcher_maker",
    "get_launcher_maker_toolchain_for_action",
)

def _artifact_short_path(artifact):
    return artifact.short_path

def compile_kotlin_for_jvm(
        actions,
        srcs,
        dep_jars,
        class_jar,
        module_name,
        path_separator,
        toolchain_info,
        kotlinc_opts,
        output_srcjar = None):
    """Compiles Kotlin sources for the JVM into a class jar and optional source jar.

    Args:
        actions: the rule actions object used to declare and run compile actions.
        srcs: the Kotlin sources to compile.
        dep_jars: a depset of dependency jars on the compile classpath.
        class_jar: the declared output class jar.
        module_name: the Kotlin module name for the compilation.
        path_separator: the platform classpath separator.
        toolchain_info: the resolved Kotlin toolchain info.
        kotlinc_opts: the kotlinc options applied to the compilation.
        output_srcjar: the optional declared output source jar.
    """
    if not srcs:
        # still gotta create the jars for keep bazel haps.
        actions.symlink(
            output = output_srcjar,
            target_file = toolchain_info.empty_jar,
        )
        actions.symlink(
            output = class_jar,
            target_file = toolchain_info.empty_jar,
        )
        return

    classpath = depset(
        transitive = [
            dep_jars,
            toolchain_info.kotlin_stdlib.transitive_compile_time_jars,
        ],
    )

    args = actions.args()
    args.add("-d", class_jar)
    args.add("-jdk-home", toolchain_info.java_runtime.java_home)
    args.add("-jvm-target", toolchain_info.jvm_target)
    args.add("-no-stdlib")
    args.add("-api-version", toolchain_info.api_version)
    args.add("-language-version", toolchain_info.language_version)
    args.add("-module-name", module_name)
    args.add_joined("-cp", classpath, join_with = path_separator)
    args.add_all(kotlinc_opts)
    args.add_all(srcs)

    actions.run(
        outputs = [class_jar],
        executable = toolchain_info.kotlinc,
        inputs = depset(direct = srcs, transitive = [classpath, toolchain_info.java_runtime.files]),
        arguments = [args],
        mnemonic = toolchain_info.compile_mnemonic,
        toolchain = TYPE,
    )

    if output_srcjar:
        actions.run(
            outputs = [output_srcjar],
            executable = toolchain_info.executable_zip,
            inputs = srcs,
            arguments = [actions.args().add("c").add(output_srcjar).add_all(srcs)],
            mnemonic = "SourceJar",
            toolchain = TYPE,
        )

def write_jvm_launcher(toolchain_info, actions, path_separator, workspace_prefix, jvm_flags, runtime_jars, main_class, executable_output):
    """Writes a JVM launcher shell script for a core_kt_jvm_binary.

    Args:
        toolchain_info: the resolved Kotlin toolchain info.
        actions: the rule actions object used to expand the launcher template.
        path_separator: the platform classpath separator.
        workspace_prefix: the runfiles workspace prefix used in the classpath.
        jvm_flags: the JVM flags passed to the launched binary.
        runtime_jars: the runtime jars placed on the launcher classpath.
        main_class: the fully qualified main class to launch.
        executable_output: the declared launcher script output file.

    Returns:
        A depset of files needed for runfiles (runtime jars, java runtime, kotlin stdlib).
    """
    template = toolchain_info.java_stub_template
    java_runtime = toolchain_info.java_runtime
    java_bin_path = java_runtime.java_executable_runfiles_path

    # Following https://github.com/bazelbuild/bazel/blob/6d5b084025a26f2f6d5041f7a9e8d302c590bc80/src/main/starlark/builtins_bzl/bazel/java/bazel_java_binary.bzl#L66-L67
    # Enable the security manager past deprecation until permanently disabled: https://openjdk.org/jeps/486
    # On bazel 6, this check isn't possible...
    _java_runtime_version = getattr(java_runtime, "version", 0)
    if _java_runtime_version >= 17 and _java_runtime_version < 24:
        jvm_flags = jvm_flags + " -Djava.security.manager=allow"

    classpath = path_separator.join(
        ["${RUNPATH}%s" % (j.short_path) for j in runtime_jars.to_list() + toolchain_info.kotlin_stdlib.transitive_compile_time_jars.to_list()],
    )
    needs_runfiles = "0" if java_bin_path.startswith("/") or (len(java_bin_path) > 2 and java_bin_path[1] == ":") else "1"

    actions.expand_template(
        template = template,
        output = executable_output,
        substitutions = {
            "%classpath%": classpath,
            "%java_start_class%": main_class,
            "%javabin%": "JAVABIN=" + java_bin_path,
            "%jvm_flags%": jvm_flags,
            "%needs_runfiles%": needs_runfiles,
            "%runfiles_manifest_only%": "",
            "%set_jacoco_java_runfiles_root%": "",
            "%set_jacoco_main_class%": "",
            "%set_jacoco_metadata%": "",
            "%set_java_coverage_new_implementation%": """export JAVA_COVERAGE_NEW_IMPLEMENTATION=NO""",
            "%test_runtime_classpath_file%": "export TEST_RUNTIME_CLASSPATH_FILE=${JAVA_RUNFILES}",
            "%workspace_prefix%": workspace_prefix,
        },
        is_executable = True,
    )

    return depset(
        transitive = [
            runtime_jars,
            java_runtime.files,
            toolchain_info.kotlin_stdlib.transitive_compile_time_jars,
        ],
    )

def write_windows_jvm_launcher(
        ctx,
        toolchain_info,
        runtime_jars,
        main_class,
        jvm_flags,
        executable):
    """Create a Windows exe launcher for core_kt_jvm_binary.

    Args:
        ctx: rule context used to declare the launcher and read the workspace name.
        toolchain_info: resolved Kotlin toolchain info.
        runtime_jars: runtime jars placed on the launcher classpath.
        main_class: fully qualified main class to launch.
        jvm_flags: JVM flags passed to the launched binary.
        executable: declared launcher executable output file.

    Returns:
        A depset of files needed for runfiles (runtime jars, java runtime, kotlin stdlib).
    """
    java_runtime = toolchain_info.java_runtime

    # Normalize java_bin_path
    java_bin_path = java_runtime.java_executable_runfiles_path
    if not (java_bin_path.startswith("/") or (len(java_bin_path) > 2 and java_bin_path[1] == ":")):
        java_bin_path = ctx.workspace_name + "/" + java_bin_path
    java_bin_path = paths.normalize(java_bin_path)

    # Enable security manager for Java 17-23
    _java_runtime_version = getattr(java_runtime, "version", 0)
    jvm_flags_list = jvm_flags.split() if jvm_flags else []
    if _java_runtime_version >= 17 and _java_runtime_version < 24:
        jvm_flags_list.append("-Djava.security.manager=allow")

    # Build classpath from runtime jars and kotlin stdlib
    classpath = runtime_jars.to_list() + toolchain_info.kotlin_stdlib.transitive_compile_time_jars.to_list()

    launch_info = ctx.actions.args().use_param_file("%s", use_always = True).set_param_file_format("multiline")
    launch_info.add("binary_type=Java")
    launch_info.add(ctx.workspace_name, format = "workspace_name=%s")
    launch_info.add("1", format = "symlink_runfiles_enabled=%s")
    launch_info.add(java_bin_path, format = "java_bin_path=%s")
    launch_info.add(main_class, format = "java_start_class=%s")
    launch_info.add_joined(
        classpath,
        map_each = _artifact_short_path,
        join_with = ";",
        format_joined = "classpath=%s",
        omit_if_empty = False,
    )
    launch_info.add_joined(jvm_flags_list, join_with = "\t", format_joined = "jvm_flags=%s", omit_if_empty = False)
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

    return depset(
        transitive = [
            runtime_jars,
            java_runtime.files,
            toolchain_info.kotlin_stdlib.transitive_compile_time_jars,
        ],
    )

def build_deploy_jar(toolchain_info, actions, jars, output_jar):
    """Builds a normalized deploy jar by merging all jars using SingleJar.

    Args:
        toolchain_info: resolved Kotlin toolchain info providing single_jar.
        actions: rule actions object used to run the SingleJar action.
        jars: input jars merged into the deploy jar.
        output_jar: declared deploy jar output file.
    """
    args = actions.args()
    args.add("--exclude_build_data")
    args.add("--dont_change_compression")
    args.add_all("--sources", jars)
    args.add("--normalize")
    args.add("--output", output_jar)
    actions.run(
        inputs = jars,
        outputs = [output_jar],
        executable = toolchain_info.single_jar,
        mnemonic = "SingleJar",
        arguments = [args],
        toolchain = TYPE,
    )
