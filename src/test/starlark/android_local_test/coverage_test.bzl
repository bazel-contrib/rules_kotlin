"""Coverage runtime checks for kt_android_local_test."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")

def _coverage_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    actions = analysistest.target_actions(env)
    executable = target[DefaultInfo].files_to_run.executable
    subs = [a.substitutions for a in actions if executable in a.outputs.to_list()][0]
    jacoco = ctx.attr.mode == "jacoco"
    kover = ctx.attr.mode == "kover"

    runner = "com.google.testing.junit.runner.BazelTestRunner"
    deploy_jar = target.label.name + "_deploy.jar"
    asserts.true(env, deploy_jar in subs["%classpath%"], msg = "Android launcher uses the deploy jar")
    asserts.equals(env, "com.google.testing.coverage.JacocoCoverageRunner" if jacoco else runner, subs["%java_start_class%"])
    asserts.equals(env, "export JACOCO_MAIN_CLASS=" + runner if jacoco else "", subs["%set_jacoco_main_class%"])
    if jacoco:
        asserts.true(env, deploy_jar in subs["%set_jacoco_metadata%"], msg = "JaCoCo uses the deploy jar for metadata")
    else:
        asserts.equals(env, "", subs["%set_jacoco_metadata%"])

    runtime_jars = target[JavaInfo].transitive_runtime_jars.to_list()
    asserts.equals(env, jacoco, any([f.basename == "libcustom_jacoco_runner.jar" for f in runtime_jars]))
    asserts.equals(env, jacoco, any(["jacoco" in f.basename.lower() for f in runtime_jars]))
    argv = [a.argv for a in actions if a.mnemonic == "KotlinCompile"][0]
    asserts.equals(env, "true" if jacoco else "false", argv[argv.index("--instrument_coverage") + 1])

    runfiles = target[DefaultInfo].default_runfiles.files.to_list()
    flags = subs["%jvm_flags%"].split(" ")
    agents = [f for f in runfiles if "kover-jvm-agent" in f.basename and f.extension == "jar"]
    args = [f for f in runfiles if f.basename.endswith("-kover.args.txt")]
    metadata = [f for f in runfiles if f.basename.endswith("-kover_metadata.txt")]
    asserts.equals(env, 1 if kover else 0, len(agents), msg = "agent jars in runfiles")
    asserts.equals(env, 1 if kover else 0, len(args), msg = "agent argument files in runfiles")
    asserts.equals(env, 1 if kover else 0, len(metadata), msg = "CLI metadata files in runfiles")
    if kover and agents and args:
        asserts.true(env, "-Xbootclasspath/a:" + agents[0].short_path in flags)
        asserts.true(env, "-javaagent:%s=file:%s" % (agents[0].short_path, args[0].short_path) in flags)
    else:
        asserts.false(env, any([f.startswith(("-javaagent:", "-Xbootclasspath/a:")) for f in flags]))
    return analysistest.end(env)

def _coverage_test(mode):
    return analysistest.make(
        _coverage_test_impl,
        attrs = {"mode": attr.string(default = mode)},
        config_settings = {
            "//command_line_option:collect_code_coverage": mode != "off",
            "//command_line_option:extra_toolchains": [
                "//src/test/starlark/android_local_test:jacoco_toolchain" if mode == "jacoco" else "//src/test/starlark/android_local_test:kover_toolchain",
            ],
            "//command_line_option:instrument_test_targets": True,
            "//command_line_option:instrumentation_filter": "//src/test/starlark/android_local_test",
        },
    )

coverage_off_test = _coverage_test("off")
jacoco_test = _coverage_test("jacoco")
kover_test = _coverage_test("kover")
