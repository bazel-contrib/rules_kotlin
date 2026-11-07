"""it_shared_kapt_ksp_pipeline_parity -- integration test for us-shared-processing-parity.

Locks action-graph invariants across the kt_jvm_library KAPT/KSP/Java/combined/export-only
matrix: kotlinc/kapt/ksp/jdeps-merge actions register against the rule's declared output jars,
each generated artifact is declared exactly once per target, and the runtime-jar fold preserves
KAPT-before-KSP input ordering."""

load("@rules_testing//lib:util.bzl", "TestingAspectInfo")
load("//kotlin:jvm.bzl", "kt_jvm_library")
load("//src/test/starlark:case.bzl", "suite")

def _actions_named(target, mnemonic):
    return [a for a in target[TestingAspectInfo].actions if a.mnemonic == mnemonic]

def _assert_exactly_once(env, got, mnemonic):
    # TargetSubject.action_named fails loudly unless exactly one action matches `mnemonic`
    # (invariant b: each generated artifact declared exactly once per target).
    env.expect.that_target(got).action_named(mnemonic)

def _assert_absent(env, got, mnemonic):
    found = _actions_named(got, mnemonic)
    if found:
        env.fail("expected no %s action, found %d" % (mnemonic, len(found)))

def _assert_kapt_before_ksp_in_runtime_fold(env, got):
    """Asserts the runtime-jar fold's argv lists the KAPT class jar before the KSP class jar."""
    fold = env.expect.that_target(got).action_named("KotlinFoldJarsRuntime")
    argv = fold.actual.argv
    kapt_indices = [i for i, a in enumerate(argv) if a.endswith("-kapt-generated-class.jar")]
    ksp_indices = [i for i, a in enumerate(argv) if a.endswith("-ksp-genclasses.jar")]
    if len(kapt_indices) != 1 or len(ksp_indices) != 1:
        env.fail(
            "expected exactly one kapt class jar and one ksp class jar in the runtime fold " +
            "inputs: kapt=%s ksp=%s argv=%s" % (kapt_indices, ksp_indices, argv),
        )
        return
    if kapt_indices[0] >= ksp_indices[0]:
        env.fail("KAPT output must precede KSP output in the runtime fold inputs (KAPT-before-KSP order): %s" % argv)

# plain: no KAPT, no KSP, no Java -- the baseline path with every phase's gate unmet.
def _plain_library_parity(env, got):
    for mnemonic in ["KotlinCompile", "KotlinFoldJarsAbi", "KotlinFoldJarsRuntime", "JdepsMerge"]:
        _assert_exactly_once(env, got, mnemonic)
    for mnemonic in ["KotlinKapt", "KotlinKsp2", "Javac"]:
        _assert_absent(env, got, mnemonic)

def _test_it_shared_kapt_ksp_pipeline_parity_plain(test):
    got = test.got(
        kt_jvm_library,
        name = "got",
        srcs = [test.artifact("ParitySource.kt")],
    )
    test.claim(got = got, what = _plain_library_parity, wants = {})

# srcjar: a generated source jar input instead of a plain .kt file -- partitioned into
# srcs.src_jars, not srcs.kt, by _partitioned_srcs; must still reach KotlinCompile. A non-empty
# srcs.src_jars also satisfies the "Build Java" gate (it may contain generated .java), so Javac
# runs too.
def _srcjar_library_parity(env, got):
    for mnemonic in ["KotlinCompile", "Javac", "KotlinFoldJarsAbi", "KotlinFoldJarsRuntime", "JdepsMerge"]:
        _assert_exactly_once(env, got, mnemonic)
    for mnemonic in ["KotlinKapt", "KotlinKsp2"]:
        _assert_absent(env, got, mnemonic)

def _test_it_shared_kapt_ksp_pipeline_parity_srcjar(test):
    # A genrule-produced .srcjar is partitioned by extension into srcs.src_jars, exercising a
    # different branch of _partitioned_srcs than a bare .kt file.
    srcjar_out = test.name + "_src.srcjar"
    srcjar = test.have(
        native.genrule,
        name = "src",
        outs = [srcjar_out],
        cmd = """
cat << 'EOF' > ParitySrcjarSource.kt
class ParitySrcjarSource
EOF
$(JAVABASE)/bin/jar -cf $@ ParitySrcjarSource.kt
rm ParitySrcjarSource.kt
""",
        toolchains = ["@bazel_tools//tools/jdk:current_host_java_runtime"],
    )
    got = test.got(
        kt_jvm_library,
        name = "got",
        srcs = [srcjar],
    )
    test.claim(got = got, what = _srcjar_library_parity, wants = {})

# KAPT-only: //src/test/data/jvm/kapt:ap_kotlin_mixed (autovalue KAPT, mixed Kotlin+Java srcs).
def _kapt_only_parity(env, got):
    for mnemonic in ["KotlinKapt", "KotlinCompile", "Javac", "KotlinFoldJarsAbi", "KotlinFoldJarsRuntime", "JdepsMerge"]:
        _assert_exactly_once(env, got, mnemonic)
    _assert_absent(env, got, "KotlinKsp2")

def _test_it_shared_kapt_ksp_pipeline_parity_kapt_only(test):
    test.claim(
        got = "//src/test/data/jvm/kapt:ap_kotlin_mixed",
        what = _kapt_only_parity,
        wants = {},
    )

# KAPT resources-only: //src/test/data/jvm/kapt:ap_kotlin_resources (autoservice KAPT, Kotlin-only
# srcs). KAPT's gensrc jar is unconditionally declared when its gate is met, so Javac still runs
# to compile that (possibly-empty) generated Java half.
def _kapt_resources_only_parity(env, got):
    for mnemonic in ["KotlinKapt", "KotlinCompile", "Javac", "KotlinFoldJarsAbi", "KotlinFoldJarsRuntime", "JdepsMerge"]:
        _assert_exactly_once(env, got, mnemonic)
    _assert_absent(env, got, "KotlinKsp2")

def _test_it_shared_kapt_ksp_pipeline_parity_kapt_resources_only(test):
    test.claim(
        got = "//src/test/data/jvm/kapt:ap_kotlin_resources",
        what = _kapt_resources_only_parity,
        wants = {},
    )

# KSP-only: //src/test/data/jvm/ksp:ksp_kotlin_resources (moshi KSP, Kotlin-only srcs,
# generates_java defaults False so Javac does not run).
def _ksp_only_parity(env, got):
    for mnemonic in ["KotlinKsp2", "KotlinCompile", "KotlinFoldJarsAbi", "KotlinFoldJarsRuntime", "JdepsMerge"]:
        _assert_exactly_once(env, got, mnemonic)
    for mnemonic in ["KotlinKapt", "Javac"]:
        _assert_absent(env, got, mnemonic)

def _test_it_shared_kapt_ksp_pipeline_parity_ksp_only(test):
    test.claim(
        got = "//src/test/data/jvm/ksp:ksp_kotlin_resources",
        what = _ksp_only_parity,
        wants = {},
    )

# Java-only consumer: //src/test/data/jvm/ksp:ksp_only_java (autoservice KSP + a real .java src,
# so Javac runs regardless of the KSP generates_java flag).
def _java_consumer_parity(env, got):
    for mnemonic in ["KotlinKsp2", "KotlinCompile", "Javac", "KotlinFoldJarsAbi", "KotlinFoldJarsRuntime", "JdepsMerge"]:
        _assert_exactly_once(env, got, mnemonic)
    _assert_absent(env, got, "KotlinKapt")

def _test_it_shared_kapt_ksp_pipeline_parity_java_only(test):
    test.claim(
        got = "//src/test/data/jvm/ksp:ksp_only_java",
        what = _java_consumer_parity,
        wants = {},
    )

# Combined KAPT+KSP: //src/test/data/jvm/ksp:coffee_lib (dagger/moshi/autoservice KSP +
# autovalue KAPT). Both phases run, each exactly once, preserving KAPT-before-KSP fold order.
def _combined_kapt_ksp_parity(env, got):
    for mnemonic in ["KotlinKapt", "KotlinKsp2", "KotlinCompile", "Javac", "KotlinFoldJarsAbi", "KotlinFoldJarsRuntime", "JdepsMerge"]:
        _assert_exactly_once(env, got, mnemonic)
    _assert_kapt_before_ksp_in_runtime_fold(env, got)

def _test_it_shared_kapt_ksp_pipeline_parity_combined(test):
    test.claim(
        got = "//src/test/data/jvm/ksp:coffee_lib",
        what = _combined_kapt_ksp_parity,
        wants = {},
    )

# export-only: an exports-only kt_jvm_library (no srcs/resources) routes to
# compile.export_only_providers entirely, bypassing prepare/phase_kapt/phase_ksp/
# run_remaining_compile -- it must register NO kotlinc/kapt/ksp/javac/fold/jdeps-merge action
# (it only symlinks placeholder empty outputs).
def _export_only_parity(env, got):
    for mnemonic in [
        "KotlinCompile",
        "KotlinKapt",
        "KotlinKsp2",
        "Javac",
        "KotlinFoldJarsAbi",
        "KotlinFoldJarsRuntime",
        "JdepsMerge",
    ]:
        _assert_absent(env, got, mnemonic)

def _test_it_shared_kapt_ksp_pipeline_parity_export_only(test):
    # Export-only: no srcs/resources, exports a plugin-exporting java_library. Exercises
    # compile.export_only_providers, the sibling code path to the extracted prepare/kapt/ksp.
    got = test.got(
        kt_jvm_library,
        name = "got",
        exports = ["//src/test/data/jvm/kapt:library_exporting_autovalue_and_junit"],
    )
    test.claim(got = got, what = _export_only_parity, wants = {})

# export-only-with-resource_jars: an exports-only kt_jvm_library with no srcs/resources but a
# non-empty resource_jars is still active (`is_export_only_inactive` counts resource_jars) -- it
# must run the real compile/fold pipeline, not export_only_providers, or the resource_jars content
# would be dropped.
def _export_only_with_resource_jars_is_active(env, got):
    env.expect.that_target(got).action_named("KotlinFoldJarsRuntime")

def _test_it_shared_kapt_ksp_pipeline_parity_export_only_with_resource_jars(test):
    resource_jar_out = test.name + "_resource.jar"
    resource_jar = test.have(
        native.genrule,
        name = "resource_jar",
        outs = [resource_jar_out],
        cmd = """
echo resource > resource.txt
$(JAVABASE)/bin/jar -cf $@ resource.txt
rm resource.txt
""",
        toolchains = ["@bazel_tools//tools/jdk:current_host_java_runtime"],
    )
    got = test.got(
        kt_jvm_library,
        name = "got",
        exports = ["//src/test/data/jvm/kapt:library_exporting_autovalue_and_junit"],
        resource_jars = [resource_jar],
    )
    test.claim(got = got, what = _export_only_with_resource_jars_is_active, wants = {})

def test_suite(name):
    """Wires the full KAPT/KSP/Java/combined/export-only matrix."""
    suite(
        name,
        test_it_shared_kapt_ksp_pipeline_parity_plain = _test_it_shared_kapt_ksp_pipeline_parity_plain,
        test_it_shared_kapt_ksp_pipeline_parity_srcjar = _test_it_shared_kapt_ksp_pipeline_parity_srcjar,
        test_it_shared_kapt_ksp_pipeline_parity_kapt_only = _test_it_shared_kapt_ksp_pipeline_parity_kapt_only,
        test_it_shared_kapt_ksp_pipeline_parity_kapt_resources_only = _test_it_shared_kapt_ksp_pipeline_parity_kapt_resources_only,
        test_it_shared_kapt_ksp_pipeline_parity_ksp_only = _test_it_shared_kapt_ksp_pipeline_parity_ksp_only,
        test_it_shared_kapt_ksp_pipeline_parity_export_only_with_resource_jars = _test_it_shared_kapt_ksp_pipeline_parity_export_only_with_resource_jars,
        test_it_shared_kapt_ksp_pipeline_parity_java_only = _test_it_shared_kapt_ksp_pipeline_parity_java_only,
        test_it_shared_kapt_ksp_pipeline_parity_combined = _test_it_shared_kapt_ksp_pipeline_parity_combined,
        test_it_shared_kapt_ksp_pipeline_parity_export_only = _test_it_shared_kapt_ksp_pipeline_parity_export_only,
    )
