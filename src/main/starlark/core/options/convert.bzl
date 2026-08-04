"""Converts option structs into compiler flag lists."""

load("//src/main/starlark/core/options:derive.bzl", "derive")

def _to_flags(opts, attr_provider):
    """Translate options to flags

    Args:
        opts dict of name to struct
        attr options provider
    Returns:
        list of flags to add to the command line.
    """
    if not attr_provider:
        return ""

    flags = []
    for n, o in opts.items():
        value = getattr(attr_provider, n, None)
        if o.value_to_flag and o.value_to_flag.get(derive.info, None):
            info = o.value_to_flag[derive.info]
            flag = info.derive(info.ctx, value or o.args.get("default", None))
        elif o.value_to_flag:
            flag = o.value_to_flag.get(value, None)
        else:
            flag = o.map_value_to_flag(value)
        if flag:
            flags.extend(flag)
    return flags

convert = struct(
    kotlinc_options_to_flags = _to_flags,
    javac_options_to_flags = _to_flags,
)
