# Copyright 2024 The Bazel Authors. All rights reserved.
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

"""Integration tests for Kover toolchain configuration."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_java//java:java_library.bzl", "java_library")
load("//kotlin:jvm.bzl", "kt_jvm_test")

# Test that verifies Kover can be disabled (default behavior)
def _kover_disabled_test_impl(ctx):
    env = analysistest.begin(ctx)

    # When Kover is disabled, the test should not have Kover-specific outputs
    actions = analysistest.target_actions(env)

    # Verify no Kover-related actions are present
    kover_action_count = 0
    for action in actions:
        if "kover" in action.mnemonic.lower():
            kover_action_count += 1
        else:
            for output in action.outputs.to_list():
                if "kover" in str(output):
                    kover_action_count += 1
                    break

    # With Kover disabled (default), there should be no Kover-specific actions
    # This test validates the default behavior
    asserts.equals(
        env,
        expected = 0,
        actual = kover_action_count,
        msg = "Expected no Kover actions when Kover is disabled (default)",
    )

    return analysistest.end(env)

kover_disabled_test = analysistest.make(_kover_disabled_test_impl)

def _test_kover_disabled():
    """Test that Kover is disabled by default."""
    java_library(
        name = "kover_disabled_test_dep",
        srcs = [],
        tags = ["manual"],
    )

    kt_jvm_test(
        name = "kover_disabled_test_subject",
        srcs = ["//src/test/starlark/ksp:TestModel.kt"],
        test_class = "TestModel",
        deps = [":kover_disabled_test_dep"],
        tags = ["manual"],
    )

    kover_disabled_test(
        name = "kover_disabled_test",
        target_under_test = ":kover_disabled_test_subject",
    )

def kover_toolchain_test_suite(name):
    """Create the test suite for Kover toolchain tests.

    Args:
        name: The name of the test suite.
    """
    _test_kover_disabled()

    native.test_suite(
        name = name,
        tests = [
            ":kover_disabled_test",
        ],
    )
