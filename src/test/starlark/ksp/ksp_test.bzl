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

"""Tests for KSP2 integration."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("//src/main/starlark/core/plugin:providers.bzl", "KspPluginInfo")

def _ksp_outputs_test_impl(ctx):
    """Verify KSP2 action produces expected outputs."""
    env = analysistest.begin(ctx)

    target = analysistest.target_under_test(env)

    # Check that the target has JavaInfo provider
    asserts.true(
        env,
        JavaInfo in target,
        "Target should provide JavaInfo",
    )

    # Check that compilation outputs exist
    java_info = target[JavaInfo]
    asserts.true(
        env,
        len(java_info.runtime_output_jars) > 0,
        "Target should have runtime output jars",
    )

    return analysistest.end(env)

ksp_outputs_test = analysistest.make(_ksp_outputs_test_impl)

def _ksp_action_test_impl(ctx):
    """Verify KSP2 action is created with correct mnemonic."""
    env = analysistest.begin(ctx)

    # Find the KotlinKsp2 action
    actions = analysistest.target_actions(env)
    ksp2_actions = [a for a in actions if a.mnemonic == "KotlinKsp2"]

    asserts.true(
        env,
        len(ksp2_actions) > 0,
        "Should have at least one KotlinKsp2 action",
    )

    # Verify the KSP2 action outputs JAR files (not tree artifacts)
    if ksp2_actions:
        ksp2_action = ksp2_actions[0]
        outputs = ksp2_action.outputs.to_list()

        # All outputs should be files (not directories)
        for output in outputs:
            asserts.true(
                env,
                output.path.endswith(".jar"),
                "KSP2 output should be a JAR file: %s" % output.path,
            )

    return analysistest.end(env)

ksp_action_test = analysistest.make(_ksp_action_test_impl)

def _ksp_single_action_test_impl(ctx):
    """Verify KSP2 uses a single action (no tree artifacts or staging actions)."""
    env = analysistest.begin(ctx)

    actions = analysistest.target_actions(env)

    # Count KSP-related actions
    ksp_actions = [a for a in actions if "Ksp" in a.mnemonic or "ksp" in a.mnemonic.lower()]

    # Should only have one KSP2 action
    asserts.equals(
        env,
        1,
        len(ksp_actions),
        "Should have exactly one KSP action, got: %s" % [a.mnemonic for a in ksp_actions],
    )

    # Verify no staging actions
    staging_actions = [a for a in actions if "Stage" in a.mnemonic or "Unpack" in a.mnemonic]
    asserts.equals(
        env,
        0,
        len(staging_actions),
        "Should have no staging actions, got: %s" % [a.mnemonic for a in staging_actions],
    )

    return analysistest.end(env)

ksp_single_action_test = analysistest.make(_ksp_single_action_test_impl)

def _ksp_plugin_options_provider_test_impl(ctx):
    """Verify kt_ksp_plugin with options carries them in KspPluginInfo."""
    env = analysistest.begin(ctx)

    target = analysistest.target_under_test(env)

    asserts.true(
        env,
        KspPluginInfo in target,
        "kt_ksp_plugin should provide KspPluginInfo",
    )

    ksp_info = target[KspPluginInfo]
    asserts.true(
        env,
        len(ksp_info.options) == 2,
        "KspPluginInfo should have 2 options, got %d" % len(ksp_info.options),
    )
    asserts.equals(env, "test_value", ksp_info.options["test_key"])
    asserts.equals(env, "another_value", ksp_info.options["another_key"])

    return analysistest.end(env)

ksp_plugin_options_provider_test = analysistest.make(_ksp_plugin_options_provider_test_impl)

def _ksp_plugin_empty_options_provider_test_impl(ctx):
    """Verify kt_ksp_plugin without options has empty options dict in KspPluginInfo."""
    env = analysistest.begin(ctx)

    target = analysistest.target_under_test(env)

    asserts.true(
        env,
        KspPluginInfo in target,
        "kt_ksp_plugin should provide KspPluginInfo",
    )

    ksp_info = target[KspPluginInfo]
    asserts.equals(env, 0, len(ksp_info.options))

    return analysistest.end(env)

ksp_plugin_empty_options_provider_test = analysistest.make(_ksp_plugin_empty_options_provider_test_impl)

def _ksp_options_action_test_impl(ctx):
    """Verify KSP2 action receives --ksp_options in its arguments."""
    env = analysistest.begin(ctx)

    actions = analysistest.target_actions(env)
    ksp2_actions = [a for a in actions if a.mnemonic == "KotlinKsp2"]

    asserts.equals(env, 1, len(ksp2_actions), "Should have exactly one KotlinKsp2 action")

    argv = ksp2_actions[0].argv

    ksp_option_args = [arg for arg in argv if arg.startswith("test_key=") or arg.startswith("another_key=")]
    asserts.equals(
        env,
        2,
        len(ksp_option_args),
        "KotlinKsp2 action should have 2 --ksp_options values in argv, got: %s" % ksp_option_args,
    )

    ksp_flag_args = [arg for arg in argv if arg == "--ksp_options"]
    asserts.equals(
        env,
        2,
        len(ksp_flag_args),
        "KotlinKsp2 action should have 2 --ksp_options flags in argv",
    )

    return analysistest.end(env)

ksp_options_action_test = analysistest.make(_ksp_options_action_test_impl)

def _ksp_conflicting_options_test_impl(ctx):
    """Verify that conflicting KSP option keys across plugins fail analysis."""
    env = analysistest.begin(ctx)
    return analysistest.end(env)

ksp_conflicting_options_test = analysistest.make(
    _ksp_conflicting_options_test_impl,
    expect_failure = True,
)

def _find_javac_action(actions):
    """Find the java_common.compile action by its -java.jar output."""
    for a in actions:
        for o in a.outputs.to_list():
            if o.path.endswith("-java.jar"):
                return a
    return None

def _has_ksp_srcjar_input(action):
    """Check whether any input to an action is a KSP-generated srcjar."""
    for i in action.inputs.to_list():
        if i.path.endswith("-ksp-gensrc.jar"):
            return True
    return False

def _ksp_javac_excludes_srcjars_when_not_generating_java_test_impl(ctx):
    """When generates_java=False and Java sources exist, javac must not receive KSP srcjars."""
    env = analysistest.begin(ctx)

    actions = analysistest.target_actions(env)
    javac_action = _find_javac_action(actions)

    asserts.true(
        env,
        javac_action != None,
        "Javac action should exist because target has Java sources",
    )

    if javac_action:
        asserts.false(
            env,
            _has_ksp_srcjar_input(javac_action),
            "Javac action should NOT have KSP srcjars when generates_java=False",
        )

    return analysistest.end(env)

ksp_javac_excludes_srcjars_test = analysistest.make(
    _ksp_javac_excludes_srcjars_when_not_generating_java_test_impl,
)

def _ksp_javac_includes_srcjars_when_generating_java_test_impl(ctx):
    """When generates_java=True, javac must receive KSP srcjars."""
    env = analysistest.begin(ctx)

    actions = analysistest.target_actions(env)
    javac_action = _find_javac_action(actions)

    asserts.true(
        env,
        javac_action != None,
        "Javac action should exist because KSP generates Java",
    )

    if javac_action:
        asserts.true(
            env,
            _has_ksp_srcjar_input(javac_action),
            "Javac action should have KSP srcjars when generates_java=True",
        )

    return analysistest.end(env)

ksp_javac_includes_srcjars_test = analysistest.make(
    _ksp_javac_includes_srcjars_when_generating_java_test_impl,
)

def ksp_test_suite(name):
    """Create test suite for KSP2 integration tests.

    Args:
        name: Name of the test suite
    """

    # We can't create actual kt_jvm_library targets in .bzl files,
    # so the tests are defined in BUILD.bazel and this just creates the suite
    native.test_suite(
        name = name,
        tests = [
            ":ksp_outputs_test",
            ":ksp_action_test",
            ":ksp_single_action_test",
            ":ksp_plugin_options_provider_test",
            ":ksp_plugin_empty_options_provider_test",
            ":ksp_options_action_test",
            ":ksp_javac_excludes_srcjars_test",
            ":ksp_javac_includes_srcjars_test",
        ],
    )
