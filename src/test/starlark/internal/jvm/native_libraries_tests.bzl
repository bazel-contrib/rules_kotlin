load("@rules_cc//cc:defs.bzl", "cc_binary")
load("@rules_java//java:defs.bzl", "JavaInfo")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching", "subjects")
load("@rules_testing//lib:util.bzl", "util")
load("//kotlin:jvm.bzl", "kt_jvm_binary", "kt_jvm_library", "kt_jvm_test")

def _native_library_artifact(library_to_link):
    for field in [
        "resolved_symlink_dynamic_library",
        "dynamic_library",
        "interface_library",
        "pic_static_library",
        "static_library",
    ]:
        artifact = getattr(library_to_link, field, None)
        if artifact:
            return artifact
    return None

def _native_library_basenames(java_info):
    basenames = []
    for library_to_link in java_info.transitive_native_libraries.to_list():
        artifact = _native_library_artifact(library_to_link)
        if artifact:
            basenames.append(artifact.basename)
    return basenames

def _native_library_target(name, suffix):
    util.helper_target(
        cc_binary,
        name = name + "/" + suffix,
        srcs = [util.empty_file(name + "_" + suffix + ".cc")],
        linkshared = 1,
        linkstatic = 1,
    )
    return name + "/" + suffix

def _assert_native_library_basenames(env, target, expected_patterns):
    env.expect.that_collection(_native_library_basenames(target[JavaInfo])).contains_exactly_predicates([
        matching.str_matches(pattern)
        for pattern in expected_patterns
    ])

def _jvm_flags_subject(assert_action):
    if assert_action.actual.substitutions:
        return assert_action.substitutions().get(
            "%jvm_flags%",
            factory = lambda value, meta: subjects.collection([value], meta),
        )
    return assert_action.argv()

def _target_directory_name(target):
    parts = target.label.name.split("/")
    if len(parts) == 1:
        return target.label.name
    return "/".join(parts[:-1])

def _with_native_libraries_test(name):
    native_target = _native_library_target(name, "native_direct")
    util.helper_target(
        kt_jvm_library,
        name = name + "/subject",
        srcs = [util.empty_file(name + "_Direct.kt")],
        runtime_deps = [native_target],
    )

    analysis_test(
        name = name,
        impl = _with_native_libraries_test_impl,
        target = name + "/subject",
    )

def _with_native_libraries_test_impl(env, target):
    _assert_native_library_basenames(env, target, ["*native_direct*"])

def _transitive_native_libraries_test(name):
    native_c = _native_library_target(name, "native_c")
    util.helper_target(
        kt_jvm_library,
        name = name + "/lib_c",
        srcs = [util.empty_file(name + "_C.kt")],
        runtime_deps = [native_c],
    )

    native_b = _native_library_target(name, "native_b")
    util.helper_target(
        kt_jvm_library,
        name = name + "/lib_b",
        srcs = [util.empty_file(name + "_B.kt")],
        runtime_deps = [native_b],
    )

    native_a = _native_library_target(name, "native_a")
    util.helper_target(
        kt_jvm_library,
        name = name + "/subject",
        srcs = [util.empty_file(name + "_A.kt")],
        deps = [
            name + "/lib_b",
            name + "/lib_c",
        ],
        runtime_deps = [native_a],
    )

    analysis_test(
        name = name,
        impl = _transitive_native_libraries_test_impl,
        target = name + "/subject",
    )

def _transitive_native_libraries_test_impl(env, target):
    _assert_native_library_basenames(env, target, [
        "*native_a*",
        "*native_b*",
        "*native_c*",
    ])

def _native_libraries_propagation_test(name):
    native_dep = _native_library_target(name, "native_dep")
    util.helper_target(
        kt_jvm_library,
        name = name + "/lib_deps",
        srcs = [util.empty_file(name + "_Deps.kt")],
        runtime_deps = [native_dep],
    )

    native_runtime = _native_library_target(name, "native_runtime")
    util.helper_target(
        kt_jvm_library,
        name = name + "/lib_runtime_deps",
        srcs = [util.empty_file(name + "_Runtime.kt")],
        runtime_deps = [native_runtime],
    )

    native_export = _native_library_target(name, "native_export")
    util.helper_target(
        kt_jvm_library,
        name = name + "/lib_exports",
        srcs = [util.empty_file(name + "_Export.kt")],
        runtime_deps = [native_export],
    )

    util.helper_target(
        kt_jvm_library,
        name = name + "/subject",
        srcs = [util.empty_file(name + "_Subject.kt")],
        deps = [name + "/lib_deps"],
        runtime_deps = [name + "/lib_runtime_deps"],
        exports = [name + "/lib_exports"],
    )

    analysis_test(
        name = name,
        impl = _native_libraries_propagation_test_impl,
        target = name + "/subject",
    )

def _native_libraries_propagation_test_impl(env, target):
    _assert_native_library_basenames(env, target, [
        "*native_dep*",
        "*native_runtime*",
        "*native_export*",
    ])

def _kt_jvm_binary_propagates_direct_native_libraries_test(name):
    native_target = _native_library_target(name, "native")
    util.helper_target(
        kt_jvm_binary,
        name = name + "/binary",
        srcs = [util.empty_file(name + "_Main.kt")],
        main_class = "test.Main",
        runtime_deps = [native_target],
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        impl = _kt_jvm_binary_propagates_direct_native_libraries_test_impl,
        target = name + "/binary",
    )

def _kt_jvm_binary_propagates_direct_native_libraries_test_impl(env, target):
    executable = target[DefaultInfo].files_to_run.executable.short_path
    assert_action = env.expect.that_target(target).action_generating(executable)
    _jvm_flags_subject(assert_action).contains_predicate(
        matching.str_matches("*-Djava.library.path=*{}*".format(_target_directory_name(target))),
    )

def _kt_jvm_test_propagates_direct_native_libraries_test(name):
    native_target = _native_library_target(name, "native")
    util.helper_target(
        kt_jvm_test,
        name = name + "/binary",
        srcs = [util.empty_file(name + "_Test.kt")],
        test_class = "test.NativeLibraryPathTest",
        runtime_deps = [native_target],
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        impl = _kt_jvm_test_propagates_direct_native_libraries_test_impl,
        target = name + "/binary",
    )

def _kt_jvm_test_propagates_direct_native_libraries_test_impl(env, target):
    executable = target[DefaultInfo].files_to_run.executable.short_path
    assert_action = env.expect.that_target(target).action_generating(executable)
    _jvm_flags_subject(assert_action).contains_predicate(
        matching.str_matches("*-Djava.library.path=*{}*".format(_target_directory_name(target))),
    )

def native_libraries_test_suite(name):
    test_suite(
        name = name,
        tests = [
            _with_native_libraries_test,
            _transitive_native_libraries_test,
            _native_libraries_propagation_test,
            _kt_jvm_binary_propagates_direct_native_libraries_test,
            _kt_jvm_test_propagates_direct_native_libraries_test,
        ],
    )
