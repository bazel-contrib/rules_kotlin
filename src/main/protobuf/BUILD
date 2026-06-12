load("@com_google_protobuf//bazel:java_proto_library.bzl", "java_proto_library")
load("@com_google_protobuf//bazel:proto_library.bzl", "proto_library")
load("@rules_java//java:java_library.bzl", "java_library")

package(default_visibility = ["//visibility:public"])

proto_library(
    name = "deps_proto",
    srcs = [":deps.proto"],
)

java_proto_library(
    name = "deps_java_proto",
    deps = [":deps_proto"],
)

proto_library(
    name = "kotlin_model_proto",
    srcs = [":kotlin_model.proto"],
    visibility = ["//visibility:public"],
)

java_proto_library(
    name = "kotlin_model_java_proto",
    deps = [":kotlin_model_proto"],
)

java_library(
    name = "protobuf",
    exports = [
        ":deps_java_proto",
        ":kotlin_model_java_proto",
    ],
)
