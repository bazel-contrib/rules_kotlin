"""Locks the `_phase_kapt`/`_phase_ksp` struct contract in kotlin/internal/jvm/compile.bzl by asserting a real kt_jvm_library's KAPT/KSP actions generate exactly the declared src and class jars,
AND that those artifacts actually reach their documented consumers (producer->consumer edges), not
merely that they exist: the gensrc jar must be a Kotlin-compile source jar, the class jar must
reach the KotlinFoldJarsRuntime fold, and -- for KAPT -- the neverlink stub JavaInfo wrapping the
stub jar must reach the Javac pass compiling the Java half."""

load("@rules_java//java:defs.bzl", "java_plugin")
load("@rules_testing//lib:truth.bzl", "matching")
load("//kotlin:core.bzl", "kt_ksp_plugin")
load("//kotlin:jvm.bzl", "kt_jvm_library")
load("//src/test/starlark:case.bzl", "Want", "suite")

def _kapt_contract(env, got):
    got_target = env.expect.that_target(got)

    # The KAPT action must generate exactly the gensrc and class jars _phase_kapt declares.
    got_target.action_generating(env.ctx.file.gensrc_jar.short_path)
    got_target.action_generating(env.ctx.file.class_jar.short_path)

    # The gensrc jar is folded into generated_src_jars, a KotlinCompile source jar.
    kt_compile = got_target.action_named("KotlinCompile")
    kt_compile.inputs().contains_at_least_predicates([
        matching.file_basename_equals(env.ctx.file.gensrc_jar.basename),
    ])

    # The gensrc jar also reaches the Javac pass compiling the Java half, alongside the neverlink
    # stub JavaInfo wrapping the KAPT stub jar (_run_kt_java_builder_actions' kt_stubs_for_java).
    javac = got_target.action_named("Javac")
    javac.inputs().contains_at_least_predicates([
        matching.file_basename_equals(env.ctx.file.gensrc_jar.basename),
        matching.file_basename_equals(env.ctx.file.stub_jar.basename),
    ])

    # The class jar is folded into the final runtime jar.
    fold = got_target.action_named("KotlinFoldJarsRuntime")
    fold.inputs().contains_at_least_predicates([
        matching.file_basename_equals(env.ctx.file.class_jar.basename),
    ])

def _ksp_contract(env, got):
    got_target = env.expect.that_target(got)

    # The KSP action must generate exactly the gensrc and class jars _phase_ksp declares.
    got_target.action_generating(env.ctx.file.gensrc_jar.short_path)
    got_target.action_generating(env.ctx.file.class_jar.short_path)

    # The gensrc jar is folded into generated_src_jars, a KotlinCompile source jar.
    kt_compile = got_target.action_named("KotlinCompile")
    kt_compile.inputs().contains_at_least_predicates([
        matching.file_basename_equals(env.ctx.file.gensrc_jar.basename),
    ])

    # The class jar is folded into the final runtime jar.
    fold = got_target.action_named("KotlinFoldJarsRuntime")
    fold.inputs().contains_at_least_predicates([
        matching.file_basename_equals(env.ctx.file.class_jar.basename),
    ])

def _test_kapt_phase_contract(test):
    # Real AutoValue processor, just enough to exercise the KAPT action path.
    autovalue = test.have(
        java_plugin,
        name = "autovalue_plugin",
        generates_api = 1,
        processor_class = "com.google.auto.value.processor.AutoValueProcessor",
        deps = ["@kotlin_rules_maven//:com_google_auto_value_auto_value"],
    )
    got = test.got(
        kt_jvm_library,
        name = "got",
        srcs = [test.artifact("Lib.kt")],
        plugins = [autovalue],
    )
    test.claim(
        got = got,
        what = _kapt_contract,
        wants = {
            "class_jar": Want(
                attr = attr.label(allow_single_file = True),
                value = got + "-kapt-generated-class.jar",
            ),
            "gensrc_jar": Want(
                attr = attr.label(allow_single_file = True),
                value = got + "-kapt-gensrc.jar",
            ),
            "stub_jar": Want(
                attr = attr.label(allow_single_file = True),
                value = got + "-kapt-generated-stub.jar",
            ),
        },
    )

def _test_ksp_phase_contract(test):
    # Real Moshi KSP processor, just enough to exercise the KSP action path.
    moshi = test.have(
        kt_ksp_plugin,
        name = "moshi_plugin",
        processor_class = "com.squareup.moshi.kotlin.codegen.ksp.JsonClassSymbolProcessorProvider",
        deps = [
            "@kotlin_rules_maven_test//:com_squareup_moshi_moshi",
            "@kotlin_rules_maven_test//:com_squareup_moshi_moshi_kotlin",
            "@kotlin_rules_maven_test//:com_squareup_moshi_moshi_kotlin_codegen",
        ],
    )
    got = test.got(
        kt_jvm_library,
        name = "got",
        srcs = [test.artifact("Lib.kt")],
        plugins = [moshi],
    )
    test.claim(
        got = got,
        what = _ksp_contract,
        wants = {
            "class_jar": Want(
                attr = attr.label(allow_single_file = True),
                value = got + "-ksp-genclasses.jar",
            ),
            "gensrc_jar": Want(
                attr = attr.label(allow_single_file = True),
                value = got + "-ksp-gensrc.jar",
            ),
        },
    )

def test_suite(name):
    suite(
        name,
        test_kapt_phase_contract = _test_kapt_phase_contract,
        test_ksp_phase_contract = _test_ksp_phase_contract,
    )
