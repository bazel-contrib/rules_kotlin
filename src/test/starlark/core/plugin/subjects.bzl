"""Truth subject factories for plugin-provider assertions."""

load("@rules_testing//lib:truth.bzl", "subjects")

def plugin_option_subject_factory(value, meta):
    return subjects.struct(
        value,
        meta = meta.derive("option"),
        attrs = {
            "id": subjects.str,
            "value": subjects.str,
        },
    )

def plugin_subject_factory(value, meta):
    return subjects.struct(
        value,
        meta = meta,
        attrs = {
            "classpath": subjects.collection,
            "compile": subjects.bool,
            "id": subjects.str,
            "options": subjects.collection,
            "plugin_jars": subjects.collection,
            "stubs": subjects.bool,
        },
    )

def plugin_configuration_subject_factory(value, meta):
    return subjects.struct(
        value,
        meta = meta,
        attrs = {
            "classpath": subjects.collection,
            "data": subjects.collection,
            "id": subjects.str,
            "options": subjects.collection,
        },
    )
