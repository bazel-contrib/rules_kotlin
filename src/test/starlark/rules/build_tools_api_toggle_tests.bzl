load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("//src/test/starlark:case.bzl", "suite")
load(":arrangement.bzl", "arrange")
load(":util.bzl", "values_for_flag_of")

def _lowercase(value):
    return value.lower()

def _build_tools_api_flag_assertion(env, target):
    action = env.expect.that_target(target).action_named("KotlinCompile")
    values_for_flag_of(action, "--build_tools_api").transform(
        desc = "lowercased",
        map_each = _lowercase,
    ).contains_exactly([env.ctx.attr.want_value])

def _make_toggle_test(setting_value, want_value):
    def _case(test):
        (_dependency_a_trans_dep_jar, _dependency_a, main_target_library) = arrange(test)

        analysis_test(
            name = test.name,
            impl = _build_tools_api_flag_assertion,
            target = main_target_library,
            config_settings = {
                str(Label("@rules_kotlin//kotlin/settings:experimental_build_tools_api")): setting_value,
            },
            attr_values = {
                "want_value": want_value,
            },
            attrs = {
                "want_value": attr.string(),
            },
        )

    return _case

def build_tools_api_toggle_tests(name):
    suite(
        name,
        setting_disabled_compiles_via_legacy = _make_toggle_test(False, "false"),
        setting_enabled_compiles_via_build_tools_api = _make_toggle_test(True, "true"),
    )
