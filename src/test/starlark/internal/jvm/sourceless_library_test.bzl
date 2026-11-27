"""Tests that a sourceless kt_jvm_library forwards its runtime_deps and analyzes with an annotation processor."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@rules_java//java:defs.bzl", "JavaInfo", "java_plugin")
load("//kotlin:core.bzl", "kt_ksp_plugin")
load("//kotlin:jvm.bzl", "kt_jvm_import", "kt_jvm_library")
load("//src/main/starlark/core/compile:common.bzl", "KtJvmInfo")

def _sourceless_library_runtime_deps_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    # The runtime dep must flow to the sourceless library's transitive runtime classpath, exactly
    # as it does for a compiled library.
    runtime_jars = [jar.basename for jar in target[JavaInfo].transitive_runtime_jars.to_list()]
    asserts.true(
        env,
        "sourceless_library_dep.jar" in runtime_jars,
        msg = "expected the runtime dep jar on the transitive runtime classpath, got %s" % runtime_jars,
    )

    # A runtime dep grants no compile-time visibility of any kind.
    compile_jars = [jar.basename for jar in target[JavaInfo].compile_jars.to_list()]
    asserts.false(
        env,
        "sourceless_library_dep.jar" in compile_jars,
        msg = "the runtime dep jar must not be exported as a direct compile jar: %s" % compile_jars,
    )

    transitive_compile_jars = [jar.basename for jar in target[JavaInfo].transitive_compile_time_jars.to_list()]
    asserts.false(
        env,
        "sourceless_library_dep.jar" in transitive_compile_jars,
        msg = "the runtime dep jar must not be on the transitive compile-time classpath: %s" % transitive_compile_jars,
    )

    return analysistest.end(env)

_sourceless_library_runtime_deps_test = analysistest.make(_sourceless_library_runtime_deps_test_impl)

def _sourceless_library_annotation_processor_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    # The library compiles nothing, so no annotation processor runs.
    asserts.equals(
        env,
        None,
        target[KtJvmInfo].annotation_processing,
        msg = "a library without sources must not report annotation processing",
    )

    return analysistest.end(env)

_sourceless_library_annotation_processor_test = analysistest.make(_sourceless_library_annotation_processor_test_impl)

def _sourceless_library_contents():
    write_file(
        name = "sourceless_library_dep_jar",
        out = "sourceless_library_dep.jar",
        tags = ["manual"],
    )

    kt_jvm_import(
        name = "sourceless_library_dep",
        jars = ["sourceless_library_dep.jar"],
        tags = ["manual"],
    )

    kt_jvm_library(
        name = "sourceless_library",
        srcs = [],
        runtime_deps = [":sourceless_library_dep"],
        tags = ["manual"],
    )

    _sourceless_library_runtime_deps_test(
        name = "sourceless_library_forwards_runtime_deps_test",
        target_under_test = ":sourceless_library",
    )

    write_file(
        name = "sourceless_library_resource",
        out = "sourceless_library_resource.txt",
        tags = ["manual"],
    )

    write_file(
        name = "sourceless_library_resource_jar",
        out = "sourceless_library_resources.jar",
        tags = ["manual"],
    )

    java_plugin(
        name = "sourceless_library_java_processor",
        processor_class = "com.google.auto.value.processor.AutoValueProcessor",
        tags = ["manual"],
        deps = ["@kotlin_rules_maven//:com_google_auto_value_auto_value"],
    )

    kt_ksp_plugin(
        name = "sourceless_library_ksp_processor",
        processor_class = "com.squareup.moshi.kotlin.codegen.ksp.JsonClassSymbolProcessorProvider",
        tags = ["manual"],
        deps = [
            "@kotlin_rules_maven_test//:com_squareup_moshi_moshi",
            "@kotlin_rules_maven_test//:com_squareup_moshi_moshi_kotlin",
            "@kotlin_rules_maven_test//:com_squareup_moshi_moshi_kotlin_codegen",
        ],
    )

    # The libraries below run the compile engine for their resources, with nothing to compile.
    kt_jvm_library(
        name = "sourceless_resource_jars_library_with_java_processor",
        srcs = [],
        plugins = [":sourceless_library_java_processor"],
        resource_jars = [":sourceless_library_resource_jar"],
        tags = ["manual"],
    )

    kt_jvm_library(
        name = "sourceless_resource_jars_library_with_ksp_processor",
        srcs = [],
        plugins = [":sourceless_library_ksp_processor"],
        resource_jars = [":sourceless_library_resource_jar"],
        tags = ["manual"],
    )

    kt_jvm_library(
        name = "sourceless_resources_library_with_java_processor",
        srcs = [],
        plugins = [":sourceless_library_java_processor"],
        resources = [":sourceless_library_resource"],
        tags = ["manual"],
    )

    _sourceless_library_annotation_processor_test(
        name = "sourceless_resource_jars_library_with_java_processor_test",
        target_under_test = ":sourceless_resource_jars_library_with_java_processor",
    )

    _sourceless_library_annotation_processor_test(
        name = "sourceless_resource_jars_library_with_ksp_processor_test",
        target_under_test = ":sourceless_resource_jars_library_with_ksp_processor",
    )

    _sourceless_library_annotation_processor_test(
        name = "sourceless_resources_library_with_java_processor_test",
        target_under_test = ":sourceless_resources_library_with_java_processor",
    )

def sourceless_library_test_suite(name):
    _sourceless_library_contents()

    native.test_suite(
        name = name,
        tests = [
            ":sourceless_library_forwards_runtime_deps_test",
            ":sourceless_resource_jars_library_with_java_processor_test",
            ":sourceless_resource_jars_library_with_ksp_processor_test",
            ":sourceless_resources_library_with_java_processor_test",
        ],
    )
