"""Tests that the export-only (srcs-less) kt_jvm_library path inherits module_name from associates."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("@rules_testing//lib:util.bzl", "util")
load("//kotlin:jvm.bzl", "kt_jvm_library")
load("//kotlin/internal:defs.bzl", "KtJvmInfo")

_ASSOCIATE_MODULE = "test.export_only.associated_module"

def _export_only_inherits_associate_module_name_test_impl(env, target):
    """A srcs-less kt_jvm_library inherits its module_name from its associates.

    The compiled path resolves module_name from the associates (jvm_deps.bzl); the export-only
    path must do the same, otherwise an associate of an srcs-less shim would see a different
    module than the rest of its module and lose `internal` visibility.
    """
    env.expect.that_target(target).has_provider(KtJvmInfo)
    env.expect.that_str(target[KtJvmInfo].module_name).equals(_ASSOCIATE_MODULE)

def _export_only_inherits_associate_module_name_test(name):
    kt_jvm_library(
        name = name + "_associate",
        srcs = [util.empty_file(name + "_Associated.kt")],
        module_name = _ASSOCIATE_MODULE,
        tags = ["manual"],
    )

    # No srcs and no resources -> the export-only providers path (see kt_jvm_library_impl).
    kt_jvm_library(
        name = name + "_subject",
        associates = [":" + name + "_associate"],
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        impl = _export_only_inherits_associate_module_name_test_impl,
        target = name + "_subject",
    )

def export_only_module_name_test_suite(name):
    """Test suite for export-only module_name inheritance."""
    test_suite(
        name = name,
        tests = [
            _export_only_inherits_associate_module_name_test,
        ],
    )
