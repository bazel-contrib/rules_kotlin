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

load("@bazel_skylib//lib:unittest.bzl", "analysistest")
load("@rules_java//java:defs.bzl", "java_plugin")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("@rules_testing//lib:truth.bzl", "matching")
load("@rules_testing//lib:util.bzl", "TestingAspectInfo")
load("//kotlin:core.bzl", "kt_ksp_plugin")
load("//kotlin:jvm.bzl", "kt_jvm_library")

# buildifier: disable=bzl-visibility
load("//kotlin/internal:defs.bzl", "KtJvmInfo")
load("//src/main/starlark/core/plugin:providers.bzl", "KspPluginInfo")
load("//src/test/starlark:case.bzl", "suite")

def _moshi_plugin(test, **kwargs):
    return test.have(
        kt_ksp_plugin,
        name = "moshi",
        processor_class = "com.squareup.moshi.kotlin.codegen.ksp.JsonClassSymbolProcessorProvider",
        deps = [
            "@kotlin_rules_maven_test//:com_squareup_moshi_moshi",
            "@kotlin_rules_maven_test//:com_squareup_moshi_moshi_kotlin",
            "@kotlin_rules_maven_test//:com_squareup_moshi_moshi_kotlin_codegen",
        ],
        **kwargs
    )

def _autovalue_plugin(test):
    return test.have(
        java_plugin,
        name = "autovalue",
        generates_api = 1,
        processor_class = "com.google.auto.value.processor.AutoValueProcessor",
        deps = ["@kotlin_rules_maven//:com_google_auto_value_auto_value"],
    )

def _ksp_lib(test, plugins):
    return test.got(
        kt_jvm_library,
        name = "got",
        srcs = [test.artifact("TestModel.kt")],
        plugins = plugins,
        deps = [
            "@kotlin_rules_maven_test//:com_squareup_moshi_moshi",
            "@kotlin_rules_maven_test//:com_squareup_moshi_moshi_kotlin",
        ],
    )

def _ksp_outputs(env, got):
    """Verify KSP2 action produces expected outputs."""
    got_target = env.expect.that_target(got)
    got_target.has_provider(JavaInfo)

    java_info = got[JavaInfo]
    env.expect.that_int(len(java_info.runtime_output_jars)).is_greater_than(0)

    # IDE annotation-processing metadata must keep referring to the Kotlin output, including when
    # KSP/KAPT also causes a Java compilation.
    kotlin_info = got[KtJvmInfo]
    processing = kotlin_info.annotation_processing
    env.expect.that_bool(processing.enabled).equals(True)
    env.expect.that_str(processing.class_jar.basename).equals(got.label.name + "-kt.jar")
    env.expect.that_str(processing.source_jar.basename).equals(got.label.name + "-ksp-gensrc.jar")
    if java_info.outputs.jdeps != kotlin_info.outputs.jdeps:
        env.fail("java_info.outputs.jdeps must equal kotlin_info.outputs.jdeps")

def _test_outputs(test):
    moshi = _moshi_plugin(test)
    got = _ksp_lib(test, [moshi])
    test.claim(got = got, what = _ksp_outputs, wants = {})

def _test_kapt_outputs(test):
    autovalue = _autovalue_plugin(test)
    moshi = _moshi_plugin(test)
    got = _ksp_lib(test, [autovalue, moshi])
    test.claim(got = got, what = _ksp_outputs, wants = {})

def _test_mixed_outputs(test):
    moshi_generates_java = _moshi_plugin(test, generates_java = True)
    got = test.got(
        kt_jvm_library,
        name = "got",
        srcs = [test.artifact("TestHelper.java"), test.artifact("TestModel.kt")],
        plugins = [moshi_generates_java],
        deps = [
            "@kotlin_rules_maven_test//:com_squareup_moshi_moshi",
            "@kotlin_rules_maven_test//:com_squareup_moshi_moshi_kotlin",
        ],
    )
    test.claim(got = got, what = _ksp_outputs, wants = {})

def _ksp_action(env, got):
    """Verify KSP2 action is created with correct mnemonic and JAR (not tree-artifact) outputs."""
    ksp2 = env.expect.that_target(got).action_named("KotlinKsp2")
    for output in ksp2.actual.outputs.to_list():
        if not output.path.endswith(".jar"):
            env.fail("KSP2 output should be a JAR file: %s" % output.path)

def _test_action(test):
    moshi = _moshi_plugin(test)
    got = _ksp_lib(test, [moshi])
    test.claim(got = got, what = _ksp_action, wants = {})

def _ksp_producer_consumer_edges(env, got):
    """Verify the KotlinKsp2 action's producer->consumer EDGES (not mere artifact existence):
    exactly one KotlinKsp2 action runs, and its generated src/class jars actually reach Kotlin
    compile and the runtime jar fold by basename, mirroring the KspProcessor pipeline-stage
    contract asserted at the pipeline level by pipeline/ksp_stage_test.bzl."""
    got_target = env.expect.that_target(got)
    ksp2 = got_target.action_named("KotlinKsp2")

    outputs = ksp2.actual.outputs.to_list()
    gensrc_matches = [o for o in outputs if o.path.endswith("-ksp-gensrc.jar")]
    class_matches = [o for o in outputs if o.path.endswith("-ksp-genclasses.jar")]
    if len(gensrc_matches) != 1 or len(class_matches) != 1:
        env.fail(
            "KotlinKsp2 should declare exactly one -ksp-gensrc.jar and one -ksp-genclasses.jar " +
            "output, found gensrc=%d genclasses=%d" % (len(gensrc_matches), len(class_matches)),
        )
        return

    got_target.action_named("KotlinCompile").inputs().contains_predicate(
        matching.file_basename_equals(gensrc_matches[0].basename),
    )
    got_target.action_named("KotlinFoldJarsRuntime").inputs().contains_predicate(
        matching.file_basename_equals(class_matches[0].basename),
    )

def _test_producer_consumer_edges(test):
    moshi = _moshi_plugin(test)
    got = _ksp_lib(test, [moshi])
    test.claim(got = got, what = _ksp_producer_consumer_edges, wants = {})

def _ksp_single_action(env, got):
    """Verify KSP2 uses a single action (no tree artifacts or staging actions)."""
    actions = got[TestingAspectInfo].actions
    ksp_actions = [a for a in actions if "Ksp" in a.mnemonic or "ksp" in a.mnemonic.lower()]
    if len(ksp_actions) != 1:
        env.fail("Should have exactly one KSP action, got: %s" % [a.mnemonic for a in ksp_actions])

    staging_actions = [a for a in actions if "Stage" in a.mnemonic or "Unpack" in a.mnemonic]
    if staging_actions:
        env.fail("Should have no staging actions, got: %s" % [a.mnemonic for a in staging_actions])

def _test_single_action(test):
    moshi = _moshi_plugin(test)
    got = _ksp_lib(test, [moshi])
    test.claim(got = got, what = _ksp_single_action, wants = {})

def _ksp_plugin_options_provider(env, got):
    """Verify kt_ksp_plugin with options carries them in KspPluginInfo."""
    env.expect.that_target(got).has_provider(KspPluginInfo)
    env.expect.that_dict(got[KspPluginInfo].options).contains_exactly({
        "another_key": "another_value",
        "test_key": "test_value",
    })

def _test_plugin_options_provider(test):
    plugin = _moshi_plugin(test, options = {"another_key": "another_value", "test_key": "test_value"})
    test.claim(got = plugin, what = _ksp_plugin_options_provider, wants = {})

def _ksp_plugin_empty_options_provider(env, got):
    """Verify kt_ksp_plugin without options has empty options dict in KspPluginInfo."""
    env.expect.that_target(got).has_provider(KspPluginInfo)
    env.expect.that_dict(got[KspPluginInfo].options).contains_exactly({})

def _test_plugin_empty_options_provider(test):
    plugin = _moshi_plugin(test)
    test.claim(got = plugin, what = _ksp_plugin_empty_options_provider, wants = {})

def _ksp_options_action(env, got):
    """Verify KSP2 action receives --ksp_options in its arguments."""
    ksp2 = env.expect.that_target(got).action_named("KotlinKsp2")
    argv = ksp2.actual.argv

    option_args = [a for a in argv if a.startswith("test_key=") or a.startswith("another_key=")]
    if len(option_args) != 2:
        env.fail("KotlinKsp2 action should have 2 --ksp_options values in argv, got: %s" % option_args)

    flag_args = [a for a in argv if a == "--ksp_options"]
    if len(flag_args) != 2:
        env.fail("KotlinKsp2 action should have 2 --ksp_options flags in argv")

def _test_options_action(test):
    moshi_with_options = _moshi_plugin(test, options = {"another_key": "another_value", "test_key": "test_value"})
    got = _ksp_lib(test, [moshi_with_options])
    test.claim(got = got, what = _ksp_options_action, wants = {})

def _ksp_javac_excludes_srcjars(env, got):
    """When generates_java=False and Java sources exist, javac must not receive KSP srcjars."""
    env.expect.that_target(got).action_named("Javac").inputs().not_contains_predicate(
        matching.file_basename_contains("-ksp-gensrc.jar"),
    )

def _test_javac_excludes_srcjars(test):
    # Mixed Java+Kotlin with KSP (generates_java=False) -- KSP srcjars must NOT go to javac.
    moshi = _moshi_plugin(test)
    got = test.got(
        kt_jvm_library,
        name = "got",
        srcs = [test.artifact("TestHelper.java"), test.artifact("TestModel.kt")],
        plugins = [moshi],
        deps = [
            "@kotlin_rules_maven_test//:com_squareup_moshi_moshi",
            "@kotlin_rules_maven_test//:com_squareup_moshi_moshi_kotlin",
        ],
    )
    test.claim(got = got, what = _ksp_javac_excludes_srcjars, wants = {})

def _ksp_javac_includes_srcjars(env, got):
    """When generates_java=True, javac must receive KSP srcjars."""
    env.expect.that_target(got).action_named("Javac").inputs().contains_predicate(
        matching.file_basename_contains("-ksp-gensrc.jar"),
    )

def _test_javac_includes_srcjars(test):
    # Mixed Java+Kotlin with KSP (generates_java=True) -- KSP srcjars must go to javac.
    moshi_generates_java = _moshi_plugin(test, generates_java = True)
    got = test.got(
        kt_jvm_library,
        name = "got",
        srcs = [test.artifact("TestHelper.java"), test.artifact("TestModel.kt")],
        plugins = [moshi_generates_java],
        deps = [
            "@kotlin_rules_maven_test//:com_squareup_moshi_moshi",
            "@kotlin_rules_maven_test//:com_squareup_moshi_moshi_kotlin",
        ],
    )
    test.claim(got = got, what = _ksp_javac_includes_srcjars, wants = {})

def _ksp_processor_classpath_isolation(env, got):
    """Verify KSP2 processor classpath excludes KAPT processor JARs."""
    ksp2 = env.expect.that_target(got).action_named("KotlinKsp2")
    argv = ksp2.actual.argv

    # Collect all --processor_classpath values from argv.
    processor_classpath_entries = []
    collecting = False
    for arg in argv:
        if arg == "--processor_classpath":
            collecting = True
        elif collecting and arg.startswith("--"):
            collecting = False
        elif collecting:
            processor_classpath_entries.append(arg)

    # KAPT processor JARs (autovalue) must NOT be on KSP2 processor classpath.
    kapt_jars_on_ksp = [e for e in processor_classpath_entries if "auto_value" in e or "auto-value" in e]
    if kapt_jars_on_ksp:
        env.fail("KAPT processor JARs should not leak onto KSP2 --processor_classpath, found: %s" % kapt_jars_on_ksp)

    # KSP processor JARs (moshi) SHOULD be present.
    ksp_jars = [e for e in processor_classpath_entries if "moshi" in e]
    if not ksp_jars:
        env.fail("KSP processor JARs (moshi) should be on KSP2 --processor_classpath")

def _test_processor_classpath_isolation(test):
    # Target with both KAPT (autovalue) and KSP (moshi) plugins -- verifies that KAPT processor
    # JARs do not leak onto the KSP2 processor classpath.
    autovalue = _autovalue_plugin(test)
    moshi = _moshi_plugin(test)
    got = test.got(
        kt_jvm_library,
        name = "got",
        srcs = [test.artifact("TestModel.kt")],
        plugins = [autovalue, moshi],
        deps = [
            "@kotlin_rules_maven//:com_google_auto_value_auto_value_annotations",
            "@kotlin_rules_maven_test//:com_squareup_moshi_moshi",
            "@kotlin_rules_maven_test//:com_squareup_moshi_moshi_kotlin",
        ],
    )
    test.claim(got = got, what = _ksp_processor_classpath_isolation, wants = {})

def test_suite(name):
    """Wires the KSP2 integration test matrix onto //src/test/starlark:case.bzl.

    `ksp_conflicting_options_test` (expect_failure=True, whole-target-analysis-failure) stays on
    @bazel_skylib//lib:unittest.bzl: case.bzl's case()/claim() API has no equivalent to
    analysistest.make(..., expect_failure=True), and partial migration -- not silently weakening
    that assertion -- is the explicit fallback for facets the case.bzl API can't express. See
    BUILD.bazel for its wiring and fixtures.

    Args:
      name: the (inert, see //src/test/starlark:case.bzl's `suite`) aggregate test_suite name.
    """
    suite(
        name,
        test_outputs = _test_outputs,
        test_kapt_outputs = _test_kapt_outputs,
        test_mixed_outputs = _test_mixed_outputs,
        test_action = _test_action,
        test_producer_consumer_edges = _test_producer_consumer_edges,
        test_single_action = _test_single_action,
        test_plugin_options_provider = _test_plugin_options_provider,
        test_plugin_empty_options_provider = _test_plugin_empty_options_provider,
        test_options_action = _test_options_action,
        test_javac_excludes_srcjars = _test_javac_excludes_srcjars,
        test_javac_includes_srcjars = _test_javac_includes_srcjars,
        test_processor_classpath_isolation = _test_processor_classpath_isolation,
    )

def _ksp_conflicting_options_test_impl(ctx):
    """Verify that conflicting KSP option keys across plugins fail analysis."""
    env = analysistest.begin(ctx)
    return analysistest.end(env)

ksp_conflicting_options_test = analysistest.make(
    _ksp_conflicting_options_test_impl,
    expect_failure = True,
)
