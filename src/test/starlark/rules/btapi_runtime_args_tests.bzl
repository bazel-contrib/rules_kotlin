load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("//src/test/starlark:case.bzl", "suite")
load(":arrangement.bzl", "arrange")
load(":util.bzl", "basename_of", "values_for_flag_of")

# The complete Build Tools API runtime surface the worker receives when the Build Tools API
# compilation is enabled: the classloader jars and the internal compiler plugin classpaths,
# as (flag, expected default jar count) pairs.
_BTAPI_RUNTIME_FLAG_COUNTS = [
    ("--btapi_impl_classpath", 10),
    ("--internal_jvm_abi_gen_classpath", 1),
    ("--internal_skip_code_gen_classpath", 1),
    ("--internal_kapt_classpath", 1),
    ("--internal_jdeps_gen_classpath", 1),
]

def _count(values):
    return [str(len(values))]

def _runtime_args_present_assertion(env, target):
    action = env.expect.that_target(target).action_named("KotlinCompile")
    for flag, jar_count in _BTAPI_RUNTIME_FLAG_COUNTS:
        values_for_flag_of(action, flag).transform(
            desc = "count of " + flag,
            loop = _count,
        ).contains_exactly([str(jar_count)])

    # The default runtime is the bundled CLI compiler distribution, keeping default Build Tools
    # API behavior identical to a toolchain without runtime overrides; the internal plugins must
    # come from the same (CLI) dialect as the selected compiler jar.
    values_for_flag_of(action, "--btapi_impl_classpath").transform(
        desc = "basenames",
        map_each = basename_of,
    ).contains("kotlin-compiler.jar")
    values_for_flag_of(action, "--internal_kapt_classpath").transform(
        desc = "basenames",
        map_each = basename_of,
    ).contains_exactly(["kotlin-annotation-processing.jar"])

def _runtime_args_absent_assertion(env, target):
    action = env.expect.that_target(target).action_named("KotlinCompile")
    for flag, _jar_count in _BTAPI_RUNTIME_FLAG_COUNTS:
        values_for_flag_of(action, flag).transform(
            desc = "count of " + flag,
            loop = _count,
        ).contains_exactly(["0"])

def _make_runtime_args_test(setting_value, assertion):
    def _case(test):
        (_dependency_a_trans_dep_jar, _dependency_a, main_target_library) = arrange(test)

        analysis_test(
            name = test.name,
            impl = assertion,
            target = main_target_library,
            config_settings = {
                str(Label("@rules_kotlin//kotlin/settings:experimental_build_tools_api")): setting_value,
            },
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
    )
