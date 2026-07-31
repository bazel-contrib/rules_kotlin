load("@rules_java//java:defs.bzl", "java_library")
load("//third_party:jarjar.bzl", "jar_jar")

# Fixtures for the compiler-dialect re-shading rules: one jar with classes in every package the
# rules touch, re-shaded once per rule set. The tests read the entry names and the class-file
# references of the results.
package(default_visibility = ["//visibility:private"])

java_library(
    name = "dialect_fixture",
    srcs = glob(["**/*.java"]),
)

jar_jar(
    name = "dialect_fixture_embeddable_reshaded",
    input_jar = ":libdialect_fixture.jar",
    rules = "//kotlin/internal/jvm:kotlin-compiler-embeddable-reshade.jarjar",
)

jar_jar(
    name = "dialect_fixture_dist_reshaded",
    input_jar = ":libdialect_fixture.jar",
    rules = "//kotlin/internal/jvm:kotlin-compiler-reshade.jarjar",
)

filegroup(
    name = "reshade",
    srcs = [
        ":dialect_fixture_dist_reshaded",
        ":dialect_fixture_embeddable_reshaded",
    ],
    visibility = ["//visibility:public"],
)
