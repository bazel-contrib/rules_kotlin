"""Macros for incremental compilation integration tests."""

load("@bazel_binaries//:defs.bzl", "bazel_binaries")
load(
    "@rules_bazel_integration_test//bazel_integration_test:defs.bzl",
    "bazel_integration_test",
)

def ic_integration_test(
        name,
        workspace_path,
        workspace_files,
        tags = []):
    """Creates an IC integration test.

    This test:
    1. Copies the test workspace excluding .new/.delete files
    2. Renames BUILD.bazel.txt to BUILD.bazel
    3. Runs initial Bazel build with IC logging enabled
    4. Applies modifications (copy .new files, delete .delete files)
    5. Runs incremental build
    6. Compares IC logs against expected build.log in the workspace

    The test workspace should contain:
    - MODULE.bazel or WORKSPACE file
    - BUILD.bazel.txt (renamed to BUILD.bazel at runtime to avoid subpackage issues)
    - build.log (expected IC output)
    - Source files with optional .new/.delete variants

    Args:
        name: Test name
        workspace_path: Path to test workspace directory
        workspace_files: Glob of all workspace files (including .new/.delete)
        tags: Additional test tags
    """

    # Use the current (default) bazel version for IC tests
    bazel_integration_test(
        name = name,
        timeout = "long",
        bazel_version = bazel_binaries.versions.current,
        test_runner = "//src/main/kotlin/io/bazel/kotlin/test:ICIntegrationTestRunner",
        workspace_files = workspace_files,
        workspace_path = workspace_path,
        tags = tags + ["ic"],
    )

def ic_integration_test_suite(
        name,
        workspace_path,
        tags = []):
    """Creates an IC integration test suite for a single test case.

    Args:
        name: Test suite name
        workspace_path: Path to test workspace directory (relative to repo root)
        tags: Additional test tags
    """

    # workspace_path is relative to repo root (e.g., "ic_tests/trivial_change")
    # But glob is relative to current BUILD file directory
    # So we need to strip the package prefix
    package_name = native.package_name()  # e.g., "ic_tests"
    if workspace_path.startswith(package_name + "/"):
        local_path = workspace_path[len(package_name) + 1:]
    else:
        local_path = workspace_path

    workspace_files = native.glob(
        ["%s/**" % local_path],
        exclude = ["%s/bazel-*/**" % local_path],
    )

    ic_integration_test(
        name = name,
        workspace_path = workspace_path,
        workspace_files = workspace_files,
        tags = tags,
    )
