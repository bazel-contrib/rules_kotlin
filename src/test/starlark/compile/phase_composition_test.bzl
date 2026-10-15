"""Analysis tests locking runtime-fold composition and provider goldens: the
KotlinFoldJarsRuntime fold receives the Kotlin runtime, KAPT class, and resource jars, and
JavaInfo transitive jars plus <name>.jdeps stay identical across library/binary/test/import."""

load("@rules_java//java:defs.bzl", "java_plugin")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("@rules_testing//lib:truth.bzl", "matching")
load("//kotlin:jvm.bzl", "kt_jvm_binary", "kt_jvm_import", "kt_jvm_library", "kt_jvm_test")
load("//src/main/starlark/core/compile:common.bzl", "KtJvmInfo")
load("//src/test/starlark:case.bzl", "Want", "suite")
load(":subjects.bzl", "java_info_subject_factory")

def _runtime_fold_composition(env, got):
    got_target = env.expect.that_target(got)

    # output_jars folds kapt + ksp + kotlin + java class jars; a KAPT target's fold must contain both the Kotlin runtime jar and the KAPT-generated class jar.
    fold = got_target.action_named("KotlinFoldJarsRuntime")
    fold.inputs().contains_at_least_predicates([
        matching.file_basename_equals(env.ctx.file.kt_runtime_jar.basename),
        matching.file_basename_equals(env.ctx.file.kapt_class_jar.basename),
    ])

def _resource_composition(env, got):
    got_target = env.expect.that_target(got)

    # The caller composes `engine.output_jars + resource_jars` into a new list; the intermediate <name>-resources.jar must still reach the fold.
    fold = got_target.action_named("KotlinFoldJarsRuntime")
    fold.inputs().contains_at_least_predicates([
        matching.file_basename_equals(env.ctx.file.kt_runtime_jar.basename),
        matching.file_basename_equals(env.ctx.file.resource_jar.basename),
    ])

def _java_provider_golden(env, got):
    got_target = env.expect.that_target(got)

    # JavaInfo transitive jars and jdeps are the externally consumed field set; the composition reshape must not perturb them.
    got_target.has_provider(JavaInfo)
    ji = got_target.provider(JavaInfo, java_info_subject_factory)
    ji.transitive_compile_time_jars().contains(env.ctx.file.compile_jar.short_path)
    ji.transitive_runtime_jars().contains(env.ctx.file.runtime_jar.short_path)

    # jdeps is the FINAL aggregation stage; the target's own <name>.jdeps exists.
    got_target.action_generating(env.ctx.file.jdeps.short_path)

def _import_provider_golden(env, got):
    got_target = env.expect.that_target(got)

    # kt_jvm_import bypasses the compile engine; its provider set must be unchanged by the engine reshape.
    got_target.has_provider(JavaInfo)
    got_target.has_provider(KtJvmInfo)

def _test_runtime_fold_composition(test):
    # KAPT no-op processor fixture, generated inline to exercise the KAPT action path.
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
        what = _runtime_fold_composition,
        wants = {
            "kapt_class_jar": Want(
                attr = attr.label(allow_single_file = True),
                value = got + "-kapt-generated-class.jar",
            ),
            "kt_runtime_jar": Want(
                attr = attr.label(allow_single_file = True),
                value = got + "-kt.jar",
            ),
        },
    )

def _test_resource_composition(test):
    got = test.got(
        kt_jvm_library,
        name = "got",
        srcs = [test.artifact("Lib.kt")],
        resources = [test.artifact("res.txt")],
    )
    test.claim(
        got = got,
        what = _resource_composition,
        wants = {
            "kt_runtime_jar": Want(
                attr = attr.label(allow_single_file = True),
                value = got + "-kt.jar",
            ),
            "resource_jar": Want(
                attr = attr.label(allow_single_file = True),
                value = got + "-resources.jar",
            ),
        },
    )

def _java_golden_wants(got):
    return {
        "compile_jar": Want(
            attr = attr.label(allow_single_file = True),
            value = got + ".abi.jar",
        ),
        "jdeps": Want(
            attr = attr.label(allow_single_file = True),
            value = got + ".jdeps",
        ),
        "runtime_jar": Want(
            attr = attr.label(allow_single_file = True),
            value = got + ".jar",
        ),
    }

def _test_library_provider_golden(test):
    got = test.got(
        kt_jvm_library,
        name = "got",
        srcs = [test.artifact("Lib.kt")],
    )
    test.claim(
        got = got,
        what = _java_provider_golden,
        wants = _java_golden_wants(got),
    )

def _test_binary_provider_golden(test):
    got = test.got(
        kt_jvm_binary,
        name = "got",
        srcs = [test.artifact("Lib.kt")],
        main_class = "Foo",
    )
    test.claim(
        got = got,
        what = _java_provider_golden,
        wants = _java_golden_wants(got),
    )

def _test_junit_test_provider_golden(test):
    got = test.got(
        kt_jvm_test,
        name = "got",
        srcs = [test.artifact("Lib.kt")],
        test_class = "Foo",
        deps = ["@kotlin_rules_maven_test//:junit_junit"],
    )
    test.claim(
        got = got,
        what = _java_provider_golden,
        wants = _java_golden_wants(got),
    )

def _test_import_provider_golden(test):
    lib = test.have(
        kt_jvm_library,
        name = "lib",
        srcs = [test.artifact("Lib.kt")],
    )
    got = test.got(
        kt_jvm_import,
        name = "got",
        jars = [lib + ".jar"],
    )
    test.claim(
        got = got,
        what = _import_provider_golden,
        wants = {
            "runtime_jar": Want(
                attr = attr.label(allow_single_file = True),
                value = lib + ".jar",
            ),
        },
    )

def test_suite(name):
    suite(
        name,
        test_runtime_fold_composition = _test_runtime_fold_composition,
        test_resource_composition = _test_resource_composition,
        test_library_provider_golden = _test_library_provider_golden,
        test_binary_provider_golden = _test_binary_provider_golden,
        test_junit_test_provider_golden = _test_junit_test_provider_golden,
        test_import_provider_golden = _test_import_provider_golden,
    )
