"""Locks the `_phase_kapt`/`_phase_ksp` struct contract in kotlin/internal/jvm/compile.bzl by asserting a real kt_jvm_library's KAPT/KSP actions generate exactly the declared src and class jars."""

load("@rules_java//java:defs.bzl", "java_plugin")
load("//kotlin:core.bzl", "kt_ksp_plugin")
load("//kotlin:jvm.bzl", "kt_jvm_library")
load("//src/test/starlark:case.bzl", "Want", "suite")

def _kapt_contract(env, got):
    got_target = env.expect.that_target(got)

    # The KAPT action must generate exactly the gensrc and class jars _phase_kapt declares.
    got_target.action_generating(env.ctx.file.gensrc_jar.short_path)
    got_target.action_generating(env.ctx.file.class_jar.short_path)

def _ksp_contract(env, got):
    got_target = env.expect.that_target(got)

    # The KSP action must generate exactly the gensrc and class jars _phase_ksp declares.
    got_target.action_generating(env.ctx.file.gensrc_jar.short_path)
    got_target.action_generating(env.ctx.file.class_jar.short_path)

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
