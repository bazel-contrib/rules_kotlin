load(
    "@bazel_skylib//lib:unittest.bzl",
    "asserts",
    "unittest",
)
load("//src/main/starlark/core/plugin:payload.bzl", "plugin_payload")
load("//src/test/starlark:truth.bzl", "parse_payload_plugins")

def _plugin_payload_text_omits_empty_plugins_test_impl(ctx):
    env = unittest.begin(ctx)

    # None makes args.add_all omit --plugins_payload; the builder then compiles without plugins.
    asserts.equals(env, None, plugin_payload.text([]))

    return unittest.end(env)

plugin_payload_text_omits_empty_plugins_test = unittest.make(
    _plugin_payload_text_omits_empty_plugins_test_impl,
)

def _plugin_payload_text_encodes_populated_plugin_test_impl(ctx):
    env = unittest.begin(ctx)

    # Mirror the line parsed by PluginsPayloadParserTest.kt so the producer's output and the
    # Kotlin TextFormat parser stay locked to the same contract: a drift in either the text here
    # or the proto field and enum names there breaks one of the two tests. The encoder sorts the
    # fields of a message by name; the phases stand unquoted.
    plugin = struct(
        id = "plugin.test",
        classpath = depset([struct(path = "a.jar"), struct(path = "b.jar")]),
        options = [
            struct(key = "k1", value = "v1"),
            struct(key = "k2", value = "v2"),
        ],
        phases = ["compile", "stubs"],
    )

    asserts.equals(
        env,
        'plugins { classpath: "a.jar" classpath: "b.jar" id: "plugin.test" ' +
        'options { key: "k1" value: "v1" } options { key: "k2" value: "v2" } ' +
        "phases: PLUGIN_PHASE_COMPILE phases: PLUGIN_PHASE_STUBS }",
        plugin_payload.text([plugin]),
    )

    return unittest.end(env)

plugin_payload_text_encodes_populated_plugin_test = unittest.make(
    _plugin_payload_text_encodes_populated_plugin_test_impl,
)

def _plugin_payload_text_encodes_edge_options_test_impl(ctx):
    env = unittest.begin(ctx)

    # A value-less option must encode with an empty value (the worker re-emits it as a bare
    # "id:key" argument), a value containing '=' must survive whole, quotes and backslashes are
    # escaped, and a newline in a value is escaped so that the payload stays one line. The test
    # helper reads the line back to the structure the producer encoded.
    plugin = struct(
        id = "plugin.edge",
        classpath = depset([struct(path = "p.jar")]),
        options = [
            struct(key = "flagOnly", value = ""),
            struct(key = "k", value = "a=b"),
            struct(key = "q", value = 'q"uo\\te'),
            struct(key = "n", value = "a\nb"),
        ],
        phases = ["compile"],
    )

    text = plugin_payload.text([plugin])

    asserts.equals(
        env,
        'plugins { classpath: "p.jar" id: "plugin.edge" options { key: "flagOnly" value: "" } ' +
        'options { key: "k" value: "a=b" } options { key: "q" value: "q\\"uo\\\\te" } ' +
        'options { key: "n" value: "a\\nb" } phases: PLUGIN_PHASE_COMPILE }',
        text,
    )
    asserts.equals(
        env,
        [{
            "classpath": ["p.jar"],
            "id": "plugin.edge",
            "options": [
                {"key": "flagOnly", "value": ""},
                {"key": "k", "value": "a=b"},
                {"key": "q", "value": 'q"uo\\te'},
                {"key": "n", "value": "a\nb"},
            ],
            "phases": ["PLUGIN_PHASE_COMPILE"],
        }],
        parse_payload_plugins(text),
    )

    return unittest.end(env)

plugin_payload_text_encodes_edge_options_test = unittest.make(
    _plugin_payload_text_encodes_edge_options_test_impl,
)

def plugin_payload_test_suite(name):
    unittest.suite(
        name,
        plugin_payload_text_omits_empty_plugins_test,
        plugin_payload_text_encodes_populated_plugin_test,
        plugin_payload_text_encodes_edge_options_test,
    )
