"""it_kapt_stage_composition_and_replacement -- integration test for us-kapt-stage.

Locks the CompilePreparationProcessor -> KaptProcessor -> JvmCompileProcessor pipeline contract
across kt_jvm_library/kt_jvm_binary/kt_jvm_test: KaptProcessor runs exactly once and its outputs
reach their documented consumers; it composes with `processing_pipeline.replace`; and it stays
gated off (stable-shape empty result, no KotlinKapt action) when inactive."""

load("@rules_java//java:defs.bzl", "java_plugin")
load("@rules_testing//lib:truth.bzl", "matching")
load("//kotlin:jvm.bzl", "kt_jvm_binary", "kt_jvm_library", "kt_jvm_test")
load(
    "//src/main/starlark/core/pipeline:pipeline.bzl",
    _ProviderInfo = "ProviderInfo",
)
load("//src/test/starlark:case.bzl", "Want", "suite")
load(
    ":pipeline_test_util.bzl",
    "assert_class_reaches_runtime_fold",
    "assert_gensrc_reaches_kotlin_compile_and_sources_jar",
    "assert_no_action_named",
    "gate_unmet_triad",
    "make_replaceable_stage_rule",
)

# (i) across library/binary/test KAPT fixtures: KaptProcessor's outputs reach their documented
# consumers once it is promoted to its own replaceable pipeline stage.
def _kapt_stage_reaches_consumers(env, got):
    got_target = env.expect.that_target(got)
    got_target.action_named("KotlinKapt")

    assert_gensrc_reaches_kotlin_compile_and_sources_jar(
        env,
        got_target,
        env.ctx.file.kapt_gensrc_jar.basename,
        env.ctx.file.sources_jar.short_path,
    )
    assert_class_reaches_runtime_fold(got_target, env.ctx.file.kapt_class_jar.basename)

    # KAPT-unique: the gensrc jar also reaches javac, alongside the neverlink stub.
    javac = got_target.action_named("Javac")
    javac.inputs().contains_predicate(
        matching.file_basename_equals(env.ctx.file.kapt_gensrc_jar.basename),
    )
    javac.inputs().contains_predicate(
        matching.file_basename_equals(env.ctx.file.kapt_stub_jar.basename),
    )

def _kapt_stage_consumer_wants(got):
    return {
        "kapt_class_jar": Want(attr = attr.label(allow_single_file = True), value = got + "-kapt-generated-class.jar"),
        "kapt_gensrc_jar": Want(attr = attr.label(allow_single_file = True), value = got + "-kapt-gensrc.jar"),
        "kapt_stub_jar": Want(attr = attr.label(allow_single_file = True), value = got + "-kapt-generated-stub.jar"),
        "sources_jar": Want(attr = attr.label(allow_single_file = True), value = got + "-sources.jar"),
    }

def _kapt_stage_autovalue(test):
    return test.have(
        java_plugin,
        name = "autovalue",
        generates_api = 1,
        processor_class = "com.google.auto.value.processor.AutoValueProcessor",
        deps = ["@kotlin_rules_maven//:com_google_auto_value_auto_value"],
    )

def _test_kapt_stage_library(test):
    autovalue = _kapt_stage_autovalue(test)
    got = test.got(
        kt_jvm_library,
        name = "got",
        srcs = [test.artifact("Source.kt")],
        plugins = [autovalue],
    )
    test.claim(got = got, what = _kapt_stage_reaches_consumers, wants = _kapt_stage_consumer_wants(got))

def _test_kapt_stage_binary(test):
    autovalue = _kapt_stage_autovalue(test)
    got = test.got(
        kt_jvm_binary,
        name = "got",
        srcs = [test.artifact("Source.kt")],
        plugins = [autovalue],
        main_class = "Foo",
    )
    test.claim(got = got, what = _kapt_stage_reaches_consumers, wants = _kapt_stage_consumer_wants(got))

def _test_kapt_stage_junit_test(test):
    autovalue = _kapt_stage_autovalue(test)
    got = test.got(
        kt_jvm_test,
        name = "got",
        srcs = [test.artifact("Source.kt")],
        plugins = [autovalue],
        test_class = "Foo",
        deps = ["@kotlin_rules_maven_test//:junit_junit"],
    )
    test.claim(got = got, what = _kapt_stage_reaches_consumers, wants = _kapt_stage_consumer_wants(got))

# (ii) processing_pipeline.replace(PROCESSORS, KaptProcessor=<custom>) composed with the REAL
# JvmCompileProcessor engine.
def _custom_kapt_stage(context):
    """Test-only KaptProcessor replacement proving `processing_pipeline.replace` composes with the real JvmCompileProcessor engine."""
    ctx = context.ctx
    custom_class_jar = ctx.actions.declare_file(ctx.label.name + "-custom-kapt-replacement.jar")
    ctx.actions.write(custom_class_jar, "custom-kapt-stage-replacement")
    return _ProviderInfo(
        name = "KaptProcessor",
        value = struct(
            ap_generated_src_jar = None,
            kapt_generated_stub_jar = None,
            kapt_generated_class_jar = custom_class_jar,
        ),
        runfiles = None,
    )

replaceable_kapt_library = make_replaceable_stage_rule(
    processor_name = "KaptProcessor",
    custom_processor = _custom_kapt_stage,
    doc = """Test-only rule proving `KaptProcessor` is independently replaceable via
    `processing_pipeline.replace` against the real kt_jvm_library PROCESSORS map and
    JvmCompileProcessor engine.""",
)

def _kapt_stage_replacement(env, got):
    # The default KAPT action must NOT be registered -- the replacement pre-empts it entirely.
    assert_no_action_named(env, got, "KotlinKapt")

    env.expect.that_target(got).action_named("KotlinFoldJarsRuntime").inputs().contains_predicate(
        matching.file_basename_equals(env.ctx.file.custom_class_jar.basename),
    )

def _test_kapt_stage_replacement(test):
    autovalue = _kapt_stage_autovalue(test)
    got = test.got(
        replaceable_kapt_library,
        name = "got",
        srcs = [test.artifact("Source.kt")],
        plugins = [autovalue],
    )
    test.claim(
        got = got,
        what = _kapt_stage_replacement,
        wants = {
            "custom_class_jar": Want(attr = attr.label(allow_single_file = True), value = got + "-custom-kapt-replacement.jar"),
        },
    )

# (iii) gate-unmet / inactive-prep cases: no annotation processors, no eligible (Kotlin) sources,
# and export-only must all register NO KotlinKapt action.
_test_kapt_stage_no_ap, _test_kapt_stage_no_eligible_srcs, _test_kapt_stage_export_only = gate_unmet_triad(
    "KotlinKapt",
    _kapt_stage_autovalue,
)

def test_suite(name):
    """Wires the full KAPT-stage composition/replacement/gate matrix."""
    suite(
        name,
        test_kapt_stage_library = _test_kapt_stage_library,
        test_kapt_stage_binary = _test_kapt_stage_binary,
        test_kapt_stage_junit_test = _test_kapt_stage_junit_test,
        test_kapt_stage_replacement = _test_kapt_stage_replacement,
        test_kapt_stage_no_ap = _test_kapt_stage_no_ap,
        test_kapt_stage_no_eligible_srcs = _test_kapt_stage_no_eligible_srcs,
        test_kapt_stage_export_only = _test_kapt_stage_export_only,
    )
