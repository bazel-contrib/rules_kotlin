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

# The embeddable-dialect variants of the builder's compiler plugins the Build Tools API runtime uses.
# (see the btapi_*/internal_* toolchain attributes)
jar_jar(
    name = "jdeps-gen-embeddable",
    input_jar = "//src/main/kotlin/io/bazel/kotlin/plugin/jdeps:jdeps-gen_deploy.jar",
    rules = "shade.embeddable.jarjar",
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

release_archive(
    name = "pkg",
    package_dir = "src/main/kotlin",  # explicitly set the package directory, as there are no parent release_archives.
    src_map = {
        "BUILD.release.bazel": "BUILD.bazel",
    },
    deps = [
        "//src/main/kotlin/io/bazel/kotlin/compiler:pkg",
    ],
)

# The prebuilt jars are published as a separate release asset instead of being part of the source
# archive. MODULE.release.bazel only downloads them when Kotlin code is compiled.
release_archive(
    name = "rules_kotlin_jars",
    extension = "tar.gz",
    package_dir = "",
    src_map = {
        ":jdeps-gen.jar": "jdeps-gen.jar",
        ":jdeps-gen-embeddable.jar": "jdeps-gen-embeddable.jar",
        "//src/main/kotlin/io/bazel/kotlin/builder/cmd:build_deploy.jar": "kotlin_worker.jar",
        "//src/main/kotlin/io/bazel/kotlin/builder/cmd:ksp2_deploy.jar": "ksp2_worker.jar",
        "//src/main/kotlin/io/bazel/kotlin/builder/cmd:merge_jdeps_deploy.jar": "jdeps_merger_worker.jar",
        "//src/main/kotlin/io/bazel/kotlin/compiler:compiler.jar": "compiler.jar",
        "//src/main/kotlin/io/bazel/kotlin/ksp2:ksp2.jar": "ksp2_invoker.jar",
    },
)
