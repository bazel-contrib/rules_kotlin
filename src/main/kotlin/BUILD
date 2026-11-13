load("@rules_java//java:defs.bzl", "java_binary")
load("//src/main/starlark/release:packager.bzl", "release_archive")
load("//third_party:jarjar.bzl", "jar_jar")

exports_files(
    ["shade.jarjar"],
    visibility = ["//src:__subpackages__"],
)

jar_jar(
    name = "jdeps-gen",
    input_jar = "//src/main/kotlin/io/bazel/kotlin/plugin/jdeps:jdeps-gen_deploy.jar",
    rules = "shade.jarjar",
    visibility = ["//visibility:public"],
)

jar_jar(
    name = "jdeps-gen-embeddable",
    input_jar = ":jdeps-gen.jar",
    rules = "//kotlin/internal/jvm:kotlin-compiler-embeddable-reshade.jarjar",
    visibility = ["//visibility:public"],
)

alias(
    name = "build",
    actual = "//src/main/kotlin/io/bazel/kotlin/builder/cmd:build",
    visibility = ["//visibility:public"],
)

alias(
    name = "jdeps_merger",
    actual = "//src/main/kotlin/io/bazel/kotlin/builder/cmd:merge_jdeps",
    visibility = ["//visibility:public"],
)

alias(
    name = "ksp2",
    actual = "//src/main/kotlin/io/bazel/kotlin/builder/cmd:ksp2",
    visibility = ["//visibility:public"],
)

alias(
    name = "ksp2_invoker",
    actual = "//src/main/kotlin/io/bazel/kotlin/ksp2",
    visibility = ["//visibility:public"],
)

java_binary(
    name = "rules_kotlin_raw",
    create_executable = False,
    runtime_deps = [
        "//src/main/kotlin/io/bazel/kotlin/builder/cmd:build_lib",
        "//src/main/kotlin/io/bazel/kotlin/builder/cmd:ksp2_lib",
        "//src/main/kotlin/io/bazel/kotlin/builder/cmd:merge_jdeps_lib",
        "//src/main/kotlin/io/bazel/kotlin/compiler",
        "//src/main/kotlin/io/bazel/kotlin/ksp2",
        "//src/main/kotlin/io/bazel/kotlin/plugin/jdeps:jdeps-gen-lib",
        "//src/main/kotlin/io/bazel/kotlin/plugin/jdeps:jdeps-gen-services",
    ],
)

jar_jar(
    name = "rules_kotlin",
    input_jar = ":rules_kotlin_raw_deploy.jar",
    rules = "shade.jarjar",
)

release_archive(
    name = "pkg",
    srcs = [":rules_kotlin.jar"],
    package_dir = "src/main/kotlin",  # explicitly set the package directory, as there are no parent release_archives.
    src_map = {
        "BUILD.release.bazel": "BUILD.bazel",
    },
    deps = [
        "//src/main/kotlin/io/bazel/kotlin/compiler:pkg",
    ],
)
