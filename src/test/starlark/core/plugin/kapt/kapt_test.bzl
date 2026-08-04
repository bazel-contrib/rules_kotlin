"""Tests for the kapt compiler-plugin configuration."""

load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("//kotlin:core.bzl", "kt_plugin_cfg")
load("//kotlin:jvm.bzl", "kt_jvm_binary", "kt_jvm_import", "kt_jvm_library")
load("//kotlin/compiler:kapt.bzl", "kapt_compiler_plugin")
load("//src/test/starlark:case.bzl", "Want", "suite")
load("//src/test/starlark:truth.bzl", "flags_and_values_of")

def _normalize_path_with_cfg(file):
    """Attempts to normalize the file to standard configs.

    This turns out to be necessary due to multiple transitions with testing.analysis_test.
    """
    prefix = file.path.removesuffix(file.short_path)
    segments = prefix.split("/")
    if segments[0] == "bazel-out":
        # not exactly reliable, but the current test rules perform several transitions making it
        # difficult to validate if a file is actually where it should be.
        if "exec" in segments[1]:
            return "(exec) " + file.short_path
        return "(target) " + file.short_path
    if file.is_source:
        return "(source) " + file.short_path

    return file.path

def _action(env, got):
    got_target = env.expect.that_target(got)

    want_inputs = {}
    for i in env.ctx.attr.exec_inputs:
        if JavaInfo in i:
            for jo in i[JavaInfo].java_outputs:
                want_inputs[_normalize_path_with_cfg(jo.compile_jar)] = True
        else:
            for f in i[DefaultInfo].files.to_list():
                want_inputs[_normalize_path_with_cfg(f)] = True
    for i in env.ctx.attr.target_inputs:
        if JavaInfo in i:
            for jo in i[JavaInfo].java_outputs:
                want_inputs[_normalize_path_with_cfg(jo.compile_jar)] = True
        else:
            for f in i[DefaultInfo].files.to_list():
                want_inputs[_normalize_path_with_cfg(f)] = True

    compile = got_target.action_named(env.ctx.attr.mnemonic)

    got_inputs = {
        _normalize_path_with_cfg(f): True
        for f in compile.actual.inputs.to_list()
    }

    env.expect.that_collection(got_inputs.keys()).contains_at_least(want_inputs.keys())

    got_target.runfiles().contains_at_least([
        "/".join((env.ctx.workspace_name, f.short_path))
        for r in env.ctx.attr.runfiles
        for f in r[DefaultInfo].files.to_list()
    ])
    flags_and_values_of(compile).contains_at_least(env.ctx.attr.flags.items())

def _apoptions_to_kotlinc(rule_under_test, **kwargs):
    def test(test):
        kapt = test.have(
            kapt_compiler_plugin,
            name = "kapt",
        )

        dep_jar = test.artifact(
            name = "dep.jar",
        )

        option_key = "hold"
        option_value = "keep"

        cfg = test.have(
            kt_plugin_cfg,
            name = "cfg",
            plugin = kapt,
            options = {
                option_key: [option_value],
            },
            deps = [
                "//third_party:dagger",
                test.have(
                    kt_jvm_import,
                    name = "dep_jar",
                    jars = [
                        dep_jar,
                    ],
                ),
            ],
        )

        src = test.artifact("hold.kt")

        got = test.have(
            rule_under_test,
            name = "got",
            srcs = [src],
            plugins = [cfg],
            deps = [],
            **kwargs
        )

        test.claim(
            got = got,
            what = _action,
            wants = {
                "exec_inputs": Want(
                    attr = attr.label_list(allow_empty = True, allow_files = True, cfg = "exec"),
                    value = [dep_jar],
                ),
                "flags": Want(
                    attr = attr.string_list_dict(),
                    value = {
                        "--stubs_plugin_options": [
                            "org.jetbrains.kotlin.kapt3:apoption=%s:%s" % (option_key, option_value),
                        ],
                    },
                ),
                "mnemonic": Want(
                    attr = attr.string(),
                    value = "KotlinKapt",
                ),
                "runfiles": Want(
                    attr = attr.label_list(allow_empty = True, allow_files = True),
                    value = [],
                ),
                "target_inputs": Want(
                    attr = attr.label_list(allow_empty = True, allow_files = True, cfg = "target"),
                    value = [src],
                ),
            },
        )

    return test

def _options_to_javac(rule_under_test, **kwargs):
    def test(test):
        kapt = test.have(
            kapt_compiler_plugin,
            name = "kapt",
        )

        dep_jar = test.artifact(
            name = "dep.jar",
        )

        option_key = "hold"
        option_value = "keep"

        cfg = test.have(
            kt_plugin_cfg,
            name = "cfg",
            plugin = kapt,
            options = {
                option_key: [option_value],
            },
            deps = [
                "//third_party:dagger",
                test.have(
                    kt_jvm_import,
                    name = "dep_jar",
                    jars = [
                        dep_jar,
                    ],
                ),
            ],
        )

        src = test.artifact("hold.java")

        got = test.have(
            rule_under_test,
            name = "got",
            srcs = [src],
            plugins = [cfg],
            deps = [],
            **kwargs
        )

        test.claim(
            got = got,
            what = _action,
            wants = {
                "exec_inputs": Want(
                    attr = attr.label_list(allow_empty = True, allow_files = True, cfg = "exec"),
                    value = [dep_jar],
                ),
                "flags": Want(
                    attr = attr.string_list_dict(),
                    value = {
                        "-A" + option_key: [option_value],
                    },
                ),
                "mnemonic": Want(
                    attr = attr.string(),
                    value = "Javac",
                ),
                "runfiles": Want(
                    attr = attr.label_list(allow_empty = True, allow_files = True),
                    value = [],
                ),
                "target_inputs": Want(
                    attr = attr.label_list(allow_empty = True, allow_files = True, cfg = "target"),
                    value = [src],
                ),
            },
        )

    return test

def test_suite(name):
    suite(
        name,
        test_apoptions_kotlinc_library = _apoptions_to_kotlinc(kt_jvm_library),
        test_apoptions_kotlinc_binary = _apoptions_to_kotlinc(kt_jvm_binary, main_class = "Foo"),
        test_options_javac_library = _options_to_javac(kt_jvm_library),
        test_options_javac_binary = _options_to_javac(kt_jvm_binary, main_class = "Foo"),
    )
