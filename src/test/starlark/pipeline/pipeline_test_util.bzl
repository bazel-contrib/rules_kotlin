"""Shared helpers for kapt_stage_test.bzl/ksp_stage_test.bzl: action-graph assertions, the
replaceable-stage-rule factory, and the no-ap/no-eligible-srcs/export-only gate-unmet triad."""

load("@rules_java//java:defs.bzl", "JavaInfo")
load("@rules_testing//lib:truth.bzl", "matching")
load("@rules_testing//lib:util.bzl", "TestingAspectInfo")
load("//kotlin:jvm.bzl", "kt_jvm_library")
load("//kotlin/internal:defs.bzl", _KtJvmInfo = "KtJvmInfo")
load("//kotlin/internal/jvm:attrs.bzl", _attrs = "attrs")
load(
    "//kotlin/internal/jvm:common.bzl",
    _make_providers = "make_providers",
)
load("//kotlin/internal/jvm:kt_jvm_library.bzl", LIBRARY_PROCESSORS = "PROCESSORS")
load(
    "//kotlin/internal/jvm:rule.bzl",
    _COMMON_OUTPUTS = "COMMON_OUTPUTS",
    _COMMON_TOOLCHAINS = "COMMON_TOOLCHAINS",
)
load(
    "//src/main/starlark/core/pipeline:pipeline.bzl",
    _processing_pipeline = "processing_pipeline",
)

def actions_named(target, mnemonic):
    return [a for a in target[TestingAspectInfo].actions if a.mnemonic == mnemonic]

def assert_no_action_named(env, got, mnemonic):
    found = actions_named(got, mnemonic)
    if found:
        env.fail("expected no %s action, found %d" % (mnemonic, len(found)))

def assert_gensrc_reaches_kotlin_compile_and_sources_jar(env, got_target, gensrc_jar_basename, sources_jar_short_path):
    """Asserts `gensrc_jar` reaches both KotlinCompile and source-jar packing (shared KAPT/KSP edge)."""
    got_target.action_named("KotlinCompile").inputs().contains_predicate(
        matching.file_basename_equals(gensrc_jar_basename),
    )
    got_target.action_generating(sources_jar_short_path).inputs().contains_predicate(
        matching.file_basename_equals(gensrc_jar_basename),
    )

def assert_class_reaches_runtime_fold(got_target, class_jar_basename):
    """Asserts `class_jar` reaches the KotlinFoldJarsRuntime fold (shared KAPT/KSP edge)."""
    got_target.action_named("KotlinFoldJarsRuntime").inputs().contains_predicate(
        matching.file_basename_equals(class_jar_basename),
    )

def replaceable_finalize(context):
    """Test-only finalize assembling kt_jvm_library providers from the accumulated processor results."""
    return _make_providers(
        context.ctx,
        providers = context.outputs["JvmCompileProcessor"],
        runfiles_targets = context.outputs["DepsProcessor"],
    )

def make_replaceable_stage_rule(processor_name, custom_processor, doc):
    """Builds a test-only rule proving `processor_name` is independently replaceable via `processing_pipeline.replace`."""
    pipeline = _processing_pipeline.make_processing_pipeline(
        processors = _processing_pipeline.replace(
            LIBRARY_PROCESSORS,
            **{processor_name: custom_processor}
        ),
        finalize = replaceable_finalize,
    )

    def _impl(ctx):
        return _processing_pipeline.run(ctx = ctx, java_package = None, pipeline = pipeline)

    return rule(
        doc = doc,
        attrs = _attrs.lib_common_attr,
        outputs = _COMMON_OUTPUTS,
        toolchains = _COMMON_TOOLCHAINS,
        fragments = ["java"],
        host_fragments = ["java"],
        implementation = _impl,
        provides = [JavaInfo, _KtJvmInfo],
    )

def gate_unmet_triad(stage_mnemonic, make_eligible_srcs_plugin):
    """Returns the (no_processors, no_eligible_srcs, export_only) gate-unmet test triad that must all register no `stage_mnemonic` action."""

    def _no_action(env, got):
        assert_no_action_named(env, got, stage_mnemonic)

    def _test_no_processors(test):
        got = test.got(
            kt_jvm_library,
            name = "got",
            srcs = [test.artifact("Source.kt")],
        )
        test.claim(got = got, what = _no_action, wants = {})

    def _test_no_eligible_srcs(test):
        plugin = make_eligible_srcs_plugin(test)
        got = test.got(
            kt_jvm_library,
            name = "got",
            srcs = [test.artifact("Source.java")],
            plugins = [plugin],
        )
        test.claim(got = got, what = _no_action, wants = {})

    def _test_export_only(test):
        got = test.got(
            kt_jvm_library,
            name = "got",
            exports = ["//src/test/data/jvm/kapt:library_exporting_autovalue_and_junit"],
        )
        test.claim(got = got, what = _no_action, wants = {})

    return _test_no_processors, _test_no_eligible_srcs, _test_export_only
