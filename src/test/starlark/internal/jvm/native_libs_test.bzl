load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("@rules_testing//lib:util.bzl", "util")
load("//kotlin:jvm.bzl", "kt_jvm_library")

def _native_dep_no_crash_test_impl(env, target):
    """Test that a cc_library as runtime_dep of kt_jvm_library doesn't crash.

    Regression test for the NoneType error when a non-JavaInfo target
    (like cc_binary(linkshared=1)) is passed as runtime_dep.
    """
    env.expect.that_target(target).has_provider(JavaInfo)

def _native_dep_no_crash_test(name):
    """Creates a test that cc runtime_deps don't cause NoneType crashes."""
    util.helper_target(
        cc_library,
        name = name + "_cc_lib",
        srcs = [util.empty_file(name + "_dummy.cc")],
        tags = ["manual"],
    )

    util.helper_target(
        kt_jvm_library,
        name = name + "_subject",
        srcs = [util.empty_file(name + "_Lib.kt")],
        runtime_deps = [":" + name + "_cc_lib"],
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        impl = _native_dep_no_crash_test_impl,
        target = name + "_subject",
    )

def _native_libs_in_java_info_test_impl(env, target):
    """Test that native libraries from CcInfo deps appear in JavaInfo.transitive_native_libraries."""
    env.expect.that_target(target).has_provider(JavaInfo)

    java_info = target[JavaInfo]
    native_libs = java_info.transitive_native_libraries.to_list()

    # cc_library with srcs should produce at least one native library
    # (The exact count depends on the platform, but it should be non-empty)
    env.expect.that_bool(len(native_libs) > 0).equals(True)

def _native_libs_in_java_info_test(name):
    """Creates a test that native libs from cc deps propagate into JavaInfo."""
    util.helper_target(
        cc_library,
        name = name + "_cc_lib",
        srcs = [util.empty_file(name + "_native.cc")],
        tags = ["manual"],
    )

    util.helper_target(
        kt_jvm_library,
        name = name + "_subject",
        srcs = [util.empty_file(name + "_Lib.kt")],
        runtime_deps = [":" + name + "_cc_lib"],
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        impl = _native_libs_in_java_info_test_impl,
        target = name + "_subject",
    )

def _transitive_native_libs_test_impl(env, target):
    """Test that native libraries propagate transitively through kt_jvm_library chain."""
    env.expect.that_target(target).has_provider(JavaInfo)

    java_info = target[JavaInfo]
    native_libs = java_info.transitive_native_libraries.to_list()
    env.expect.that_bool(len(native_libs) > 0).equals(True)

def _transitive_native_libs_test(name):
    """Creates a test that native libs propagate through transitive kt_jvm_library deps."""
    util.helper_target(
        cc_library,
        name = name + "_cc_lib",
        srcs = [util.empty_file(name + "_native.cc")],
        tags = ["manual"],
    )

    util.helper_target(
        kt_jvm_library,
        name = name + "_inner_lib",
        srcs = [util.empty_file(name + "_Inner.kt")],
        runtime_deps = [":" + name + "_cc_lib"],
        tags = ["manual"],
    )

    util.helper_target(
        kt_jvm_library,
        name = name + "_subject",
        srcs = [util.empty_file(name + "_Outer.kt")],
        deps = [":" + name + "_inner_lib"],
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        impl = _transitive_native_libs_test_impl,
        target = name + "_subject",
    )

def native_libs_test_suite(name):
    test_suite(
        name = name,
        tests = [
            _native_dep_no_crash_test,
            _native_libs_in_java_info_test,
            _transitive_native_libs_test,
        ],
    )
