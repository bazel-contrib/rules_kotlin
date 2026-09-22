"""Analysis tests locking the KotlinCompile/JavaCompile phase struct contract.

These lock the observable contract of `_phase_kotlin` / `_phase_java` in
kotlin/internal/jvm/compile.bzl. `_phase_kotlin` runs the KotlinCompile action
and returns an immutable struct whose `output_jars` is the full runtime jar
(`<name>-kt.jar`); its `extra_stubs_java_infos` wraps that full runtime jar as a
neverlink stub that the Java pass compiles against (in the default toolchain the
ABI jar is disabled, so `compile_jars` is that same `-kt.jar`). The tests run
against a mixed Kotlin+Java target (the plain fixture emits no Java pass, so it
cannot observe the stub flow) and assert:

  * the KotlinCompile action exists and generates the runtime jar the
    `_phase_kotlin` struct returns, and
  * the Javac action's inputs include that full runtime jar
    (`_phase_kotlin.extra_stubs_java_infos`),

so the phase struct contract stays behavior-preserving across the extraction.
"""

load("@rules_testing//lib:truth.bzl", "matching")
load("//kotlin:jvm.bzl", "kt_jvm_library")
load("//src/test/starlark:case.bzl", "Want", "suite")

def _kotlin_phase_contract(env, got):
    got_target = env.expect.that_target(got)

    # _phase_kotlin runs KotlinCompile and returns output_jars=[<name>-kt.jar];
    # the KotlinCompile action must generate that runtime jar.
    got_target.action_named("KotlinCompile")
    got_target.action_generating(env.ctx.file.kt_runtime_jar.short_path)

    # _phase_kotlin.extra_stubs_java_infos wraps the FULL runtime jar as a
    # neverlink stub; the Java pass compiles against it.
    javac = got_target.action_named("Javac")
    javac.inputs().contains_at_least_predicates([
        matching.file_basename_equals(env.ctx.file.kt_runtime_jar.basename),
    ])

def _test_kotlin_phase_contract(test):
    got = test.got(
        kt_jvm_library,
        name = "got",
        srcs = [
            test.artifact("Lib.kt"),
            test.artifact("Aux.java"),
        ],
    )
    test.claim(
        got = got,
        what = _kotlin_phase_contract,
        wants = {
            "kt_runtime_jar": Want(
                attr = attr.label(allow_single_file = True),
                value = got + "-kt.jar",
            ),
        },
    )

def test_suite(name):
    suite(
        name,
        test_kotlin_phase_contract = _test_kotlin_phase_contract,
    )
