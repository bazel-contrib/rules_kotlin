load("@bazel_features//:features.bzl", "bazel_features")

TYPE = "//src/main/starlark/core/compile:toolchain_type"

# Java toolchains
JAVA_TOOLCHAIN_TYPE = Label("@bazel_tools//tools/jdk:toolchain_type")
JAVA_RUNTIME_TOOLCHAIN_TYPE = Label("@bazel_tools//tools/jdk:runtime_toolchain_type")

# Toolchain type for the Windows launcher maker
LAUNCHER_MAKER_TOOLCHAIN_TYPE = "@bazel_tools//tools/launcher:launcher_maker_toolchain_type"

def is_windows(ctx):
    """Check if the target platform is Windows."""
    windows_constraint = ctx.attr._windows_constraint[platform_common.ConstraintValueInfo]
    return ctx.target_platform_has_constraint(windows_constraint)

def get_executable(ctx):
    """Declare executable file, adding .exe extension on Windows.

    Args:
        ctx: Rule context.

    Returns:
        A declared output file for the executable on the target platform.
    """
    executable_name = ctx.label.name
    if is_windows(ctx):
        executable_name = executable_name + ".exe"
    return ctx.actions.declare_file(executable_name)

def find_launcher_maker(ctx):
    """Find the launcher maker binary, preferring the toolchain approach."""
    if bazel_features.rules._has_launcher_maker_toolchain:
        return ctx.toolchains[LAUNCHER_MAKER_TOOLCHAIN_TYPE].binary
    return ctx.executable._windows_launcher_maker

def get_launcher_maker_toolchain_for_action():
    """Return the toolchain type for ctx.actions.run, or None if not available."""
    if bazel_features.rules._has_launcher_maker_toolchain:
        return LAUNCHER_MAKER_TOOLCHAIN_TYPE
    return None

KtJvmInfo = provider(
    fields = {
        "additional_generated_source_jars": "Returns additional Jars containing generated source files from kapt, ksp, etc. [bazel-bsp-aspect]",
        "all_output_jars": "Returns all the output Jars produced by this rule. [bazel-bsp-aspect]",
        "annotation_processing": "Generated annotation processing jars. [intellij-aspect]",
        "classpath_snapshot": "Classpath snapshot file for incremental compilation (None if IC disabled)",
        "exported_compiler_plugins": "compiler plugins to be invoked by targets depending on this.",
        "language_version": "version of kotlin used. [intellij-aspect]",
        "module_jars": "Jars comprising the module (logical compilation unit), a.k.a. associates",
        "module_name": "the module name",
        "outputs": "output jars produced by this rule. [intelij-aspect]",
        "srcs": "the source files. [intelij-aspect]",
        "transitive_classpath_snapshots": "Transitive classpath snapshots for IC invalidation.",
        "transitive_non_kotlin_classpath_snapshot_jars": "Transitive non-Kotlin compile jars that still need local snapshot generation.",
        "transitive_compile_time_jars": "Returns the transitive set of Jars required to build the target. [intellij-aspect]",
        "transitive_source_jars": "Returns the Jars containing source files of the current target and all of its transitive dependencies. [intellij-aspect]",
    },
)
