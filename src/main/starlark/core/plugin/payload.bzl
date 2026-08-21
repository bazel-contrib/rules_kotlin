def _phase_to_proto_enum_name(phase):
    if phase == "compile":
        return "PLUGIN_PHASE_COMPILE"
    if phase == "stubs":
        return "PLUGIN_PHASE_STUBS"
    fail("Unknown compiler plugin phase: %s" % phase)

def _plugin_to_json(plugin):
    return {
        "classpath": [entry.path for entry in plugin.classpath.to_list()],
        "id": plugin.id,
        "options": [
            {
                "key": option.key,
                "value": option.value,
            }
            for option in plugin.options
        ],
        "phases": [_phase_to_proto_enum_name(phase) for phase in plugin.phases],
    }

def _plugins_payload_json(plugins):
    return json.encode({
        "plugins": [_plugin_to_json(plugin) for plugin in plugins],
    })

plugin_payload = struct(
    plugins_payload_json = _plugins_payload_json,
)
