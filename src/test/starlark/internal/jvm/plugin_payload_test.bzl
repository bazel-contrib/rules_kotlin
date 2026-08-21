load(
    "@bazel_skylib//lib:unittest.bzl",
    "asserts",
    "unittest",
)
load("//src/main/starlark/core/plugin:payload.bzl", "plugin_payload")

def _plugins_payload_json_encodes_empty_plugins_test_impl(ctx):
    env = unittest.begin(ctx)

    asserts.equals(
        env,
        {"plugins": []},
        json.decode(plugin_payload.plugins_payload_json([])),
    )

    return unittest.end(env)

plugins_payload_json_encodes_empty_plugins_test = unittest.make(
    _plugins_payload_json_encodes_empty_plugins_test_impl,
)

def _plugins_payload_json_encodes_populated_plugin_test_impl(ctx):
    env = unittest.begin(ctx)

    # Mirror the example parsed by PluginsPayloadParserTest.kt so the producer's emitted JSON
    # shape and the Kotlin proto/JsonFormat parser stay locked to the same contract: a drift in
    # either the JSON keys here or the proto field/enum names there breaks one of the two tests.
    plugin = struct(
        id = "plugin.test",
        classpath = depset([struct(path = "a.jar"), struct(path = "b.jar")]),
        options = [
            struct(key = "k1", value = "v1"),
            struct(key = "k2", value = "v2"),
        ],
        phases = ["compile", "stubs"],
    )

    decoded = json.decode(plugin_payload.plugins_payload_json([plugin]))

    asserts.equals(env, 1, len(decoded["plugins"]))
    plugin_json = decoded["plugins"][0]
    asserts.equals(env, "plugin.test", plugin_json["id"])
    asserts.equals(env, ["a.jar", "b.jar"], plugin_json["classpath"])
    asserts.equals(
        env,
        [{"key": "k1", "value": "v1"}, {"key": "k2", "value": "v2"}],
        plugin_json["options"],
    )

    # `phases` carries the proto enum *names* the JsonFormat parser maps to PluginPhase values.
    asserts.equals(env, ["PLUGIN_PHASE_COMPILE", "PLUGIN_PHASE_STUBS"], plugin_json["phases"])

    return unittest.end(env)

plugins_payload_json_encodes_populated_plugin_test = unittest.make(
    _plugins_payload_json_encodes_populated_plugin_test_impl,
)

def _plugins_payload_json_encodes_edge_options_test_impl(ctx):
    env = unittest.begin(ctx)

    # A value-less option must encode with an empty value (the worker re-emits it as a bare
    # "id:key" argument), and a value containing '=' must survive whole.
    plugin = struct(
        id = "plugin.edge",
        classpath = depset([struct(path = "p.jar")]),
        options = [
            struct(key = "flagOnly", value = ""),
            struct(key = "k", value = "a=b"),
        ],
        phases = ["compile"],
    )

    decoded = json.decode(plugin_payload.plugins_payload_json([plugin]))

    asserts.equals(
        env,
        [{"key": "flagOnly", "value": ""}, {"key": "k", "value": "a=b"}],
        decoded["plugins"][0]["options"],
    )

    return unittest.end(env)

plugins_payload_json_encodes_edge_options_test = unittest.make(
    _plugins_payload_json_encodes_edge_options_test_impl,
)

def plugin_payload_test_suite(name):
    unittest.suite(
        name,
        plugins_payload_json_encodes_empty_plugins_test,
        plugins_payload_json_encodes_populated_plugin_test,
        plugins_payload_json_encodes_edge_options_test,
    )
