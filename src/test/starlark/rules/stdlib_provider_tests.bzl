"""Tests for the toolchain stdlibs: the full class jar on the classpath, the source jar kept."""

load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:truth.bzl", "matching")
load("//src/test/starlark:case.bzl", "suite")
load(":arrangement.bzl", "arrange")

_TOOLCHAIN = str(Label("@rules_kotlin//src/test/starlark/rules:stdlib_sources_toolchain"))
_CLASS_JAR = "stdlib-fixture.jar"
_SOURCE_JAR = "stdlib-fixture-sources.jar"

def _basenames(files):
    return [f.basename for f in files.to_list()]

def _toolchain_assertion(env, target):
    stdlibs = target[platform_common.ToolchainInfo].jvm_stdlibs

    # The full class jar is the compile jar; the source jar travels with it.
    env.expect.that_collection(_basenames(stdlibs.compile_jars)).contains_exactly([_CLASS_JAR])
    env.expect.that_collection(_basenames(stdlibs.full_compile_jars)).contains_exactly([_CLASS_JAR])
    env.expect.that_collection(_basenames(stdlibs.transitive_source_jars)).contains_exactly([_SOURCE_JAR])

    # jvm_runtime puts the class jar on the runtime classpath; jvm_stdlibs alone would not.
    env.expect.that_collection(_basenames(stdlibs.transitive_runtime_jars)).contains_exactly([_CLASS_JAR])

def _library_assertion(env, target):
    # The compiled target inherits the stdlib source jar through JavaInfo, and the compile action
    # reads the class jar only.
    env.expect.that_collection(_basenames(target[JavaInfo].transitive_source_jars)).contains(_SOURCE_JAR)
    inputs = env.expect.that_target(target).action_named("KotlinCompile").inputs()
    inputs.contains_predicate(matching.file_basename_equals(_CLASS_JAR))
    inputs.not_contains_predicate(matching.file_basename_equals(_SOURCE_JAR))

def _toolchain_case(test):
    analysis_test(
        name = test.name,
        impl = _toolchain_assertion,
        target = _TOOLCHAIN + "_impl",
    )

def _library_case(test):
    (_dependency_a_trans_dep_jar, _dependency_a, main_target_library) = arrange(test)
    analysis_test(
        name = test.name,
        impl = _library_assertion,
        target = main_target_library,
        config_settings = {
            "//command_line_option:extra_toolchains": [_TOOLCHAIN],
        },
    )

def stdlib_provider_tests(name):
    suite(
        name,
        toolchain_keeps_the_stdlib_source_jar = _toolchain_case,
        library_inherits_the_stdlib_source_jar = _library_case,
    )
