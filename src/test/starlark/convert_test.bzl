"""Tests for the option-to-flag conversion helpers."""

load(
    "@bazel_skylib//lib:unittest.bzl",
    "asserts",
    "unittest",
)
load("//src/main/starlark/core/options:convert.bzl", "convert")
load("//src/main/starlark/core/options:derive.bzl", "derive")

def _test_map_value_to_flag(value):
    return ["-flag={}".format(value)]

def _test_map_value_to_flag_repeated(values):
    return ["-flag-repeated={}".format(v) for v in values]

_TEST_OPTS = {
    "map_value_to_flag_repeated_test": struct(
        value_to_flag = None,
        map_value_to_flag = _test_map_value_to_flag_repeated,
    ),
    "map_value_to_flag_test": struct(
        value_to_flag = None,
        map_value_to_flag = _test_map_value_to_flag,
    ),
    "value_to_flag_derive_test": struct(value_to_flag = {
        derive.info: derive.repeated_values_for("-bar:"),
    }),
    "value_to_flag_test": struct(value_to_flag = {
        "options1": ["-foo-options"],
    }),
}

def _convert_options_to_flags_empty_options_test(ctx):
    """Asserts that the converters return None when the attr_provider doesn't exist.

    Args:
        ctx: unittest rule context used to run the assertions.

    Returns:
        unittest analysis result.
    """
    env = unittest.begin(ctx)

    asserts.true(env, not convert.kotlinc_options_to_flags({}, None))
    asserts.true(env, not convert.javac_options_to_flags({}, None))

    return unittest.end(env)

convert_options_to_flags_empty_options_test = unittest.make(
    _convert_options_to_flags_empty_options_test,
)

def _convert_options_to_flags_test(ctx):
    """Tests the _to_flags mapper paths
    """
    env = unittest.begin(ctx)

    attrs = struct(
        value_to_flag_test = "options1",
        value_to_flag_derive_test = ["1", "2", "3"],
        map_value_to_flag_test = "1",
        map_value_to_flag_repeated_test = ["1", "2", "3"],
    )
    asserts.equals(
        env,
        expected = convert.kotlinc_options_to_flags(_TEST_OPTS, attrs),
        actual = [
            "-flag-repeated=1",
            "-flag-repeated=2",
            "-flag-repeated=3",
            "-flag=1",
            "-bar:1",
            "-bar:2",
            "-bar:3",
            "-foo-options",
        ],
    )

    return unittest.end(env)

convert_options_to_flags_test = unittest.make(
    _convert_options_to_flags_test,
)

def convert_test_suite(name):
    unittest.suite(
        name,
        convert_options_to_flags_empty_options_test,
        convert_options_to_flags_test,
    )
