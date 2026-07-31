load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@rules_java//java:defs.bzl", "JavaInfo")
load("//kotlin:jvm.bzl", "kt_jvm_import", "kt_jvm_library")

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

def sourceless_library_test_suite(name):
    _sourceless_library_contents()

    native.test_suite(
        name = name,
        tests = [
            ":sourceless_library_forwards_runtime_deps_test",
        ],
    )
