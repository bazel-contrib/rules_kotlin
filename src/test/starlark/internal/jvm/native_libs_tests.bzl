load("@rules_cc//cc:defs.bzl", "cc_binary")
load("@rules_java//java:defs.bzl", "JavaInfo")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching", "subjects")
load("@rules_testing//lib:util.bzl", "util")
load("//kotlin:jvm.bzl", "kt_jvm_binary", "kt_jvm_library", "kt_jvm_test")

def _native_library(name, relative_name = "native"):
    target_name = name + "/" + relative_name
    util.helper_target(
        cc_binary,
        name = target_name,
        srcs = [util.empty_file(name + "_" + relative_name.replace("/", "_") + ".cc")],
        linkshared = True,
        linkstatic = True,
        tags = ["manual"],
    )
    return target_name

def _jvm_flags(env, target):
    executable = target[DefaultInfo].files_to_run.executable.short_path
    action = env.expect.that_target(target).action_generating(executable)
    if action.actual.substitutions:
        return action.substitutions().get(
            "%jvm_flags%",
            factory = lambda value, meta: subjects.collection([value], meta),
        )
    return action.argv()

def _native_runtime_dep_does_not_crash_test(name):
    native = _native_library(name)
    util.helper_target(
        kt_jvm_library,
        name = name + "/subject",
        srcs = [util.empty_file(name + "_Library.kt")],
        runtime_deps = [native],
        tags = ["manual"],
    )
    analysis_test(
        name = name,
        impl = _native_runtime_dep_does_not_crash_test_impl,
        target = name + "/subject",
    )

def _native_runtime_dep_does_not_crash_test_impl(env, target):
    env.expect.that_target(target).has_provider(JavaInfo)

def _binary_has_direct_native_library_path_test(name):
    native = _native_library(name)
    util.helper_target(
        kt_jvm_binary,
        name = name + "/subject",
        srcs = [util.empty_file(name + "_Main.kt")],
        main_class = "test.Main",
        runtime_deps = [native],
        tags = ["manual"],
    )
    analysis_test(
        name = name,
        impl = _binary_has_direct_native_library_path_test_impl,
        target = name + "/subject",
    )

def _binary_has_direct_native_library_path_test_impl(env, target):
    _jvm_flags(env, target).contains_predicate(
        matching.str_matches("*-Djava.library.path=*{}*".format(target.label.name.rpartition("/")[0])),
    )

def _test_has_direct_native_library_path_test(name):
    native = _native_library(name)
    util.helper_target(
        kt_jvm_test,
        name = name + "/subject",
        srcs = [util.empty_file(name + "_Test.kt")],
        test_class = "test.NativeLibraryPathTest",
        runtime_deps = [native],
        tags = ["manual"],
    )
    analysis_test(
        name = name,
        impl = _test_has_direct_native_library_path_test_impl,
        target = name + "/subject",
    )

def _test_has_direct_native_library_path_test_impl(env, target):
    _jvm_flags(env, target).contains_predicate(
        matching.str_matches("*-Djava.library.path=*{}*".format(target.label.name.rpartition("/")[0])),
    )

def _binary_has_transitive_native_library_path_test(name):
    native = _native_library(name)
    util.helper_target(
        kt_jvm_library,
        name = name + "/library",
        srcs = [util.empty_file(name + "_Library.kt")],
        runtime_deps = [native],
        tags = ["manual"],
    )
    util.helper_target(
        kt_jvm_binary,
        name = name + "/subject",
        srcs = [util.empty_file(name + "_Main.kt")],
        main_class = "test.Main",
        runtime_deps = [name + "/library"],
        tags = ["manual"],
    )
    analysis_test(
        name = name,
        impl = _binary_has_transitive_native_library_path_test_impl,
        target = name + "/subject",
    )

def _binary_has_transitive_native_library_path_test_impl(env, target):
    _jvm_flags(env, target).contains_predicate(
        matching.str_matches("*-Djava.library.path=*{}*".format(target.label.name.rpartition("/")[0])),
    )

def _native_library_path_uses_platform_separator_test(name):
    native_a = _native_library(name, "a/native")
    native_b = _native_library(name, "b/native")
    util.helper_target(
        kt_jvm_binary,
        name = name + "/subject",
        srcs = [util.empty_file(name + "_Main.kt")],
        main_class = "test.Main",
        runtime_deps = [native_a, native_b],
        tags = ["manual"],
    )
    analysis_test(
        name = name,
        impl = _native_library_path_uses_platform_separator_test_impl,
        target = name + "/subject",
    )

def _native_library_path_uses_platform_separator_test_impl(env, target):
    executable = target[DefaultInfo].files_to_run.executable.short_path
    separator = ";" if executable.endswith(".exe") else ":"
    _jvm_flags(env, target).contains_predicate(
        matching.str_matches("*-Djava.library.path=*{0}/a*{1}*{0}/b*".format(target.label.name.rpartition("/")[0], separator)),
    )

def native_libs_test_suite(name):
    test_suite(
        name = name,
        tests = [
            _native_runtime_dep_does_not_crash_test,
            _binary_has_direct_native_library_path_test,
            _test_has_direct_native_library_path_test,
            _binary_has_transitive_native_library_path_test,
            _native_library_path_uses_platform_separator_test,
        ],
    )
