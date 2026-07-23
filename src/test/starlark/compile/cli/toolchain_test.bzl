"""Analysis tests for the cli_toolchain rule (attribute -> toolchain info wiring)."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@rules_shell//shell:sh_binary.bzl", "sh_binary")
load("//src/main/starlark/core/compile/cli:toolchain.bzl", "COMPILE_MNEMONIC", "cli_toolchain")

def _toolchain_attrs_test_impl(ctx):
    env = analysistest.begin(ctx)

    target = analysistest.target_under_test(env)
    info = target[platform_common.ToolchainInfo]._toolchain_info

    # Every string attribute is given a distinct value, so a field read from
    # the wrong attribute fails its assertion.
    asserts.equals(env, "17", info.jvm_target)

    # "2.0.30" and "2.1.20" truncated to the major.minor form kotlinc accepts.
    asserts.equals(env, "2.0", info.api_version)
    asserts.equals(env, "2.1", info.language_version)

    asserts.true(
        env,
        info.kotlinc.executable.basename.startswith("fake_kotlinc"),
        "kotlinc executable %s should come from the kotlinc attribute" % info.kotlinc.executable.basename,
    )
    asserts.true(
        env,
        info.executable_zip.executable.basename.startswith("zipper"),
        "zip executable %s should come from the zip attribute" % info.executable_zip.executable.basename,
    )
    asserts.equals(env, "java_stub_template.txt", info.java_stub_template.basename)
    asserts.equals(env, "empty.jar", info.empty_jar.basename)

    stdlib_jars = [
        jar.basename
        for jar in info.kotlin_stdlib.transitive_compile_time_jars.to_list()
    ]
    asserts.true(
        env,
        len([jar for jar in stdlib_jars if jar.startswith("kotlin-stdlib")]) > 0,
        "kotlin_stdlib jars %s should come from the kotlin_stdlibs attribute" % stdlib_jars,
    )

    asserts.equals(env, COMPILE_MNEMONIC, info.compile_mnemonic)

    return analysistest.end(env)

toolchain_attrs_test = analysistest.make(_toolchain_attrs_test_impl)

def cli_toolchain_test_suite(name):
    write_file(
        name = "fake_kotlinc_sh",
        out = "fake_kotlinc.sh",
        content = [
            "#!/bin/sh",
            "exit 0",
        ],
        tags = ["manual"],
    )

    sh_binary(
        name = "fake_kotlinc",
        srcs = ["fake_kotlinc.sh"],
        tags = ["manual"],
    )

    cli_toolchain(
        name = "toolchain_under_test",
        api_version = "2.0.30",
        jvm_target = "17",
        kotlin_stdlibs = ["//kotlin/compiler:kotlin-stdlib"],
        kotlinc = ":fake_kotlinc",
        language_version = "2.1.20",
        tags = ["manual"],
        zip = "@bazel_tools//tools/zip:zipper",
    )

    toolchain_attrs_test(
        name = "toolchain_attrs_test",
        target_under_test = ":toolchain_under_test",
    )

    native.test_suite(
        name = name,
        tests = [":toolchain_attrs_test"],
    )
