"""Tests for mixed Kotlin/Java compilation."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:truth.bzl", "matching")
load("//kotlin:jvm.bzl", "kt_jvm_library")
load("//src/test/starlark:case.bzl", "suite")

_REMOVE_PRIVATE_CLASSES_TOOLCHAIN = Label("//src/test/starlark/rules:remove_private_classes_toolchain")

def _javac_uses_full_kotlin_output_(env, target):
    action = env.expect.that_target(target).action_named("Javac")
    action.inputs().contains_at_least_predicates([
        matching.file_basename_equals("%s_main_target_library-kt.jar" % env.ctx.attr.namespace),
    ])
    action.inputs().not_contains_predicate(
        matching.file_basename_equals("%s_main_target_library-kt.abi.jar" % env.ctx.attr.namespace),
    )

def _test_javac_uses_full_kotlin_output(test):
    main_target_library = test.got(
        kt_jvm_library,
        name = "main_target_library",
        srcs = [
            test.artifact(name = "PrivateKotlin.kt"),
            test.artifact(name = "Java.java"),
        ],
    )

    analysis_test(
        name = test.name,
        impl = _javac_uses_full_kotlin_output_,
        target = main_target_library,
        config_settings = {
            "//command_line_option:extra_toolchains": [str(_REMOVE_PRIVATE_CLASSES_TOOLCHAIN)],
        },
        attr_values = {
            "namespace": test.name,
        },
        attrs = {
            "namespace": attr.string(),
        },
    )

def mixed_mode_tests(name):
    suite(
        name,
        javac_uses_full_kotlin_output = _test_javac_uses_full_kotlin_output,
    )
