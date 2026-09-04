"""Truth subject factories for compile-rule assertions."""

load("@rules_testing//lib:truth.bzl", "subjects")

def java_info_subject_factory(value, meta):
    return subjects.struct(
        value,
        meta = meta.derive("JavaInfo"),
        attrs = {
            "java_outputs": subjects.collection,
            "source_jars": subjects.collection,
            "transitive_compile_time_jars": subjects.depset_file,
            "transitive_runtime_jars": subjects.depset_file,
        },
    )
