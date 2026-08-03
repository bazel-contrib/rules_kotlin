load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//kotlin:jvm.bzl", "kt_jvm_library")

def _resource_path_test_impl(ctx):
    env = analysistest.begin(ctx)

    actions = analysistest.target_actions(env)

    # Find the only FileWrite action (it's the one responsible for writing the arguments to the resource zipper)
    file_write_actions = [
        action
        for action in actions
        if action.mnemonic == "FileWrite"
    ]
    asserts.equals(env, expected = 1, actual = len(file_write_actions))

    arguments = file_write_actions[0].content

    # The only line should be of the form:
    # data.txt=<some prefix>/<pkg>/resourcez/data.txt
    lines = arguments.splitlines()
    asserts.equals(env, expected = 1, actual = len(lines))
    line_parts = lines[0].split("=", 1)
    asserts.equals(env, expected = 2, actual = len(line_parts))
    source_path = line_parts[1]
    expected_suffix = ctx.attr.expected_source_suffix
    asserts.true(
        env,
        source_path.endswith(expected_suffix),
        msg = "source path " + source_path + " does not have expected suffix " + expected_suffix,
    )

    destination_path = line_parts[0]

    asserts.equals(
        env,
        expected = ctx.attr.expected_destination_path,
        actual = destination_path,
        msg = "resource path was not normalized correctly",
    )

    return analysistest.end(env)

resource_path_test = analysistest.make(
    _resource_path_test_impl,
    attrs = {
        "expected_destination_path": attr.string(),
        "expected_source_suffix": attr.string(),
    },
)

# Macro to setup the test.
def _strip_resource_prefix_contents():
    pkg = native.package_name()

    write_file(
        name = "file",
        out = "resourcez/resource.txt",
        tags = ["manual"],
    )

    write_file(
        name = "source",
        out = "Source.kt",
        tags = ["manual"],
    )

    write_file(
        name = "generated_default_file",
        out = "generated/resource.txt",
        tags = ["manual"],
    )

    write_file(
        name = "generated_standard_resource",
        out = "src/main/resources/generated_resource.txt",
        tags = ["manual"],
    )

    kt_jvm_library(
        name = "dynamically_created_file",
        srcs = ["source"],
        resource_strip_prefix = "resourcez",
        resources = ["file"],  # note: file created dynamically above
        tags = ["manual"],
    )

    kt_jvm_library(
        name = "workspace_relative_dynamically_created_file",
        srcs = ["source"],
        resource_strip_prefix = pkg + "/resourcez",
        resources = ["file"],
        tags = ["manual"],
    )

    kt_jvm_library(
        name = "static_file",
        srcs = ["source"],
        resource_strip_prefix = "test_resources",
        resources = ["test_resources/resource.txt"],  # static file in the package
        tags = ["manual"],
    )

    kt_jvm_library(
        name = "workspace_relative_static_file",
        srcs = ["source"],
        resource_strip_prefix = pkg + "/test_resources",
        resources = ["test_resources/resource.txt"],
        tags = ["manual"],
    )

    kt_jvm_library(
        name = "nested_static_dir",
        srcs = ["source"],
        resource_strip_prefix = "test_resources/nested",
        resources = ["test_resources/nested/nested_resource.txt"],
        tags = ["manual"],
    )

    kt_jvm_library(
        name = "workspace_relative_nested_dir",
        srcs = ["source"],
        # The rules_java-style spelling: the full workspace-root-relative path, which parses as a
        # package-relative label and resolves to a doubled <pkg>/<pkg>/... path.
        resource_strip_prefix = pkg + "/test_resources/nested",
        resources = ["test_resources/nested/nested_resource.txt"],
        tags = ["manual"],
    )

    kt_jvm_library(
        name = "package_root_dir",
        srcs = ["source"],
        # The workspace-root-relative spelling of the package itself: strips the entire package,
        # leaving the in-package path as the jar entry. This scenario has no package-relative
        # sibling: a package-relative label cannot name the package directory itself.
        resource_strip_prefix = pkg,
        resources = ["test_resources/resource.txt"],
        tags = ["manual"],
    )

    kt_jvm_library(
        name = "package_name_collision_dir",
        srcs = ["source"],
        # An ordinary package-relative path to an in-package directory that only coincidentally
        # spells like the package itself (the same resolved value as package_root_dir's attribute)
        resource_strip_prefix = "src/test/starlark",
        resources = ["src/test/starlark/collision_resource.txt"],
        tags = ["manual"],
    )

    kt_jvm_library(
        name = "workspace_relative_collision_dir",
        srcs = ["source"],
        resource_strip_prefix = pkg + "/src/test/starlark",
        resources = ["src/test/starlark/collision_resource.txt"],
        tags = ["manual"],
    )

    kt_jvm_library(
        name = "standard_package",
        srcs = ["source"],
        resources = ["src/main/resources/resource.txt"],  # no explicit strip prefix
        tags = ["manual"],
    )

    kt_jvm_library(
        name = "generated_default_package",
        srcs = ["source"],
        resources = ["generated_default_file"],
        tags = ["manual"],
    )

    kt_jvm_library(
        name = "generated_standard_package",
        srcs = ["source"],
        resources = ["generated_standard_resource"],
        tags = ["manual"],
    )

    package_name = native.package_name().split("/")[-1]
    native.filegroup(
        name = package_name,
        srcs = ["test_resources/actual_file.txt"],
    )

    kt_jvm_library(
        name = "same_as_package_name",
        srcs = ["source"],
        resources = [package_name],  # filegroup defined above
        resource_strip_prefix = "test_resources",
        tags = ["manual"],
    )

    kt_jvm_library(
        name = "workspace_relative_same_as_package_name",
        srcs = ["source"],
        resources = [package_name],  # filegroup defined above
        resource_strip_prefix = pkg + "/test_resources",
        tags = ["manual"],
    )

    resource_path_test(
        name = "dynamically_created_file_test",
        target_under_test = ":dynamically_created_file",
        tags = ["manual"],
        expected_destination_path = "resource.txt",
        expected_source_suffix = pkg + "/resourcez/resource.txt",
    )

    resource_path_test(
        name = "workspace_relative_dynamically_created_file_test",
        target_under_test = ":workspace_relative_dynamically_created_file",
        tags = ["manual"],
        expected_destination_path = "resource.txt",
        expected_source_suffix = pkg + "/resourcez/resource.txt",
    )

    resource_path_test(
        name = "static_file_test",
        target_under_test = ":static_file",
        tags = ["manual"],
        expected_destination_path = "resource.txt",
        expected_source_suffix = pkg + "/test_resources/resource.txt",
    )

    resource_path_test(
        name = "workspace_relative_static_file_test",
        target_under_test = ":workspace_relative_static_file",
        tags = ["manual"],
        expected_destination_path = "resource.txt",
        expected_source_suffix = pkg + "/test_resources/resource.txt",
    )

    resource_path_test(
        name = "nested_static_dir_test",
        target_under_test = ":nested_static_dir",
        tags = ["manual"],
        expected_destination_path = "nested_resource.txt",
        expected_source_suffix = pkg + "/test_resources/nested/nested_resource.txt",
    )

    resource_path_test(
        name = "workspace_relative_nested_dir_test",
        target_under_test = ":workspace_relative_nested_dir",
        tags = ["manual"],
        expected_destination_path = "nested_resource.txt",
        expected_source_suffix = pkg + "/test_resources/nested/nested_resource.txt",
    )

    resource_path_test(
        name = "package_root_dir_test",
        target_under_test = ":package_root_dir",
        tags = ["manual"],
        expected_destination_path = "test_resources/resource.txt",
        expected_source_suffix = pkg + "/test_resources/resource.txt",
    )

    resource_path_test(
        name = "package_name_collision_dir_test",
        target_under_test = ":package_name_collision_dir",
        tags = ["manual"],
        expected_destination_path = "collision_resource.txt",
        expected_source_suffix = pkg + "/src/test/starlark/collision_resource.txt",
    )

    resource_path_test(
        name = "workspace_relative_collision_dir_test",
        target_under_test = ":workspace_relative_collision_dir",
        tags = ["manual"],
        expected_destination_path = "collision_resource.txt",
        expected_source_suffix = pkg + "/src/test/starlark/collision_resource.txt",
    )

    resource_path_test(
        name = "standard_package_test",
        target_under_test = ":standard_package",
        tags = ["manual"],
        expected_destination_path = "resource.txt",
        expected_source_suffix = pkg + "/src/main/resources/resource.txt",
    )

    resource_path_test(
        name = "generated_default_package_test",
        target_under_test = ":generated_default_package",
        tags = ["manual"],
        expected_destination_path = pkg + "/generated/resource.txt",
        expected_source_suffix = pkg + "/generated/resource.txt",
    )

    resource_path_test(
        name = "generated_standard_package_test",
        target_under_test = ":generated_standard_package",
        tags = ["manual"],
        expected_destination_path = "generated_resource.txt",
        expected_source_suffix = pkg + "/src/main/resources/generated_resource.txt",
    )

    resource_path_test(
        name = "same_as_package_name_test",
        target_under_test = ":same_as_package_name",
        tags = ["manual"],
        expected_destination_path = "actual_file.txt",
        expected_source_suffix = pkg + "/test_resources/actual_file.txt",
    )

    resource_path_test(
        name = "workspace_relative_same_as_package_name_test",
        target_under_test = ":workspace_relative_same_as_package_name",
        tags = ["manual"],
        expected_destination_path = "actual_file.txt",
        expected_source_suffix = pkg + "/test_resources/actual_file.txt",
    )

# Entry point from the BUILD file; macro for running each test case's macro and
# declaring a test suite that wraps them together.
def strip_resource_prefix_test_suite(name):
    # Call all test functions and wrap their targets in a suite.
    _strip_resource_prefix_contents()

    native.test_suite(
        name = name,
        tests = [
            ":dynamically_created_file_test",
            ":nested_static_dir_test",
            ":package_name_collision_dir_test",
            ":package_root_dir_test",
            ":workspace_relative_collision_dir_test",
            ":workspace_relative_dynamically_created_file_test",
            ":workspace_relative_nested_dir_test",
            ":workspace_relative_same_as_package_name_test",
            ":workspace_relative_static_file_test",
            ":generated_default_package_test",
            ":generated_standard_package_test",
            ":static_file_test",
            ":standard_package_test",
            ":same_as_package_name_test",
        ],
        tags = ["manual"],
    )
