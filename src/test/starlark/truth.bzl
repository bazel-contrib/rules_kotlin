"""
Collection of utility functions for the action subject
"""

def fail_messages_in(target_subject):
    return target_subject.failures().transform(
        desc = "failure.message",
        map_each = lambda f: f.partition("Error in fail:")[2].strip() if "Error in fail:" in f else f,
    )

def flags_and_values_of(action_subject):
    return action_subject.argv().transform(desc = "parsed()", loop = _action_subject_parse_flags)

def payload_plugins_of(action_subject):
    """The --plugins_payload plugins, one normalized string per plugin."""
    return action_subject.argv().transform(
        desc = "plugins payload plugins",
        loop = _action_subject_parse_payload_plugins,
    )

def _action_subject_parse_payload_plugins(argv):
    if argv == None:
        return []
    payload = None
    for i, arg in enumerate(argv):
        if arg == "--plugins_payload" and i + 1 < len(argv):
            payload = argv[i + 1]
            break
    if payload == None:
        return []
    return [
        "id={id} classpath=[{classpath}] phases=[{phases}] options=[{options}]".format(
            id = plugin["id"],
            classpath = ",".join([entry.rsplit("/", 1)[-1] for entry in plugin["classpath"]]),
            phases = ",".join(plugin["phases"]),
            options = ",".join(["%s=%s" % (o["key"], o["value"]) for o in plugin["options"]]),
        )
        for plugin in parse_payload_plugins(payload)
    ]

def _text_format_tokens(text):
    """Splits one line of protobuf text format into tokens: field names, `{`, `}`, `:` and quoted strings."""
    tokens = []
    current = ""
    in_string = False
    escaped = False
    for ch in text.elems():
        if in_string:
            current += ch
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                tokens.append(current)
                current = ""
                in_string = False
        elif ch == '"':
            if current:
                tokens.append(current)
            current = ch
            in_string = True
        elif ch in " \t\n":
            if current:
                tokens.append(current)
            current = ""
        elif ch in "{}:":
            if current:
                tokens.append(current)
            current = ""
            tokens.append(ch)
        else:
            current += ch
    if current:
        tokens.append(current)
    return tokens

def parse_payload_plugins(text):
    """Reads the `--plugins_payload` text format back into one dict per plugin.

    The producer (payload.bzl) writes `plugins { classpath: "..." id: "..." options { key: "..." value: "..." }
    phases: NAME }` messages on one line; its string literals escape backslashes, quotes and newlines the way JSON
    does, which json.decode reverses.

    Args:
        text: the payload.

    Returns:
        A list of dicts with the keys id, classpath, options (dicts with key and value) and phases (enum names).
    """
    plugins = []
    plugin = None
    option = None
    field = None
    for token in _text_format_tokens(text):
        if token == ":":
            continue
        if token == "{":
            if plugin == None:
                plugin = {"classpath": [], "id": "", "options": [], "phases": []}
            elif field == "options":
                option = {"key": "", "value": ""}
            field = None
        elif token == "}":
            if option != None:
                plugin["options"].append(option)
                option = None
            else:
                plugins.append(plugin)
                plugin = None
            field = None
        elif token.startswith('"'):
            value = json.decode(token)
            if option != None:
                option[field] = value
            elif field == "classpath":
                plugin["classpath"].append(value)
            else:
                plugin[field] = value
            field = None
        elif field == "phases":
            plugin["phases"].append(token)
            field = None
        else:
            field = token
    return plugins

def _action_subject_parse_flags(argv):
    parsed_flags = {}

    # argv might be none for e.g. builtin actions
    if argv == None:
        return parsed_flags
    last_flag = None
    for arg in argv:
        value = None
        if arg == "--":
            # skip the rest of the arguments, this is standard end of the flags.
            break
        if arg.startswith("-"):
            if "=" in arg:
                last_flag, value = arg.split("=", 1)
            else:
                last_flag = arg
        elif last_flag:
            # have a flag, therefore this is probably an associated argument
            value = arg
        else:
            # skip non-flag arguments
            continue

        # only set the value if it exists
        if value:
            parsed_flags.setdefault(last_flag, []).append(value)
    return parsed_flags.items()
