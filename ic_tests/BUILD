load(":ic_integration_test.bzl", "ic_integration_test_suite")

ic_integration_test_suite(
    name = "trivial_change",
    tags = ["manual"],  # Run explicitly, not in //...
    workspace_path = "ic_tests/testdata/trivial_change",
)

ic_integration_test_suite(
    name = "inline_function_change",
    tags = ["manual"],  # Run explicitly, not in //...
    workspace_path = "ic_tests/testdata/inline_function_change",
)

ic_integration_test_suite(
    name = "plugin_options_change",
    tags = ["manual"],
    workspace_path = "ic_tests/testdata/plugin_options_change",
)

ic_integration_test_suite(
    name = "kotlinc_flags_change",
    tags = ["manual"],
    workspace_path = "ic_tests/testdata/kotlinc_flags_change",
)

ic_integration_test_suite(
    name = "jvm_target_change",
    tags = ["manual"],
    workspace_path = "ic_tests/testdata/jvm_target_change",
)

ic_integration_test_suite(
    name = "transitive_snapshot_change",
    tags = ["manual"],
    workspace_path = "ic_tests/testdata/transitive_snapshot_change",
)

ic_integration_test_suite(
    name = "exported_java_dep_snapshot_change",
    tags = ["manual"],
    workspace_path = "ic_tests/testdata/exported_java_dep_snapshot_change",
)

test_suite(
    name = "ic_tests_suite",
    tags = ["ic"],
    tests = [
        "inline_function_change",
        "jvm_target_change",
        "kotlinc_flags_change",
        "plugin_options_change",
        "exported_java_dep_snapshot_change",
        "transitive_snapshot_change",
        "trivial_change",
    ],
)
