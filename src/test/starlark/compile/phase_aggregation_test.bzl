"""Analysis tests locking the aggregation-tail contracts: a target's <name>.abi.jar is
produced by the KotlinFoldJarsAbi fold, <name>.jdeps by the JdepsMerge action, and
KtJvmInfo.annotation_processing surfaces the KSP-generated <name>-ksp-gensrc.jar."""

load("//kotlin:core.bzl", "kt_ksp_plugin")
load("//kotlin:jvm.bzl", "kt_jvm_library")
load("//src/main/starlark/core/compile:common.bzl", "KtJvmInfo")
load("//src/test/starlark:case.bzl", "Want", "suite")

def _abi_fold_contract(env, got):
    got_target = env.expect.that_target(got)

    # _phase_abi folds per-pass compile_jars into <name>.abi.jar via the KotlinFoldJarsAbi fold.
    abi_action = got_target.action_generating(env.ctx.file.abi_jar.short_path)
    abi_action.mnemonic().equals("KotlinFoldJarsAbi")

def _jdeps_merge_contract(env, got):
    got_target = env.expect.that_target(got)

    # _phase_jdeps is the final aggregation: JdepsMerge writes <name>.jdeps.
    jdeps_action = got_target.action_generating(env.ctx.file.jdeps.short_path)
    jdeps_action.mnemonic().equals("JdepsMerge")

def _annotation_processing_contract(env, got):
    # _phase_annotation_processing surfaces the KSP-generated source jar through KtJvmInfo.annotation_processing.
    ap = got[KtJvmInfo].annotation_processing
    env.expect.that_bool(ap.enabled).equals(True)
    env.expect.that_str(ap.source_jar.basename).equals(env.ctx.file.gensrc_jar.basename)

def _test_abi_fold_contract(test):
    got = test.got(
        kt_jvm_library,
        name = "got",
        srcs = [test.artifact("Lib.kt")],
    )
    test.claim(
        got = got,
        what = _abi_fold_contract,
        wants = {
            "abi_jar": Want(
                attr = attr.label(allow_single_file = True),
                value = got + ".abi.jar",
            ),
        },
    )

def _test_jdeps_merge_contract(test):
    got = test.got(
        kt_jvm_library,
        name = "got",
        srcs = [test.artifact("Lib.kt")],
    )
    test.claim(
        got = got,
        what = _jdeps_merge_contract,
        wants = {
            "jdeps": Want(
                attr = attr.label(allow_single_file = True),
                value = got + ".jdeps",
            ),
        },
    )

def _test_annotation_processing_contract(test):
    # Inline moshi KSP plugin fixture exercising the annotation-processing action path.
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
        what = _annotation_processing_contract,
        wants = {
            "gensrc_jar": Want(
                attr = attr.label(allow_single_file = True),
                value = got + "-ksp-gensrc.jar",
            ),
        },
    )

def test_suite(name):
    suite(
        name,
        test_abi_fold_contract = _test_abi_fold_contract,
        test_jdeps_merge_contract = _test_jdeps_merge_contract,
        test_annotation_processing_contract = _test_annotation_processing_contract,
    )
