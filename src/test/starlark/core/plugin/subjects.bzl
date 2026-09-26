"""Truth subject factories for plugin-provider assertions."""

load("@rules_testing//lib:truth.bzl", "subjects")

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
