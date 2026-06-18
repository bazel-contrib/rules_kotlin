load("@contrib_rules_jvm//java:defs.bzl", "create_jvm_test_suite", "java_junit5_test")
load("//kotlin/internal/jvm:jvm.bzl", "kt_jvm_library", "kt_jvm_test")

_DEFAULT_TEST_SUFFIXES = ["Test.kt"]

def _define_junit4_test(name, **kwargs):
    kt_jvm_test(
        name = name,
        **kwargs
    )
    return name

def _define_junit5_test(name, **kwargs):
    library_target = "%s-compile" % name

    libargs = {} | kwargs
    libargs.pop("size", [])
    libargs.pop("test_class", [])

    kt_jvm_library(
        name = library_target,
        testonly = True,
        **libargs
    )

    testargs = {} | kwargs
    runtime_deps = testargs.pop("deps", []) + testargs.pop("runtime_deps", []) + [":%s" % library_target]
    testargs.pop("srcs", [])

    java_junit5_test(
        name = name,
        runtime_deps = runtime_deps,
        **testargs
    )

    return name

_RUNNERS = {
    "junit4": _define_junit4_test,
    "junit5": _define_junit5_test,
}

def kt_jvm_test_suite(
        name,
        srcs,
        runner = "junit4",
        test_suffixes = _DEFAULT_TEST_SUFFIXES,
        package = None,
        deps = None,
        runtime_deps = None,
        size = None,
        **kwargs):
    """Create a suite of Kotlin tests from `*Test.kt` files.

    This rule will create a `kt_jvm_test` for each file which matches
    any of the `test_suffixes` that are passed to this rule as
    `srcs`. If any non-test sources are added these will first be
    compiled into a `kt_jvm_library` which will be added as a
    dependency for each test target, allowing common utility functions
    to be shared between tests.

    The generated `kt_jvm_test` targets will be named after the test file:
    `FooTest.kt` will create a `:FooTest` target.

    In addition, a `test_suite` will be created, named using the `name`
    attribute to allow all the tests to be run in one go.

    Args:
      name: A unique name for this rule. Will be used to generate a `test_suite`.
      srcs: Source files to create test rules for.
      runner: The test runner to use. Valid values are `junit4` and `junit5`.
      package: The package name used by the tests. If not set, this is
        inferred from the current bazel package name.
      deps: A list of dependencies.
      runtime_deps: A list of dependencies needed at runtime.
      size: The size of the test, passed to `kt_jvm_test`.
      test_suffixes: The file name suffix used to identify if a file
        contains a test class.
    """
    if runner not in _RUNNERS:
        fail("Unsupported kt_jvm_test_suite runner '%s'. Valid runners are: %s" % (
            runner,
            ", ".join(sorted(_RUNNERS.keys())),
        ))

    if deps != None:
        kwargs["deps"] = deps
    if runtime_deps != None:
        kwargs["runtime_deps"] = runtime_deps
    if size != None:
        kwargs["size"] = size

    create_jvm_test_suite(
        name,
        srcs = srcs,
        test_suffixes = test_suffixes,
        package = package,
        define_library = kt_jvm_library,
        define_test = _RUNNERS[runner],
        **kwargs
    )
