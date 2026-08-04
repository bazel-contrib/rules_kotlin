"""Defines ktlint_config rule and its provider."""

KtlintConfigInfo = provider(
    doc = "Configuration for running ktlint, including editorconfig and rule toggles.",
    fields = {
        "android_rules_enabled": "Turn on Android Kotlin Style Guide compatibility",
        "editorconfig": "Editor config file to use",
        "experimental_rules_enabled": "Turn on experimental rules (ktlint-ruleset-experimental)",
    },
)

def _ktlint_config_impl(ctx):
    return [
        KtlintConfigInfo(
            editorconfig = ctx.file.editorconfig,
            android_rules_enabled = ctx.attr.android_rules_enabled,
            experimental_rules_enabled = ctx.attr.experimental_rules_enabled,
        ),
    ]

ktlint_config = rule(
    _ktlint_config_impl,
    attrs = {
        "android_rules_enabled": attr.bool(
            doc = "Turn on Android Kotlin Style Guide compatibility",
            default = False,
        ),
        "editorconfig": attr.label(
            doc = "Editor config file to use",
            mandatory = False,
            allow_single_file = True,
        ),
        "experimental_rules_enabled": attr.bool(
            doc = "Turn on experimental rules (ktlint-ruleset-experimental)",
            default = False,
        ),
    },
    doc = """Used to configure ktlint.

    `ktlint` can be configured to use a `.editorconfig`, as documented at
    https://github.com/pinterest/ktlint/#editorconfig""",
)
