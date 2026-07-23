# The entire test suite excluding local tests.
test_suite(
    name = "all_tests",
    tests = [
        "//src/test/kotlin/io/bazel/kotlin:assertion_tests",
        "//src/test/kotlin/io/bazel/kotlin/builder:builder_tests",
        "//src/test/kotlin/io/bazel/worker:worker_tests",
        "//src/test/starlark:convert_tests",
        "//src/test/starlark:resource_strip_prefix_tests",
    ],
)

# Local tests. Tests that shouldn't be run on the CI server.
test_suite(
    name = "all_local_tests",
    tests = [
        ":all_tests",
        "//src/test/kotlin/io/bazel/kotlin:local_assertion_tests",
        "//src/test/kotlin/io/bazel/worker:local_worker_tests",
        "//src/test/starlark:convert_tests",
        "//src/test/starlark:resource_strip_prefix_tests",
    ],
)
