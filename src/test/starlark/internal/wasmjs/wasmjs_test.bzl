"""Analysis tests for the Kotlin/WasmJs rules."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//kotlin:wasmjs.bzl", "KtWasmJsInfo", "kt_wasmjs_import")

def _basenames(files):
    return sorted([f.basename for f in files.to_list()])

def _import_test_impl(ctx):
    env = analysistest.begin(ctx)
    info = analysistest.target_under_test(env)[KtWasmJsInfo]

    # The compile visibility follows the exported deps only, the link visibility the whole closure.
    asserts.equals(env, expected = ["test_wasmjs_dep.klib", "test_wasmjs_import.klib"], actual = _basenames(info.compile_klibs))
    asserts.equals(
        env,
        expected = ["test_wasmjs_dep.klib", "test_wasmjs_import.klib", "test_wasmjs_runtime_dep.klib"],
        actual = _basenames(info.link_klibs),
    )
    return analysistest.end(env)

_import_test = analysistest.make(_import_test_impl)

def _neverlink_test_impl(ctx):
    env = analysistest.begin(ctx)
    info = analysistest.target_under_test(env)[KtWasmJsInfo]
    asserts.equals(env, expected = ["test_wasmjs_dep.klib", "test_wasmjs_import.klib"], actual = _basenames(info.compile_klibs))
    asserts.equals(env, expected = [], actual = _basenames(info.link_klibs))
    asserts.equals(env, expected = [], actual = info.npm_packages.to_list())
    return analysistest.end(env)

_neverlink_test = analysistest.make(_neverlink_test_impl)

def _contents():
    for name in ["test_wasmjs_dep", "test_wasmjs_runtime_dep", "test_wasmjs_import"]:
        write_file(name = name + "_klib", out = name + ".klib", tags = ["manual"])
    write_file(name = "npm_a", out = "npm_a/package.json", content = ["{}"], tags = ["manual"])

    kt_wasmjs_import(
        name = "dep",
        klib = "test_wasmjs_dep.klib",
        npm_packages = {"@js-joda/core": ":npm_a"},
        tags = ["manual"],
    )
    kt_wasmjs_import(
        name = "runtime_dep",
        klib = "test_wasmjs_runtime_dep.klib",
        tags = ["manual"],
    )
    kt_wasmjs_import(
        name = "imported",
        klib = "test_wasmjs_import.klib",
        deps = [":runtime_dep"],
        exported_deps = [":dep"],
        tags = ["manual"],
    )
    kt_wasmjs_import(
        name = "neverlink_import",
        klib = "test_wasmjs_import.klib",
        deps = [":runtime_dep"],
        exported_deps = [":dep"],
        neverlink = True,
        tags = ["manual"],
    )

    _import_test(name = "import_test", target_under_test = ":imported")
    _neverlink_test(name = "neverlink_import_test", target_under_test = ":neverlink_import")

def wasmjs_test_suite(name):
    _contents()
    native.test_suite(
        name = name,
        tests = [
            ":import_test",
            ":neverlink_import_test",
        ],
    )
