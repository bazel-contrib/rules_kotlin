"""Analysis tests for the Kotlin compiler-plugin rules."""

load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("//kotlin:core.bzl", "kt_compiler_plugin", "kt_plugin_cfg")
load("//kotlin:jvm.bzl", "kt_jvm_import", "kt_jvm_library")
load("//src/main/starlark/core/plugin:providers.bzl", "KtCompilerPluginInfo", "KtPluginConfiguration")
load("//src/test/starlark:case.bzl", "suite")
load("//src/test/starlark:truth.bzl", "fail_messages_in", "flags_and_values_of", "payload_plugins_of")
load(":subjects.bzl", "plugin_configuration_subject_factory")

def _provider_test_impl(env, target):
    want_options = env.ctx.attr.want_options
    got_target = env.expect.that_target(target)
    got_target.has_provider(KtPluginConfiguration)
    got_provider = got_target.provider(KtPluginConfiguration, plugin_configuration_subject_factory)
    got_provider.options().transform(desc = "option.value", map_each = lambda o: o.value).contains_at_least(want_options)
    got_provider.id().equals(env.ctx.attr.want_plugin[KtCompilerPluginInfo].id)

# The per-phase plugin flags the plugins payload replaced; no action may carry them.
_RETIRED_PLUGIN_FLAGS = [
    "--compiler_plugin_classpath",
    "--compiler_plugin_options",
    "--stubs_plugin_classpath",
    "--stubs_plugin_options",
]

def _action_test_impl(env, target):
    action = env.expect.that_target(target).action_named(env.ctx.attr.on_action_mnemonic)
    action.inputs().contains_at_least([f.short_path for f in env.ctx.files.want_inputs])
    parsed_flags = flags_and_values_of(action)
    parsed_flags.contains_at_least(env.ctx.attr.want_flags.items())
    flag_keys = parsed_flags.transform(
        desc = "flag keys",
        map_each = lambda item: item[0],
    )
    if env.ctx.attr.want_flag_keys:
        flag_keys.contains_at_least(env.ctx.attr.want_flag_keys)
    flag_keys.contains_none_of(_RETIRED_PLUGIN_FLAGS)
    if env.ctx.attr.want_payload_plugins:
        payload_plugins_of(action).contains_exactly(env.ctx.attr.want_payload_plugins)

def _inline_payload_test_impl(env, target):
    action = env.expect.that_target(target).action_named("KotlinCompile")
    action.argv().transform(
        desc = "inline --plugins_payload plugin ids",
        loop = _inline_payload_plugin_ids,
    ).contains(env.ctx.attr.want_plugin_id)

def _inline_payload_plugin_ids(argv):
    if argv == None:
        return []
    for i, arg in enumerate(argv):
        if arg != "--plugins_payload" or i + 1 >= len(argv):
            continue
        value = argv[i + 1]
        if not value.startswith("{"):
            # A params-file reference or split value breaks the inline JSON contract.
            return []
        return [plugin["id"] for plugin in json.decode(value)["plugins"]]
    return []

def _expect_failure(env, target):
    fail_messages_in(env.expect.that_target(target)).contains_at_least(env.ctx.attr.want_failures)

def _expect_failure_contains(env, target):
    failures = fail_messages_in(env.expect.that_target(target))
    for want in env.ctx.attr.want_failure_substrings:
        failures.transform(
            desc = "contains '%s'" % want,
            map_each = lambda f: want in f,
        ).contains(True)

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

def _test_kt_plugin_cfg_multi_value_options(test):
    plugin = test.have(
        kt_compiler_plugin,
        name = "plugin",
        id = "test.multi",
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

    cfg = test.got(
        kt_plugin_cfg,
        name = "got",
        plugin = plugin,
        options = {
            "annotation": [
                "plugin.First",
                "plugin.Second",
            ],
        },
        deps = [],
    )

    analysis_test(
        name = test.name,
        impl = _provider_test_impl,
        target = cfg,
        attr_values = {
            "want_deps": [],
            "want_options": [
                "annotation=plugin.First",
                "annotation=plugin.Second",
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
            "want_flag_keys": ["--plugins_payload"],
            "want_flags": {
            },
            "want_inputs": [
                plugin_jar,
                dep_jar,
            ],
            "want_payload_plugins": [
                "id=test.stub classpath=[{n}_plugin.jar,{n}_dep.jar] ".format(n = test.name) +
                "phases=[PLUGIN_PHASE_COMPILE,PLUGIN_PHASE_STUBS] " +
                "options=[annotation=plugin.StubForTesting,-Dop=koo]",
            ],
        },
        attrs = {
            "on_action_mnemonic": attr.string(),
            "want_flag_keys": attr.string_list(),
            "want_flags": attr.string_list_dict(),
            "want_inputs": attr.label_list(providers = [DefaultInfo], allow_files = True),
            "want_payload_plugins": attr.string_list(),
        },
    )

def _test_compile_configuration_inline_payload_json(test):
    plugin = test.have(
        kt_compiler_plugin,
        name = "plugin",
        id = "test.inline.payload",
        options = {
            "annotation": "plugin.StubForTesting",
        },
        deps = [
            test.have(
                kt_jvm_import,
                name = "plugin_jar",
                jars = [
                    test.artifact(
                        name = "plugin.jar",
                    ),
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
        plugins = [plugin],
    )

    analysis_test(
        name = test.name,
        impl = _inline_payload_test_impl,
        target = got,
        attr_values = {
            "want_plugin_id": "test.inline.payload",
        },
        attrs = {
            "want_plugin_id": attr.string(),
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
            "want_flag_keys": ["--plugins_payload"],
            "want_flags": {
            },
            "want_inputs": [
                plugin_jar,
                dep_a_jar,
                dep_b_jar,
            ],
            "want_payload_plugins": [
                "id=test.stub classpath=[{n}_plugin.jar,{n}_a_dep.jar,{n}_b_dep.jar] ".format(n = test.name) +
                "phases=[PLUGIN_PHASE_COMPILE,PLUGIN_PHASE_STUBS] " +
                "options=[annotation=plugin.StubForTesting,-Dop=koo,-Dop=zubzub]",
            ],
        },
        attrs = {
            "on_action_mnemonic": attr.string(),
            "want_flag_keys": attr.string_list(),
            "want_flags": attr.string_list_dict(),
            "want_inputs": attr.label_list(providers = [DefaultInfo], allow_files = True),
            "want_payload_plugins": attr.string_list(),
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
            "want_flag_keys": ["--plugins_payload"],
            "want_flags": {
            },
            "want_inputs": [
                stub_jar,
                compile_jar,
            ],
            "want_payload_plugins": [
                "id=plugin.stub classpath=[{n}_stub.jar] ".format(n = test.name) +
                "phases=[PLUGIN_PHASE_STUBS] options=[-Dop=stub_only]",
                "id=plugin.compile classpath=[{n}_compile.jar] ".format(n = test.name) +
                "phases=[PLUGIN_PHASE_COMPILE] options=[-Dop=compile_only]",
            ],
        },
        attrs = {
            "on_action_mnemonic": attr.string(),
            "want_flag_keys": attr.string_list(),
            "want_flags": attr.string_list_dict(),
            "want_inputs": attr.label_list(providers = [DefaultInfo], allow_files = True),
            "want_payload_plugins": attr.string_list(),
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

def _test_library_plugin_without_phase(test):
    (plugin, _) = plugin_for(
        test,
        name = "no_phase_plugin",
        id = "test.no_phase",
        compile_phase = False,
        stubs_phase = False,
    )

    got = test.got(
        kt_jvm_library,
        name = "got_library",
        srcs = [
            test.artifact(
                name = "got_library.kt",
            ),
        ],
        plugins = [plugin],
    )

    analysis_test(
        name = test.name,
        impl = _expect_failure_contains,
        expect_failure = True,
        target = got,
        attr_values = {
            "want_failure_substrings": [
                "has plugin without a phase defined:",
                "test.no_phase",
            ],
        },
        attrs = {
            "want_failure_substrings": attr.string_list(),
        },
    )

def test_suite(name):
    suite(
        name,
        test_kt_plugin_cfg = _test_kt_plugin_cfg,
        test_kt_plugin_cfg_multi_value_options = _test_kt_plugin_cfg_multi_value_options,
        test_compile_configuration = _test_compile_configuration,
        test_compile_configuration_inline_payload_json = _test_compile_configuration_inline_payload_json,
        test_library_multiple_plugins_with_same_id = _test_library_multiple_plugins_with_same_id,
        test_library_plugin_without_phase = _test_library_plugin_without_phase,
        test_compile_configuration_single_phase = _test_compile_configuration_single_phase,
        test_compile_multiple_configurations = _test_compile_multiple_configurations,
    )
