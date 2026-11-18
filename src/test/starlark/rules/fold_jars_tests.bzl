"""Tests that a jar fold is created only when it has more than the Kotlin jar to fold."""

load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:truth.bzl", "matching")
load("//kotlin:jvm.bzl", "kt_jvm_library")
load("//src/test/starlark:case.bzl", "suite")

_ABI_JARS_TOOLCHAIN = Label("//src/test/starlark/rules:abi_jars_toolchain")

_FOLDS = ["KotlinFoldJarsRuntime", "KotlinFoldJarsAbi"]

def _mnemonics(target):
    return [action.mnemonic for action in target.actions]

def _kotlin_only_writes_final_jars(env, target):
    for fold in _FOLDS:
        env.expect.that_collection(_mnemonics(target)).not_contains(fold)

    java_outputs = target[JavaInfo].java_outputs
    env.expect.that_int(len(java_outputs)).equals(1)
    env.expect.that_str(java_outputs[0].class_jar.basename).equals(env.ctx.attr.name_prefix + ".jar")
    env.expect.that_str(java_outputs[0].compile_jar.basename).equals(env.ctx.attr.name_prefix + ".abi.jar")

    got_target = env.expect.that_target(target)
    got_target.action_generating(java_outputs[0].class_jar.short_path).mnemonic().equals("KotlinCompile")
    got_target.action_generating(java_outputs[0].compile_jar.short_path).mnemonic().equals("KotlinCompile")

def _resources_fold_the_runtime_jar(env, target):
    fold = env.expect.that_target(target).action_named("KotlinFoldJarsRuntime")
    fold.inputs().contains_at_least_predicates([
        matching.file_basename_equals(env.ctx.attr.name_prefix + "-kt.jar"),
        matching.file_basename_equals(env.ctx.attr.name_prefix + "-resources.jar"),
    ])

    # The compile jar takes no resources, so the KotlinBuilder still writes it directly.
    env.expect.that_collection(_mnemonics(target)).not_contains("KotlinFoldJarsAbi")

def _java_sources_fold_both_jars(env, target):
    runtime_fold = env.expect.that_target(target).action_named("KotlinFoldJarsRuntime")
    runtime_fold.inputs().contains_at_least_predicates([
        matching.file_basename_equals(env.ctx.attr.name_prefix + "-kt.jar"),
        matching.file_basename_equals(env.ctx.attr.name_prefix + "-java.jar"),
    ])
    abi_fold = env.expect.that_target(target).action_named("KotlinFoldJarsAbi")
    abi_fold.inputs().contains_at_least_predicates([
        matching.file_basename_equals(env.ctx.attr.name_prefix + "-kt.abi.jar"),
    ])

def _analysis_test(test, impl, target, name):
    analysis_test(
        name = test.name,
        impl = impl,
        target = target,
        config_settings = {
            "//command_line_option:extra_toolchains": [str(_ABI_JARS_TOOLCHAIN)],
        },
        attr_values = {
            "name_prefix": test.name + "_" + name,
        },
        attrs = {
            "name_prefix": attr.string(),
        },
    )

def _test_kotlin_only_writes_final_jars(test):
    lib = test.got(
        kt_jvm_library,
        name = "lib",
        srcs = [test.artifact(name = "Lib.kt")],
    )
    _analysis_test(test, _kotlin_only_writes_final_jars, lib, "lib")

def _test_resources_fold_the_runtime_jar(test):
    lib = test.got(
        kt_jvm_library,
        name = "lib",
        srcs = [test.artifact(name = "Lib.kt")],
        resources = [test.artifact(name = "res.txt")],
    )
    _analysis_test(test, _resources_fold_the_runtime_jar, lib, "lib")

def _test_java_sources_fold_both_jars(test):
    lib = test.got(
        kt_jvm_library,
        name = "lib",
        srcs = [
            test.artifact(name = "Lib.kt"),
            test.artifact(name = "Java.java"),
        ],
    )
    _analysis_test(test, _java_sources_fold_both_jars, lib, "lib")

def fold_jars_tests(name):
    suite(
        name,
        kotlin_only_writes_final_jars = _test_kotlin_only_writes_final_jars,
        resources_fold_the_runtime_jar = _test_resources_fold_the_runtime_jar,
        java_sources_fold_both_jars = _test_java_sources_fold_both_jars,
    )
