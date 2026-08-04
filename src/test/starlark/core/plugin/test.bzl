"""Analysis tests for the Kotlin compiler-plugin rules."""

load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("//kotlin:core.bzl", "kt_compiler_plugin", "kt_plugin_cfg")
load("//kotlin:jvm.bzl", "kt_jvm_import", "kt_jvm_library")
load("//src/main/starlark/core/plugin:providers.bzl", "KtCompilerPluginInfo", "KtPluginConfiguration")
load("//src/test/starlark:case.bzl", "suite")
load("//src/test/starlark:truth.bzl", "fail_messages_in", "flags_and_values_of")
load(":subjects.bzl", "plugin_configuration_subject_factory")

def _provider_test_impl(env, target):
    want_options = env.ctx.attr.want_options
    got_target = env.expect.that_target(target)
    got_target.has_provider(KtPluginConfiguration)
    got_provider = got_target.provider(KtPluginConfiguration, plugin_configuration_subject_factory)
    got_provider.options().transform(desc = "option.value", map_each = lambda o: o.value).contains_at_least(want_options)
    got_provider.id().equals(env.ctx.attr.want_plugin[KtCompilerPluginInfo].id)

def _action_test_impl(env, target):
    action = env.expect.that_target(target).action_named(env.ctx.attr.on_action_mnemonic)
    action.inputs().contains_at_least([f.short_path for f in env.ctx.files.want_inputs])
    flags_and_values_of(action).contains_at_least(env.ctx.attr.want_flags.items())

def _expect_failure(env, target):
    fail_messages_in(env.expect.that_target(target)).contains_at_least(env.ctx.attr.want_failures)

def plugin_for(test, name, deps = [], id = None, **kwargs):
    plugin_jar = test.artifact(
        name = name + ".jar",
    )

    deps = deps + [
        test.have(
            kt_jvm_import,
            name = name + "_plugin_jar",
            jars = [
                plugin_jar,
            ],
        ),
    ]

    plugin = test.have(
        kt_compiler_plugin,
        id = id if id else "plugin." + name,
        name = name,
        deps = deps,
        **kwargs
    )
    return (plugin, plugin_jar)

def _test_kt_plugin_cfg(test):
    plugin = test.have(
        kt_compiler_plugin,
        name = "plugin",
        id = "test.stub",
        options = {
            "annotation": "plugin.StubForTesting",
        },
        deps = [
            test.have(
                kt_jvm_library,
                name = "plugin_dep",
                srcs = [
                    test.artifact(
                        name = "plugin.kt",
                    ),
                ],
            ),
        ],
    )
    cfg_dep = test.have(
        kt_jvm_library,
        name = "cfg_dep",
        srcs = [
            test.artifact(
                name = "dependency.kt",
            ),
        ],
    )

    cfg = test.got(
        kt_plugin_cfg,
        name = "got",
        plugin = plugin,
        options = {
            "extra": ["annotation"],
        },
        deps = [
            cfg_dep,
        ],
    )

    analysis_test(
        name = test.name,
        impl = _provider_test_impl,
        target = cfg,
        attr_values = {
            "want_deps": [cfg_dep],
            "want_options": [
                "extra=annotation",
            ],
            "want_plugin": plugin,
        },
        attrs = {
            "want_deps": attr.label_list(providers = [JavaInfo]),
            "want_options": attr.string_list(),
            "want_plugin": attr.label(providers = [KtCompilerPluginInfo]),
        },
    )

def _test_compile_configuration(test):
    plugin_jar = test.artifact(
        name = "plugin.jar",
    )

    plugin = test.have(
        kt_compiler_plugin,
        name = "plugin",
        id = "test.stub",
        options = {
            "annotation": "plugin.StubForTesting",
        },
        deps = [
            test.have(
                kt_jvm_import,
                name = "plugin_jar",
                jars = [
                    plugin_jar,
                ],
            ),
        ],
    )

    dep_jar = test.artifact(
        name = "dep.jar",
    )

    cfg = test.have(
        kt_plugin_cfg,
        name = "cfg",
        plugin = plugin,
        options = {
            "-Dop": ["koo"],
        },
        deps = [
            test.have(
                kt_jvm_import,
                name = "dep_jar",
                jars = [
                    dep_jar,
                ],
            ),
        ],
    )

    got = test.got(
        kt_jvm_library,
        name = "got_library",
        srcs = [
            test.artifact(
                name = "got_library.kt",
            ),
        ],
        plugins = [
            plugin,
            cfg,
        ],
    )

    analysis_test(
        name = test.name,
        impl = _action_test_impl,
        target = got,
        attr_values = {
            "on_action_mnemonic": "KotlinCompile",
            "want_flags": {
                "--compiler_plugin_options": ["test.stub:annotation=plugin.StubForTesting", "test.stub:-Dop=koo"],
                "--stubs_plugin_options": ["test.stub:annotation=plugin.StubForTesting", "test.stub:-Dop=koo"],
            },
            "want_inputs": [
                plugin_jar,
                dep_jar,
            ],
        },
        attrs = {
            "on_action_mnemonic": attr.string(),
            "want_flags": attr.string_list_dict(),
            "want_inputs": attr.label_list(providers = [DefaultInfo], allow_files = True),
        },
    )

def _test_compile_multiple_configurations(test):
    plugin_jar = test.artifact(
        name = "plugin.jar",
    )

    plugin = test.have(
        kt_compiler_plugin,
        name = "plugin",
        id = "test.stub",
        options = {
            "annotation": "plugin.StubForTesting",
        },
        deps = [
            test.have(
                kt_jvm_import,
                name = "plugin_jar",
                jars = [
                    plugin_jar,
                ],
            ),
        ],
    )

    dep_a_jar = test.artifact(
        name = "a_dep.jar",
    )
    dep_b_jar = test.artifact(
        name = "b_dep.jar",
    )

    cfg_a = test.have(
        kt_plugin_cfg,
        name = "cfg_a",
        plugin = plugin,
        options = {
            "-Dop": ["koo"],
        },
        deps = [
            test.have(
                kt_jvm_import,
                name = "dep_a_jar",
                jars = [
                    dep_a_jar,
                ],
            ),
        ],
    )

    cfg_b = test.have(
        kt_plugin_cfg,
        name = "cfg_b",
        plugin = plugin,
        options = {
            "-Dop": ["zubzub"],
        },
        deps = [
            test.have(
                kt_jvm_import,
                name = "dep_b_jar",
                jars = [
                    dep_b_jar,
                ],
            ),
        ],
    )

    got = test.got(
        kt_jvm_library,
        name = "got_library",
        srcs = [
            test.artifact(
                name = "got_library.kt",
            ),
        ],
        plugins = [
            plugin,
            cfg_a,
            cfg_b,
        ],
    )

    analysis_test(
        name = test.name,
        impl = _action_test_impl,
        target = got,
        attr_values = {
            "on_action_mnemonic": "KotlinCompile",
            "want_flags": {
                "--compiler_plugin_options": [
                    "test.stub:annotation=plugin.StubForTesting",
                    "test.stub:-Dop=koo",
                    "test.stub:-Dop=zubzub",
                ],
                "--stubs_plugin_options": [
                    "test.stub:annotation=plugin.StubForTesting",
                    "test.stub:-Dop=koo",
                    "test.stub:-Dop=zubzub",
                ],
            },
            "want_inputs": [
                plugin_jar,
                dep_a_jar,
                dep_b_jar,
            ],
        },
        attrs = {
            "on_action_mnemonic": attr.string(),
            "want_flags": attr.string_list_dict(),
            "want_inputs": attr.label_list(providers = [DefaultInfo], allow_files = True),
        },
    )

def _test_compile_configuration_single_phase(test):
    stub, stub_jar = plugin_for(
        test,
        name = "stub",
        id = "plugin.stub",
        compile_phase = False,
        stubs_phase = True,
    )

    compile, compile_jar = plugin_for(
        test,
        name = "compile",
        id = "plugin.compile",
        stubs_phase = False,
        compile_phase = True,
    )

    stub_cfg = test.have(
        kt_plugin_cfg,
        name = "stub_cfg",
        plugin = stub,
        options = {
            "-Dop": ["stub_only"],
        },
    )

    compile_cfg = test.have(
        kt_plugin_cfg,
        name = "compile_cfg",
        plugin = compile,
        options = {
            "-Dop": ["compile_only"],
        },
    )

    got = test.got(
        kt_jvm_library,
        name = "got_library",
        srcs = [
            test.artifact(
                name = "got_library.kt",
            ),
        ],
        plugins = [
            stub,
            compile,
            compile_cfg,
            stub_cfg,
        ],
    )

    analysis_test(
        name = test.name,
        impl = _action_test_impl,
        target = got,
        attr_values = {
            "on_action_mnemonic": "KotlinCompile",
            "want_flags": {
                "--compiler_plugin_options": ["plugin.compile:-Dop=compile_only"],
                "--stubs_plugin_options": ["plugin.stub:-Dop=stub_only"],
            },
            "want_inputs": [
                stub_jar,
                compile_jar,
            ],
        },
        attrs = {
            "on_action_mnemonic": attr.string(),
            "want_flags": attr.string_list_dict(),
            "want_inputs": attr.label_list(providers = [DefaultInfo], allow_files = True),
        },
    )

def _test_library_multiple_plugins_with_same_id(test):
    got = test.got(
        kt_jvm_library,
        name = "got_library",
        srcs = [
            test.artifact(
                name = "got_library.kt",
            ),
        ],
        plugins = [
            test.have(
                kt_compiler_plugin,
                name = "one",
                id = "test.stub",
                options = {
                    "annotation": "plugin.StubForTesting",
                },
                deps = [
                    test.have(
                        kt_jvm_import,
                        name = "one_plugin_jar",
                        jars = [
                            test.artifact(
                                name = "one_plugin.jar",
                            ),
                        ],
                    ),
                ],
            ),
            test.have(
                kt_compiler_plugin,
                name = "two",
                id = "test.stub",
                options = {
                    "annotation": "plugin.StubForTesting",
                },
                deps = [
                    test.have(
                        kt_jvm_import,
                        name = "two_plugin_jar",
                        jars = [
                            test.artifact(
                                name = "two_plugin.jar",
                            ),
                        ],
                    ),
                ],
            ),
        ],
    )

    analysis_test(
        name = test.name,
        impl = _expect_failure,
        expect_failure = True,
        target = got,
        attr_values = {
            "want_failures": [
                "has multiple plugins with the same id: test.stub.",
            ],
        },
        attrs = {
            "want_failures": attr.string_list(),
        },
    )

def test_suite(name):
    suite(
        name,
        test_kt_plugin_cfg = _test_kt_plugin_cfg,
        test_compile_configuration = _test_compile_configuration,
        test_library_multiple_plugins_with_same_id = _test_library_multiple_plugins_with_same_id,
        test_compile_configuration_single_phase = _test_compile_configuration_single_phase,
        test_compile_multiple_configurations = _test_compile_multiple_configurations,
    )
