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

"""Tests for Kover code coverage integration."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//kotlin/internal/jvm:kover.bzl", "get_kover_jvm_flags")

def _get_kover_jvm_flags_test_impl(ctx):
    """Test that get_kover_jvm_flags generates correct JVM agent flags including bootclasspath."""
    env = unittest.begin(ctx)

    # Create mock file objects with short_path attribute
    mock_agent_file = struct(short_path = "external/kover/kover-jvm-agent.jar")
    mock_args_file = struct(short_path = "bazel-out/k8-fastbuild/bin/test-kover.args.txt")

    result = get_kover_jvm_flags([mock_agent_file], mock_args_file)

    # Expected format includes both -Xbootclasspath/a and -javaagent flags
    expected = "-Xbootclasspath/a:external/kover/kover-jvm-agent.jar -javaagent:external/kover/kover-jvm-agent.jar=file:bazel-out/k8-fastbuild/bin/test-kover.args.txt"
    asserts.equals(env, expected, result)

    return unittest.end(env)

get_kover_jvm_flags_test = unittest.make(_get_kover_jvm_flags_test_impl)

def _kover_jvm_flags_format_test_impl(ctx):
    """Test JVM flags format with different path patterns."""
    env = unittest.begin(ctx)

    # Test with workspace-relative path
    mock_agent = struct(short_path = "maven/kover-agent-1.0.jar")
    mock_args = struct(short_path = "pkg/test.args")

    result = get_kover_jvm_flags([mock_agent], mock_args)

    # Verify the format includes both bootclasspath and javaagent flags
    asserts.true(env, "-Xbootclasspath/a:" in result)
    asserts.true(env, "-javaagent:" in result)
    asserts.true(env, "=file:" in result)
    asserts.true(env, result.endswith("pkg/test.args"))

    return unittest.end(env)

kover_jvm_flags_format_test = unittest.make(_kover_jvm_flags_format_test_impl)

def kover_test_suite(name):
    """Create the test suite for Kover integration tests.

    Args:
        name: The name of the test suite.
    """
    unittest.suite(
        name,
        get_kover_jvm_flags_test,
        kover_jvm_flags_format_test,
    )
