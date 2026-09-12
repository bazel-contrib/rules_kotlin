load("@rules_java//java:defs.bzl", "java_library", "java_plugin")

java_plugin(
    name = "dagger_component_plugin",
    generates_api = 1,
    processor_class = "dagger.internal.codegen.ComponentProcessor",
    visibility = ["//visibility:private"],
    deps = [
        "@kotlin_rules_maven_test//:com_google_dagger_dagger_compiler",
    ],
)

java_library(
    name = "dagger",
    exported_plugins = [":dagger_component_plugin"],
    visibility = ["//src/test:__subpackages__"],
    exports = [
        "@kotlin_rules_maven_test//:com_google_dagger_dagger",
        "@kotlin_rules_maven_test//:javax_inject_javax_inject",
    ],
)

java_plugin(
    name = "autovalue_plugin",
    generates_api = 1,
    processor_class = "com.google.auto.value.processor.AutoValueProcessor",
    visibility = ["//visibility:private"],
    deps = ["@kotlin_rules_maven_test//:com_google_auto_value_auto_value"],
)

java_library(
    name = "autovalue",
    exported_plugins = [":autovalue_plugin"],
    neverlink = 1,
    visibility = ["//src/test:__subpackages__"],
    exports = ["@kotlin_rules_maven_test//:com_google_auto_value_auto_value_annotations"],
)
