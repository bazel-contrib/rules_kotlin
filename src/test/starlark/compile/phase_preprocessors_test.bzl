"""Analysis tests locking the KAPT/KSP pre-pass phase struct contract.

These lock the observable contract of `_phase_kapt` / `_phase_ksp` in
kotlin/internal/jvm/compile.bzl: each pre-pass phase declares a generated
source jar and a generated class jar and returns them through an immutable
struct that the orchestrator folds into the compile inputs. The tests assert
that the KAPT/KSP actions of a real kt_jvm_library generate exactly those two
jars, so the struct contract stays behavior-preserving across the extraction.
"""

load("//kotlin:jvm.bzl", "kt_jvm_library")
load("//src/test/starlark:case.bzl", "Want", "suite")

def _kapt_contract(env, got):
    got_target = env.expect.that_target(got)

    # _phase_kapt returns generated_src_jars=[<name>-kapt-gensrc.jar] and
    # output_class_jars=[<name>-kapt-generated-class.jar]; the KAPT action must
    # generate exactly those files.
    got_target.action_generating(env.ctx.file.gensrc_jar.short_path)
    got_target.action_generating(env.ctx.file.class_jar.short_path)

def _ksp_contract(env, got):
    got_target = env.expect.that_target(got)

    # _phase_ksp returns generated_src_jars=[<name>-ksp-gensrc.jar] and
    # output_class_jars=[<name>-ksp-genclasses.jar]; the KSP action must
    # generate exactly those files.
    got_target.action_generating(env.ctx.file.gensrc_jar.short_path)
    got_target.action_generating(env.ctx.file.class_jar.short_path)

def _test_kapt_phase_contract(test):
    got = test.got(
        kt_jvm_library,
        name = "got",
        srcs = [test.artifact("Lib.kt")],
        plugins = ["//src/test/starlark/compile:phase_autovalue_plugin"],
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
    got = test.got(
        kt_jvm_library,
        name = "got",
        srcs = [test.artifact("Lib.kt")],
        plugins = ["//src/test/starlark/compile:phase_moshi_plugin"],
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
