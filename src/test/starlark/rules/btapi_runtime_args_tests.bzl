load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("//src/test/starlark:case.bzl", "suite")
load(":arrangement.bzl", "arrange")
load(":util.bzl", "basename_of", "values_for_flag_of")

_OVERRIDE_RUNTIME_TOOLCHAIN = str(Label("@rules_kotlin//src/test/starlark/rules:override_runtime_toolchain"))
_SETTING_CONTROLLED_RUNTIME_TOOLCHAIN = str(Label("@rules_kotlin//src/test/starlark/rules:setting_controlled_runtime_toolchain"))

# The complete Build Tools API runtime surface the worker receives when the Build Tools API
# compilation is enabled: the classloader jars and the internal compiler plugin classpaths,
# as (flag, expected default jar count) pairs. The classloader holds the implementation, the four
# release libraries, the five shared libraries, and the compiler.
_BTAPI_RUNTIME_FLAG_COUNTS = [
    ("--btapi_impl_classpath", 11),
    ("--internal_jvm_abi_gen_classpath", 1),
    ("--internal_skip_code_gen_classpath", 1),
    ("--internal_kapt_classpath", 1),
    ("--internal_jdeps_gen_classpath", 1),
]

def _count(values):
    return [str(len(values))]

def _first_basename(values):
    return [basename_of(values[0])] if values else []

def _last_basename(values):
    return [basename_of(values[-1])] if values else []

def _basenames_of(action, flag):
    return values_for_flag_of(action, flag).transform(
        desc = "basenames of " + flag,
        map_each = basename_of,
    )

def _runtime_args_present_assertion(env, target):
    action = env.expect.that_target(target).action_named("KotlinCompile")
    for flag, jar_count in _BTAPI_RUNTIME_FLAG_COUNTS:
        values_for_flag_of(action, flag).transform(
            desc = "count of " + flag,
            loop = _count,
        ).contains_exactly([str(jar_count)])

    # The Build Tools API invocation runs the embeddable compiler family of the configured Kotlin
    # release: the implementation loads first, the compiler last, and the internal plugins come in
    # the embeddable dialect. The CLI-distribution compiler stays out of the runtime.
    values_for_flag_of(action, "--btapi_impl_classpath").transform(
        desc = "first jar of --btapi_impl_classpath",
        loop = _first_basename,
    ).contains_exactly(["kotlin-build-tools-impl.jar"])
    values_for_flag_of(action, "--btapi_impl_classpath").transform(
        desc = "last jar of --btapi_impl_classpath",
        loop = _last_basename,
    ).contains_exactly(["kotlin-compiler-embeddable.jar"])
    _basenames_of(action, "--btapi_impl_classpath").not_contains("kotlin-compiler.jar")
    _basenames_of(action, "--internal_kapt_classpath").contains_exactly(["kotlin-annotation-processing-embeddable.jar"])
    _basenames_of(action, "--internal_jvm_abi_gen_classpath").contains_exactly(["jvm-abi-gen.jar"])
    _basenames_of(action, "--internal_jdeps_gen_classpath").contains_exactly(["jdeps-gen-embeddable.jar"])
    _basenames_of(action, "--internal_skip_code_gen_classpath").contains_exactly(["skip-code-gen-embeddable.jar"])

def _runtime_args_absent_assertion(env, target):
    action = env.expect.that_target(target).action_named("KotlinCompile")
    for flag, _jar_count in _BTAPI_RUNTIME_FLAG_COUNTS:
        values_for_flag_of(action, flag).transform(
            desc = "count of " + flag,
            loop = _count,
        ).contains_exactly(["0"])

def _override_runtime_assertion(env, target):
    action = env.expect.that_target(target).action_named("KotlinCompile")

    # A runtime built on the default replaces the compiler alone; every other artifact is the
    # default one.
    values_for_flag_of(action, "--btapi_impl_classpath").transform(
        desc = "last jar of --btapi_impl_classpath",
        loop = _last_basename,
    ).contains_exactly(["marked-compiler-embeddable.jar"])
    _basenames_of(action, "--btapi_impl_classpath").not_contains("kotlin-compiler-embeddable.jar")
    values_for_flag_of(action, "--btapi_impl_classpath").transform(
        desc = "first jar of --btapi_impl_classpath",
        loop = _first_basename,
    ).contains_exactly(["kotlin-build-tools-impl.jar"])
    _basenames_of(action, "--internal_kapt_classpath").contains_exactly(["kotlin-annotation-processing-embeddable.jar"])

def _make_runtime_args_test(setting_value, assertion, extra_toolchain = None):
    def _case(test):
        (_dependency_a_trans_dep_jar, _dependency_a, main_target_library) = arrange(test)

        config_settings = {
            str(Label("@rules_kotlin//kotlin/settings:experimental_build_tools_api")): setting_value,
        }
        if extra_toolchain:
            config_settings["//command_line_option:extra_toolchains"] = [extra_toolchain]

        analysis_test(
            name = test.name,
            impl = assertion,
            target = main_target_library,
            config_settings = config_settings,
        )

    return _case

def btapi_runtime_args_tests(name):
    suite(
        name,
        build_tools_api_actions_carry_the_runtime = _make_runtime_args_test(
            True,
            _runtime_args_present_assertion,
        ),
        legacy_actions_carry_no_runtime = _make_runtime_args_test(
            False,
            _runtime_args_absent_assertion,
        ),
        overridden_runtime_replaces_one_artifact = _make_runtime_args_test(
            True,
            _override_runtime_assertion,
            extra_toolchain = _OVERRIDE_RUNTIME_TOOLCHAIN,
        ),
        runtime_alone_enables_the_build_tools_api = _make_runtime_args_test(
            False,
            _override_runtime_assertion,
            extra_toolchain = _OVERRIDE_RUNTIME_TOOLCHAIN,
        ),
        explicit_legacy_toolchain_leaves_the_runtime_to_the_setting = _make_runtime_args_test(
            False,
            _runtime_args_absent_assertion,
            extra_toolchain = _SETTING_CONTROLLED_RUNTIME_TOOLCHAIN,
        ),
    )
