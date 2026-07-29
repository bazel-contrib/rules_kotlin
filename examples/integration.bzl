"""Macros for managing the integration test framework."""

load("@bazel_binaries//:defs.bzl", "bazel_binaries")
load(
    "@rules_bazel_integration_test//bazel_integration_test:defs.bzl",
    "bazel_integration_test",
)

def _version_supports_workspace(clean_version):
    """Returns True if version < 9.0.0 (workspace is deprecated in Bazel 9+)."""

    # clean_version is already extracted via Label(version).name, e.g., "8.0.0" or "9.0.0rc5" or ".bazelversion"
    parts = clean_version.split(".")
    if len(parts) >= 1 and parts[0]:
        # Handle versions like "9.0.0rc5" by splitting on common suffixes
        major_str = parts[0]
        for suffix in ["rc", "pre", "alpha", "beta"]:
            major_str = major_str.split(suffix)[0]
        if major_str:
            major = int(major_str)
            return major < 9

    # For non-standard version strings (like ".bazelversion"), assume workspace is not supported
    # since we're transitioning away from workspace
    return False

def derive_metadata(directory):
    return struct(
        directory = directory,
        workspace_files = native.glob(
            ["%s/**/**" % directory],
            # exclude any bazel directories if existing
            exclude = ["%s/bazel-*/**" % directory],
        ) + ["//:local_repository_files"],
        exclude = [
            # Cut to the file name, and use it as an excluded bazel version. For exclusion to work
            # the file name in the `exclude` directory must match the bazel version in `bazel_binaries.versions.all`.
            # This is done as a secondary loop for readability and avoiding over-globbing.
            version.rpartition("/")[2]
            for version in native.glob(
                ["%s/exclude/*" % directory],
                allow_empty = True,
            )
        ],
        only = [
            # Cut to the file name, and use it as an only bazel version. For exclusion to work
            # the file name in the `only` directory must match the bazel version in `bazel_binaries.versions.all`.
            # This is done as a secondary loop for readability and avoiding over-globbing.
            version.rpartition("/")[2]
            for version in native.glob(
                ["%s/only/*" % directory],
                allow_empty = True,
            )
        ],
        has_module = len(native.glob(
            ["%s/MODULE.bazel" % directory, "%s/MODULE" % directory],
            allow_empty = True,
        )) > 0,
        has_workspace = len(native.glob(
            ["%s/WORKSPACE" % directory, "%s/WORKSPACE.bazel" % directory],
            allow_empty = True,
        )) > 0,
    )

def example_integration_test_suite(
        name,
        metadata,
        tags):
    for version in bazel_binaries.versions.all:
        if version in metadata.only or (not metadata.only and version not in metadata.exclude):
            clean_bazel_version = Label(version).name

            # Build list of modes to test
            modes = []
            if metadata.has_module:
                modes.append(("bzlmod", {}))
            if metadata.has_workspace and _version_supports_workspace(clean_bazel_version):
                modes.append(("workspace", {"WORKSPACE_ENABLED": "1"}))

            for mode, env in modes:
                bazel_integration_test(
                    name = "%s_%s_%s_test" % (name, mode, clean_bazel_version),
                    timeout = "eternal",
                    additional_env_inherit = [
                        "ANDROID_HOME",
                        "ANDROID_SDK_ROOT",
                        "ANDROID_NDK_HOME",
                    ],
                    env = env,
                    bazel_version = version,
                    tags = tags + [clean_bazel_version, name, name + "_" + mode],
                    test_runner = "//src/main/kotlin/io/bazel/kotlin/test:BazelIntegrationTestRunner",
                    workspace_files = metadata.workspace_files,
                    workspace_path = metadata.directory,
                )

    native.test_suite(
        name = name,
        tags = [name],
    )

    native.test_suite(
        name = name + "_bzlmod",
        tags = [name + "_bzlmod"],
    )

    native.test_suite(
        name = name + "_workspace",
        tags = [name + "_workspace"],
    )
