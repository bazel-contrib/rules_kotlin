"""Check coverage inputs during analysis, without compiling or running the fixture."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

def _metadata_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    metadata = [
        action
        for action in analysistest.target_actions(env)
        if any([file.basename.endswith("-kover_metadata.txt") for file in action.outputs.to_list()])
    ]
    asserts.equals(env, 1, len(metadata), msg = "one Kover CLI argument file")
    if len(metadata) == 1:
        args = metadata[0].content.split("\n")
        jars = [args[i + 1] for i in range(len(args) - 1) if args[i] == "--classfiles"]
        asserts.equals(env, sorted(ctx.attr.expected_jars), sorted(jars), msg = "only instrumented JARs enter the report")

    sources = [file.short_path for file in target[InstrumentedFilesInfo].instrumented_files.to_list()]
    asserts.equals(env, sorted(ctx.attr.expected_sources), sorted(sources), msg = "only instrumented sources enter the report")
    return analysistest.end(env)

def _metadata_test(instrumentation_filter):
    return analysistest.make(
        _metadata_test_impl,
        attrs = {
            "expected_jars": attr.string_list(mandatory = True),
            "expected_sources": attr.string_list(mandatory = True),
        },
        config_settings = {
            "//command_line_option:collect_code_coverage": True,
            "//command_line_option:extra_toolchains": [str(Label(":toolchain"))],
            "//command_line_option:instrument_test_targets": False,
            "//command_line_option:instrumentation_filter": instrumentation_filter,
        },
    )

filtered_metadata_test = _metadata_test("^//src/test/kover[/:],-//src/test/kover:outside_filter$")
module_metadata_test = _metadata_test("^//src/test/kover[/:]")
