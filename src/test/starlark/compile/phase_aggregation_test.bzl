"""Analysis tests locking the AbiFold/Jdeps/AnnotationProcessing aggregation contracts.

These lock the observable contract of `_phase_abi` / `_phase_jdeps` /
`_phase_annotation_processing` in kotlin/internal/jvm/compile.bzl, the read-side
aggregation tail of the compile pipeline:

  * `_phase_abi` folds the per-pass ABI jars into the target's `<name>.abi.jar`
    compile jar, so the single action generating that jar must be the
    KotlinFoldJarsAbi fold.
  * `_phase_jdeps` is the FINAL aggregation stage: it merges the per-pass jdeps
    into the target's `<name>.jdeps` via the JdepsMerge action.
  * `_phase_annotation_processing` builds the KtJvmInfo.annotation_processing
    struct; on a KSP target it is `enabled` and points `source_jar` at the
    KSP-generated `<name>-ksp-gensrc.jar`.

so the phase struct contracts stay behavior-preserving across the extraction.
"""

load("//kotlin:jvm.bzl", "kt_jvm_library")
load("//src/main/starlark/core/compile:common.bzl", "KtJvmInfo")
load("//src/test/starlark:case.bzl", "Want", "suite")

def _abi_fold_contract(env, got):
    got_target = env.expect.that_target(got)

    # _phase_abi folds the per-pass compile_jars into <name>.abi.jar; the single
    # action generating that jar is the KotlinFoldJarsAbi fold.
    abi_action = got_target.action_generating(env.ctx.file.abi_jar.short_path)
    abi_action.mnemonic().equals("KotlinFoldJarsAbi")

def _jdeps_merge_contract(env, got):
    got_target = env.expect.that_target(got)

    # _phase_jdeps is the final aggregation: JdepsMerge writes <name>.jdeps.
    jdeps_action = got_target.action_generating(env.ctx.file.jdeps.short_path)
    jdeps_action.mnemonic().equals("JdepsMerge")

def _annotation_processing_contract(env, got):
    # _phase_annotation_processing surfaces the KSP-generated source jar through
    # KtJvmInfo.annotation_processing.
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
    got = test.got(
        kt_jvm_library,
        name = "got",
        srcs = [test.artifact("Lib.kt")],
        plugins = ["//src/test/starlark/compile:phase_moshi_plugin"],
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
