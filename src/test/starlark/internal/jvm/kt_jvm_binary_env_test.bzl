load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("@rules_testing//lib:util.bzl", "util")
load("//kotlin:jvm.bzl", "kt_jvm_binary")

def _kt_jvm_binary_env_test_impl(env, target):
    """Test that kt_jvm_binary sets RunEnvironmentInfo correctly."""

    # Check that RunEnvironmentInfo is present
    env.expect.that_target(target).has_provider(RunEnvironmentInfo)

    # Get the RunEnvironmentInfo provider
    run_env_info = target[RunEnvironmentInfo]

    # Verify the environment variables
    env.expect.that_dict(run_env_info.environment).contains_exactly({
        "BAZ": "qux",
        "FOO": "bar",
    })

    # Verify the inherited environment variables
    env.expect.that_collection(run_env_info.inherited_environment).contains_exactly([
        "HOME",
        "PATH",
    ])

def _kt_jvm_binary_env_test(name):
    """Creates a test that verifies env and env_inherit attributes work."""
    kt_jvm_binary(
        name = name + "_subject",
        srcs = [util.empty_file(name + "_Main.kt")],
        main_class = "test.Main",
        env = {
            "BAZ": "qux",
            "FOO": "bar",
        },
        env_inherit = ["HOME", "PATH"],
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        impl = _kt_jvm_binary_env_test_impl,
        target = name + "_subject",
    )

def _kt_jvm_binary_empty_env_test_impl(env, target):
    """Test that kt_jvm_binary works with no env attributes."""

    # Check that RunEnvironmentInfo is present
    env.expect.that_target(target).has_provider(RunEnvironmentInfo)

    # Get the RunEnvironmentInfo provider
    run_env_info = target[RunEnvironmentInfo]

    # Verify the environment is empty
    env.expect.that_dict(run_env_info.environment).contains_exactly({})

    # Verify no inherited environment variables
    env.expect.that_collection(run_env_info.inherited_environment).contains_exactly([])

def _kt_jvm_binary_empty_env_test(name):
    """Creates a test that verifies default env behavior."""
    kt_jvm_binary(
        name = name + "_subject",
        srcs = [util.empty_file(name + "_Main.kt")],
        main_class = "test.Main",
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        impl = _kt_jvm_binary_empty_env_test_impl,
        target = name + "_subject",
    )

def _kt_jvm_binary_env_expansion_test_impl(env, target):
    """Test that kt_jvm_binary expands make variables and locations in env."""

    run_env_info = target[RunEnvironmentInfo]
    env.expect.that_dict(run_env_info.environment).contains_exactly({
        "BUILD_MODE": "fastbuild",
        "RESOURCE_PATH": "src/test/starlark/internal/jvm/expanded_env_resource.txt",
    })

def _kt_jvm_binary_env_expansion_test(name):
    """Creates a test that verifies env values are expanded like java_binary."""
    kt_jvm_binary(
        name = name + "_subject",
        srcs = [util.empty_file(name + "_Main.kt")],
        data = ["expanded_env_resource.txt"],
        main_class = "test.Main",
        env = {
            "BUILD_MODE": "$(COMPILATION_MODE)",
            "RESOURCE_PATH": "$(location expanded_env_resource.txt)",
        },
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        impl = _kt_jvm_binary_env_expansion_test_impl,
        target = name + "_subject",
    )

def kt_jvm_binary_env_test_suite(name):
    """Test suite for kt_jvm_binary env support."""
    test_suite(
        name = name,
        tests = [
            _kt_jvm_binary_env_test,
            _kt_jvm_binary_env_expansion_test,
            _kt_jvm_binary_empty_env_test,
        ],
    )
