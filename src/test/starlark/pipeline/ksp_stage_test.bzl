"""it_ksp_stage_composition_and_replacement -- integration test for us-ksp-stage.

Locks the KspProcessor pipeline stage's contract, inserted between KaptProcessor and
JvmCompileProcessor: it runs exactly once off the original partitioned srcs (never KAPT-generated
sources), its outputs reach their documented consumers, it composes with
`processing_pipeline.replace`, and it stays gated off when inactive."""

load("@rules_testing//lib:truth.bzl", "matching")
load("//kotlin:core.bzl", "kt_ksp_plugin")
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

# (i) on a pure-KSP target: KspProcessor's outputs reach their documented consumers. The gensrc/
# class jars are plain declare_file() artifacts (not predeclared rule outputs), so they're
# discovered from the KotlinKsp2 action's own outputs rather than addressed as a Want.
def _ksp_stage_reaches_consumers(env, got):
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
    gensrc_jar, class_jar = gensrc_matches[0], class_matches[0]

    assert_gensrc_reaches_kotlin_compile_and_sources_jar(
        env,
        got_target,
        gensrc_jar.basename,
        env.ctx.file.sources_jar.short_path,
    )
    assert_class_reaches_runtime_fold(got_target, class_jar.basename)

def _test_ksp_stage_pure_ksp(test):
    got = "//src/test/data/jvm/ksp:ksp_kotlin_resources"
    test.claim(
        got = got,
        what = _ksp_stage_reaches_consumers,
        wants = {
            "sources_jar": Want(attr = attr.label(allow_single_file = True), value = got + "-sources.jar"),
        },
    )

# (ii) on a combined KAPT+KSP target: KspProcessor uses ORIGINAL srcs (never KAPT-generated
# sources), and javac includes KSP sources only because this fixture's KSP plugin set generates
# Java (the existing Java-generation gate).
def _ksp_stage_combined(env, got):
    got_target = env.expect.that_target(got)

    got_target.action_named("KotlinKapt")
    ksp2 = got_target.action_named("KotlinKsp2")

    gensrc_matches = [o for o in ksp2.actual.outputs.to_list() if o.path.endswith("-ksp-gensrc.jar")]
    if len(gensrc_matches) != 1:
        env.fail("KotlinKsp2 should declare exactly one -ksp-gensrc.jar output, found %d" % len(gensrc_matches))
        return
    gensrc_jar = gensrc_matches[0]

    ksp2.inputs().not_contains_predicate(matching.file_basename_contains("-kapt-gensrc.jar"))
    got_target.action_named("Javac").inputs().contains_predicate(
        matching.file_basename_equals(gensrc_jar.basename),
    )

def _test_ksp_stage_combined(test):
    test.claim(
        got = "//src/test/data/jvm/ksp:coffee_lib",
        what = _ksp_stage_combined,
        wants = {},
    )

# (iii) processing_pipeline.replace(PROCESSORS, KspProcessor=<custom>) composed with the REAL
# JvmCompileProcessor engine.
def _custom_ksp_stage(context):
    """Test-only KspProcessor replacement proving `processing_pipeline.replace` composes with the real JvmCompileProcessor engine."""
    ctx = context.ctx
    custom_class_jar = ctx.actions.declare_file(ctx.label.name + "-custom-ksp-replacement.jar")
    ctx.actions.write(custom_class_jar, "custom-ksp-stage-replacement")
    return _ProviderInfo(
        name = "KspProcessor",
        value = struct(
            ksp_generated_src_jar = None,
            ksp_generated_class_jar = custom_class_jar,
        ),
        runfiles = None,
    )

replaceable_ksp_library = make_replaceable_stage_rule(
    processor_name = "KspProcessor",
    custom_processor = _custom_ksp_stage,
    doc = """Test-only rule proving `KspProcessor` is independently replaceable via
    `processing_pipeline.replace` against the real kt_jvm_library PROCESSORS map and
    JvmCompileProcessor engine.""",
)

def _ksp_stage_replacement(env, got):
    # The default KSP action must NOT be registered -- the replacement pre-empts it entirely.
    assert_no_action_named(env, got, "KotlinKsp2")

    env.expect.that_target(got).action_named("KotlinFoldJarsRuntime").inputs().contains_predicate(
        matching.file_basename_equals(env.ctx.file.custom_class_jar.basename),
    )

def _ksp_stage_moshi(test, **kwargs):
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

def _test_ksp_stage_replacement(test):
    moshi = _ksp_stage_moshi(test)
    got = test.got(
        replaceable_ksp_library,
        name = "got",
        srcs = [test.artifact("Source.kt")],
        plugins = [moshi],
    )
    test.claim(
        got = got,
        what = _ksp_stage_replacement,
        wants = {
            "custom_class_jar": Want(attr = attr.label(allow_single_file = True), value = got + "-custom-ksp-replacement.jar"),
        },
    )

# Gate-unmet / inactive-prep cases: no KSP annotation processors, no eligible (Kotlin) sources,
# and export-only must all register NO KotlinKsp2 action.
_test_ksp_stage_no_ksp, _test_ksp_stage_no_eligible_srcs, _test_ksp_stage_export_only = gate_unmet_triad(
    "KotlinKsp2",
    _ksp_stage_moshi,
)

def test_suite(name):
    """Wires the full KSP-stage composition/replacement/gate matrix."""
    suite(
        name,
        test_ksp_stage_pure_ksp = _test_ksp_stage_pure_ksp,
        test_ksp_stage_combined = _test_ksp_stage_combined,
        test_ksp_stage_replacement = _test_ksp_stage_replacement,
        test_ksp_stage_no_ksp = _test_ksp_stage_no_ksp,
        test_ksp_stage_no_eligible_srcs = _test_ksp_stage_no_eligible_srcs,
        test_ksp_stage_export_only = _test_ksp_stage_export_only,
    )
