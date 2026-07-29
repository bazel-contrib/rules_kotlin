load("@rules_cc//cc:defs.bzl", "cc_binary")
load("@rules_java//java:defs.bzl", "JavaInfo")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("@rules_testing//lib:truth.bzl", "subjects")
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

def _native_library_path(env, target):
    flags = [
        value
        for value in _jvm_flags(env, target).actual
        if "-Djava.library.path=" in value
    ]
    env.expect.that_bool(bool(flags)).equals(True)

    library_path = "\n".join(flags)
    executable = target[DefaultInfo].files_to_run.executable.short_path
    if executable.endswith(".exe"):
        env.expect.that_bool("${JAVA_RUNFILES}" not in library_path).equals(True)
    return library_path

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
    env.expect.that_str(_native_library_path(env, target)).contains(target.label.name.rpartition("/")[0])

def _binary_accepts_native_library_in_deps_test(name):
    native = _native_library(name)
    util.helper_target(
        kt_jvm_binary,
        name = name + "/subject",
        srcs = [util.empty_file(name + "_Main.kt")],
        deps = [native],
        main_class = "test.Main",
        tags = ["manual"],
    )
    analysis_test(
        name = name,
        impl = _binary_accepts_native_library_in_deps_test_impl,
        target = name + "/subject",
    )

def _binary_accepts_native_library_in_deps_test_impl(env, target):
    env.expect.that_str(_native_library_path(env, target)).contains(target.label.name.rpartition("/")[0])

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
    env.expect.that_str(_native_library_path(env, target)).contains(target.label.name.rpartition("/")[0])

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
    env.expect.that_str(_native_library_path(env, target)).contains(target.label.name.rpartition("/")[0])

def _export_only_library_propagates_native_library_test(name):
    native = _native_library(name)
    util.helper_target(
        kt_jvm_library,
        name = name + "/library",
        exports = [native],
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
        impl = _export_only_library_propagates_native_library_test_impl,
        target = name + "/subject",
    )

def _export_only_library_propagates_native_library_test_impl(env, target):
    env.expect.that_str(_native_library_path(env, target)).contains(target.label.name.rpartition("/")[0])

def _user_jvm_flags_override_native_library_path_test(name):
    native = _native_library(name)
    util.helper_target(
        kt_jvm_binary,
        name = name + "/subject",
        srcs = [util.empty_file(name + "_Main.kt")],
        jvm_flags = ["-Djava.library.path=user_override"],
        main_class = "test.Main",
        runtime_deps = [native],
        tags = ["manual"],
    )
    analysis_test(
        name = name,
        impl = _user_jvm_flags_override_native_library_path_test_impl,
        target = name + "/subject",
    )

def _user_jvm_flags_override_native_library_path_test_impl(env, target):
    flags = "\n".join(_jvm_flags(env, target).actual)
    generated_path = target.label.name.rpartition("/")[0]
    env.expect.that_str(flags).contains(generated_path)
    env.expect.that_str(flags).contains("user_override")
    env.expect.that_bool(flags.find(generated_path) < flags.find("user_override")).equals(True)

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
    windows = executable.endswith(".exe")
    separator = ";" if windows else ":"
    dirname = target.label.name.rpartition("/")[0]
    library_path = env.expect.that_str(_native_library_path(env, target))
    library_path.contains(dirname + "/a")
    library_path.contains(separator)
    library_path.contains(dirname + "/b")

def native_libs_test_suite(name):
    test_suite(
        name = name,
        tests = [
            _native_runtime_dep_does_not_crash_test,
            _binary_has_direct_native_library_path_test,
            _binary_accepts_native_library_in_deps_test,
            _test_has_direct_native_library_path_test,
            _binary_has_transitive_native_library_path_test,
            _export_only_library_propagates_native_library_test,
            _user_jvm_flags_override_native_library_path_test,
            _native_library_path_uses_platform_separator_test,
        ],
    )
