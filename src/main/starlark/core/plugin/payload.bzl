"""The compiler plugins of a compilation as the `--plugins_payload` value the builder reads."""

# The PluginPhase enum value of each phase name the rules use. Starlark cannot read the proto definition;
# PluginsPayloadPhaseNamesTest checks that the values of this table are the constants of the enum.
_PLUGIN_PHASES = {
    "compile": "PLUGIN_PHASE_COMPILE",
    "stubs": "PLUGIN_PHASE_STUBS",
}

# The enum-typed fields of a plugin message and their values.
_ENUM_FIELDS = {
    "phases": _PLUGIN_PHASES.values(),
}

def _phase_to_proto_enum_name(phase):
    if phase not in _PLUGIN_PHASES:
        fail("Unknown compiler plugin phase: %s" % phase)
    return _PLUGIN_PHASES[phase]

def _plugin_to_struct(plugin):
    return struct(
        classpath = [entry.path for entry in plugin.classpath.to_list()],
        id = plugin.id,
        options = [struct(key = option.key, value = option.value) for option in plugin.options],
        phases = [_phase_to_proto_enum_name(phase) for phase in plugin.phases],
    )

def _one_line(text):
    """Joins the lines of the encoder's output into one, with the values of the enum fields as bare identifiers.

    The encoder writes one field per line and escapes newlines inside string values, so a line that reads
    `phases: "NAME"` is that field and nothing else.
    """
    lines = []
    for line in text.split("\n"):
        line = line.strip()
        if not line:
            continue

        # proto.encode_text writes every string in quotes, and the TextFormat expects a bare identifier, so the enum values are to be unquoted.
        for field, names in _ENUM_FIELDS.items():
            for name in names:
                if line == '%s: "%s"' % (field, name):
                    line = "%s: %s" % (field, name)
        lines.append(line)
    return " ".join(lines)

def _plugin_payload_text(plugins):
    """The plugins as a `JvmCompilationTask.Inputs` message in protobuf text format, on one line.

    Args:
        plugins: the compiler plugin structs of the compilation.

    Returns:
        One `plugins { ... }` message per plugin, or None when there are no plugins, which omits the flag.
    """
    if not plugins:
        return None
    return _one_line(proto.encode_text(struct(plugins = [_plugin_to_struct(plugin) for plugin in plugins])))

plugin_payload = struct(
    plugin_phases = _PLUGIN_PHASES,
    text = _plugin_payload_text,
)
