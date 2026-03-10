"""Macros for managing the integration test framework."""

load("@bazel_binaries//:defs.bzl", "bazel_binaries")
load(
    "@rules_bazel_integration_test//bazel_integration_test:defs.bzl",
    "bazel_integration_test",
)

def derive_metadata(directory):
    return struct(
        directory = directory,
        workspace_files = native.glob(
            ["%s/**/**" % directory],
            # exclude any bazel directories if existing
            exclude = ["%s/bazel-*/**" % directory],
        ),
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
    )

def example_integration_test_suite(
        name,
        metadata,
        tags):
    for version in bazel_binaries.versions.all:
        if version in metadata.only or (not metadata.only and version not in metadata.exclude):
            clean_bazel_version = Label(version).name
            if metadata.has_module:
                bazel_integration_test(
                    name = "%s_%s_test" % (name, clean_bazel_version),
                    timeout = "eternal",
                    additional_env_inherit = [
                        "ANDROID_HOME",
                        "ANDROID_SDK_ROOT",
                        "ANDROID_NDK_HOME",
                    ],
                    bazel_version = version,
                    tags = tags + [clean_bazel_version, name],
                    test_runner = "//src/main/kotlin/io/bazel/kotlin/test:BazelIntegrationTestRunner",
                    workspace_files = metadata.workspace_files,
                    workspace_path = metadata.directory,
                )

    native.test_suite(
        name = name,
        tags = [name],
    )
