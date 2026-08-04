"""Utilities for deriving compiler flags from option values."""

_value_to_flag_info = provider(
    doc = "Binds a derive callable to context for turning an option value into compiler flags.",
    fields = {
        "ctx": "_derive_flag_ctx",
        "derive": "Callable(ctx, value) -> List[str] ",
    },
)

_derive_flag_ctx = provider(
    doc = "Context carrying the compiler flag name used when deriving flags from a value.",
    fields = {"name": "flag name for the compiler"},
)

def _derive_repeated_flag(ctx, value):
    return ["%s%s" % (ctx.name, v) for v in value]

def _repeated_values_for(name):
    return _value_to_flag_info(
        ctx = _derive_flag_ctx(name = name),
        derive = _derive_repeated_flag,
    )

def _format_key_value_for(name, template):
    def _format(ctx, kv_dict):
        return [
            template.format(name = ctx.name, key = k, value = v)
            for (k, v) in kv_dict.items()
        ]

    return _value_to_flag_info(
        ctx = _derive_flag_ctx(name = name),
        derive = _format,
    )

derive = struct(
    info = _value_to_flag_info,
    repeated_values_for = _repeated_values_for,
    format_key_value_for = _format_key_value_for,
)
