"""Analysis tests locking the Kotlin/Java compile contract on a mixed Kotlin+Java target:
KotlinCompile generates the full runtime jar (<name>-kt.jar), and the Javac action
compiles against that jar as a neverlink stub."""

load("@rules_testing//lib:truth.bzl", "matching")
load("//kotlin:jvm.bzl", "kt_jvm_library")
load("//src/test/starlark:case.bzl", "Want", "suite")

def _kotlin_phase_contract(env, got):
    got_target = env.expect.that_target(got)

    # _phase_kotlin returns output_jars=[<name>-kt.jar]; KotlinCompile must generate it.
    got_target.action_named("KotlinCompile")
    got_target.action_generating(env.ctx.file.kt_runtime_jar.short_path)

    # _phase_kotlin.extra_stubs_java_infos wraps the full runtime jar as a neverlink stub the Java pass compiles against.
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
