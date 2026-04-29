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

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@rules_java//java:defs.bzl", "JavaInfo", "JavaPluginInfo", "java_common")
load(
    "//kotlin/internal:defs.bzl",
    _KspPluginInfo = "KspPluginInfo",
    _KtCompilerPluginInfo = "KtCompilerPluginInfo",
    _KtJvmInfo = "KtJvmInfo",
    _TOOLCHAIN_TYPE = "TOOLCHAIN_TYPE",
)
load(
    "//kotlin/internal/jvm:compile.bzl",
    _compile = "compile",
)
load(
    "//kotlin/internal/utils:utils.bzl",
    _utils = "utils",
)
load(
    "//src/main/starlark/core/compile:common.bzl",
    "find_launcher_maker",
    "get_executable",
    "get_launcher_maker_toolchain_for_action",
    "is_windows",
)
load("//src/main/starlark/core/plugin:common.bzl", "plugin_common")
load("//third_party:jarjar.bzl", "jarjar_action")

def _artifact_short_path(artifact):
    return artifact.short_path

def _make_providers(ctx, providers, runfiles_targets, transitive_files = depset(order = "default"), executable = None, *additional_providers):
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

def _write_launcher_action(ctx, rjars, main_class, jvm_flags, is_test = False):
    """Macro that writes out a launcher script shell script.
      Args:
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

# buildifier: disable=unused-variable
def _is_source_jar_stub(jar):
    """Workaround for intellij plugin expecting a source jar"""
    return jar.path.endswith("third_party/empty.jar")

def _unify_jars(ctx):
    if bool(ctx.attr.jar):
        return struct(class_jar = ctx.file.jar, source_jar = ctx.file.srcjar, ijar = None)
    else:
        # Legacy handling.
        jars = []
        source_jars = []
        if (ctx.file.srcjar and not ("%s" % ctx.file.srcjar.path).endswith("third_party/empty.jar")):
            source_jars.append(ctx.file.srcjar)

        # There must be a single jar jar and it can either be a filegroup or a JavaInfo.
        for jar in ctx.attr.jars:
            # If a JavaInfo is available it's because it was picked up from a `maven_jar` style attribute -- e.g.,
            # @com_google_guava_guava//jar. so the transitive_compile_jars or the transitive_runtime_jars should not be
            # visited -- descending into these results in ijars entering the graph.
            if JavaInfo in jar:
                jars += jar[JavaInfo].full_compile_jars.to_list()
                source_jars += jar[JavaInfo].transitive_source_jars.to_list()
            else:
                # this branch occurs when the attr was a filegroup.
                for file in jar.files.to_list():
                    if file.basename.endswith("-sources.jar"):
                        source_jars.append(file)
                    elif file.basename.endswith(".jar"):
                        jars.append(file)
                    else:
                        fail("a jar pointing to a filegroup must either end with -sources.jar or .jar: %s", file)

        if len(jars) > 1:
            fail("Got more than one jar, this is an error create an issue: %s" % jars)
        if len(source_jars) > 1:
            fail("Got more than one source jar. " +
                 "Did you include both srcjar and a sources jar in the jars attribute?: %s" % source_jars)
        return struct(class_jar = jars[0], source_jar = source_jars[0] if len(source_jars) == 1 else None, ijar = None)

def kt_jvm_import_impl(ctx):
    if bool(ctx.attr.jars) and bool(ctx.attr.jar):
        fail("Cannot use both jars= and jar= attribute.  Prefer jar=")

    artifact = _unify_jars(ctx)
    kt_info = _KtJvmInfo(
        module_name = _utils.derive_module_name(ctx),
        module_jars = [],
        exported_compiler_plugins = depset(getattr(ctx.attr, "exported_compiler_plugins", [])),
        classpath_snapshot = None,
        transitive_classpath_snapshots = depset(),
        transitive_non_kotlin_classpath_snapshot_jars = depset(),
        outputs = struct(
            jars = [artifact],
        ),
    )

    return [
        DefaultInfo(
            files = depset(direct = [artifact.class_jar]),
            runfiles = ctx.runfiles(
                # Append class jar with the optional sources jar
                files = [artifact.class_jar] + [artifact.source_jar] if artifact.source_jar else [],
            ).merge_all([d[DefaultInfo].default_runfiles for d in ctx.attr.deps]),
        ),
        JavaInfo(
            output_jar = artifact.class_jar,
            compile_jar = artifact.class_jar,
            source_jar = artifact.source_jar,
            runtime_deps = [dep[JavaInfo] for dep in ctx.attr.runtime_deps if JavaInfo in dep],
            deps = [dep[JavaInfo] for dep in ctx.attr.deps if JavaInfo in dep],
            exports = [d[JavaInfo] for d in getattr(ctx.attr, "exports", [])],
            neverlink = getattr(ctx.attr, "neverlink", False),
        ),
        kt_info,
    ]

def kt_jvm_library_impl(ctx):
    if ctx.attr.neverlink and ctx.attr.runtime_deps:
        fail("runtime_deps and neverlink is nonsensical.", attr = "runtime_deps")

    if not ctx.attr.srcs and len(ctx.attr.deps) > 0:
        fail(
            "deps without srcs is invalid." +
            "\nTo add runtime dependencies use runtime_deps." +
            "\nTo export libraries use exports.",
            attr = "deps",
        )
    return _make_providers(
        ctx,
        providers = _compile.kt_jvm_produce_jar_actions(ctx, "kt_jvm_library") if ctx.attr.srcs or ctx.attr.resources else _compile.export_only_providers(
            ctx = ctx,
            actions = ctx.actions,
            outputs = ctx.outputs,
            attr = ctx.attr,
        ),
        runfiles_targets = ctx.attr.deps + ctx.attr.exports + ctx.attr.runtime_deps + ctx.attr.data,
    )

def kt_jvm_binary_impl(ctx):
    providers = _compile.kt_jvm_produce_jar_actions(ctx, "kt_jvm_binary")
    jvm_flags = []
    if hasattr(ctx.fragments.java, "default_jvm_opts"):
        jvm_flags = ctx.fragments.java.default_jvm_opts
    jvm_flags.extend(ctx.attr.jvm_flags)
    launcher_result = _write_launcher_action(
        ctx,
        providers.java.transitive_runtime_jars,
        ctx.attr.main_class,
        jvm_flags,
    )
    if len(ctx.attr.srcs) == 0 and len(ctx.attr.deps) > 0:
        fail("deps without srcs is invalid. To add runtime classpath and resources, use runtime_deps.", attr = "deps")

    # Get java runtime files from toolchain for runfiles (needed for Windows launcher)
    java_runtime = ctx.toolchains["@bazel_tools//tools/jdk:runtime_toolchain_type"].java_runtime

    return _make_providers(
        ctx,
        providers,
        ctx.attr.deps + ctx.attr.runtime_deps + ctx.attr.data,
        depset(
            order = "default",
            transitive = [providers.java.transitive_runtime_jars, java_runtime.files],
        ),
        launcher_result.executable,
        RunEnvironmentInfo(
            environment = ctx.attr.env,
            inherited_environment = ctx.attr.env_inherit,
        ),
    )

_SPLIT_STRINGS = [
    "src/test/java/",
    "src/test/kotlin/",
    "javatests/",
    "kotlin/",
    "java/",
    "test/",
]

def kt_jvm_junit_test_impl(ctx):
    providers = _compile.kt_jvm_produce_jar_actions(ctx, "kt_jvm_test")
    runtime_jars = depset(ctx.files._bazel_test_runner, transitive = [providers.java.transitive_runtime_jars])

    coverage_runfiles = []
    if ctx.configuration.coverage_enabled:
        jacocorunner = ctx.toolchains[_TOOLCHAIN_TYPE].jacocorunner
        coverage_runfiles = jacocorunner.files.to_list()

    test_class = ctx.attr.test_class

    # If no test_class, do a best-effort attempt to infer one.
    if not bool(ctx.attr.test_class):
        for file in ctx.files.srcs:
            package_relative_path = file.path.replace(ctx.label.package + "/", "")
            if package_relative_path.split(".")[0] == ctx.attr.name:
                for splitter in _SPLIT_STRINGS:
                    elements = file.short_path.split(splitter, 1)
                    if len(elements) == 2:
                        test_class = elements[1].split(".")[0].replace("/", ".")
                        break

    jvm_flags = []
    if hasattr(ctx.fragments.java, "default_jvm_opts"):
        jvm_flags = ctx.fragments.java.default_jvm_opts

    jvm_flags.extend(ctx.attr.jvm_flags)
    launcher_result = _write_launcher_action(
        ctx,
        runtime_jars,
        main_class = ctx.attr.main_class,
        jvm_flags = [
            "-ea",
            "-Dbazel.test_suite=%s" % test_class,
        ] + jvm_flags,
        is_test = True,
    )

    # Get java runtime files from toolchain for runfiles (needed for Windows launcher)
    java_runtime = ctx.toolchains["@bazel_tools//tools/jdk:runtime_toolchain_type"].java_runtime

    return _make_providers(
        ctx,
        providers,
        ctx.attr.deps + ctx.attr.runtime_deps + ctx.attr.data,
        depset(
            order = "default",
            transitive = [runtime_jars, depset(coverage_runfiles), depset(launcher_result.coverage_metadata), java_runtime.files],
        ),
        launcher_result.executable,
        # adds common test variables, including TEST_WORKSPACE.
        testing.TestEnvironment(environment = ctx.attr.env, inherited_environment = ctx.attr.env_inherit),
    )

_KtCompilerPluginClasspathInfo = provider(
    fields = {
        "infos": "list JavaInfos of a compiler library",
        "reshaded_infos": "list reshaded JavaInfos of a compiler library",
    },
)

def kt_compiler_deps_aspect_impl(target, ctx):
    """
    Collects and reshades (if necessary) all jars in the plugin transitive closure.

    Args:
        target: Target of the rule being inspected
        ctx: aspect ctx
    Returns:
        list of _KtCompilerPluginClasspathInfo
    """
    transitive_infos = [
        t[_KtCompilerPluginClasspathInfo]
        for d in ["deps", "runtime_deps", "exports"]
        for t in getattr(ctx.rule.attr, d, [])
        if _KtCompilerPluginClasspathInfo in t
    ]
    reshaded_infos = []
    infos = [
        i
        for t in transitive_infos
        for i in t.infos
    ]
    if JavaInfo in target:
        ji = target[JavaInfo]
        infos.append(ji)
        reshaded_infos.append(
            _reshade_embedded_kotlinc_jars(
                target = target,
                ctx = ctx,
                jars = ji.runtime_output_jars,
                deps = [
                    i
                    for t in transitive_infos
                    for i in t.reshaded_infos
                ],
            ),
        )

    return [
        _KtCompilerPluginClasspathInfo(
            reshaded_infos = reshaded_infos,
            infos = [java_common.merge(infos)],
        ),
    ]

def _reshade_embedded_kotlinc_jars(target, ctx, jars, deps):
    # No jars to reshade — just propagate transitive deps (e.g. sourceless libraries).
    if not jars:
        return java_common.merge(deps) if deps else java_common.merge([])

    reshaded = [
        jarjar_action(
            actions = ctx.actions,
            jarjar = ctx.executable._jarjar,
            rules = ctx.file._kotlin_compiler_reshade_rules,
            input = jar,
            output = ctx.actions.declare_file(
                "%s_reshaded_%s" % (target.label.name, jar.basename),
            ),
        )
        for jar in jars
    ]

    # JavaInfo only takes a single jar, so create many and merge them.
    return java_common.merge(
        [
            JavaInfo(output_jar = jar, compile_jar = jar, deps = deps)
            for jar in reshaded
        ],
    )

def _expand_location_with_data_deps(ctx):
    return lambda targets: ctx.expand_location(targets, ctx.attr.data)

def kt_compiler_plugin_impl(ctx):
    plugin_id = ctx.attr.id

    deps = ctx.attr.deps
    info = None
    if ctx.attr.target_embedded_compiler:
        info = java_common.merge([
            i
            for d in deps
            for i in d[_KtCompilerPluginClasspathInfo].reshaded_infos
        ])
    else:
        info = java_common.merge([
            i
            for d in deps
            for i in d[_KtCompilerPluginClasspathInfo].infos
        ])

    classpath = depset(info.runtime_output_jars, transitive = [info.transitive_runtime_jars])

    # TODO(1035): Migrate kt_compiler_plugin.options to string_list_dict
    options = plugin_common.resolve_plugin_options(plugin_id, {k: [v] for (k, v) in ctx.attr.options.items()}, _expand_location_with_data_deps(ctx))

    return [
        DefaultInfo(files = classpath),
        _KtCompilerPluginInfo(
            id = plugin_id,
            classpath = classpath,
            options = options,
            stubs = ctx.attr.stubs_phase,
            compile = ctx.attr.compile_phase,
            resolve_cfg = plugin_common.resolve_cfg,
            merge_cfgs = plugin_common.merge_cfgs,
        ),
    ]

def kt_plugin_cfg_impl(ctx):
    plugin = ctx.attr.plugin[_KtCompilerPluginInfo]
    return [
        plugin,
    ] + plugin.resolve_cfg(plugin, ctx.attr.options, ctx.attr.deps, _expand_location_with_data_deps(ctx))

def kt_ksp_plugin_impl(ctx):
    deps = ctx.attr.deps
    if ctx.attr.target_embedded_compiler:
        info = java_common.merge([
            i
            for d in deps
            for i in d[_KtCompilerPluginClasspathInfo].reshaded_infos
        ])
    else:
        info = java_common.merge([dep[JavaInfo] for dep in deps])

    classpath = depset(info.runtime_output_jars, transitive = [info.transitive_runtime_jars])

    return [
        DefaultInfo(files = classpath),
        _KspPluginInfo(
            plugins = [
                JavaPluginInfo(
                    runtime_deps = [
                        info,
                    ],
                    processor_class = ctx.attr.processor_class,
                    # rules_kotlin doesn't support stripping non-api generating annotation
                    # processors out of the public ABI.
                    generates_api = True,
                ),
            ],
            generates_java = ctx.attr.generates_java,
            options = ctx.attr.options,
        ),
    ]
