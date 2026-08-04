"""Test-case framework for the Starlark analysis tests."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:util.bzl", "util")

def _prepend(rule, name, **kwargs):
    util.helper_target(
        rule,
        name = name,
        **kwargs
    )
    return ":" + name

# buildifier: disable=name-conventions
Want = provider(
    doc = "Expected attr type and value for a Starlark analysis-test assertion.",
    fields = {
        "attr": "attr type of the value.",
        "value": "attr value",
    },
)

def _claim(name, what, got, wants):
    analysis_test(
        name = name,
        impl = what,
        target = got,
        attr_values = {
            name: want.value
            for (name, want) in wants.items()
        },
        attrs = {
            name: want.attr
            for (name, want) in wants.items()
        },
    )

def case(namespace):
    return struct(
        name = namespace,
        have = lambda rule, name, **kwargs: _prepend(rule, namespace + "_" + name, **kwargs),
        artifact = lambda name, **kwargs: util.empty_file(
            name = namespace + "_" + name,
            **kwargs
        ),
        got = lambda rule, name, **kwargs: _prepend(rule, namespace + "_" + name, **kwargs),
        ref = lambda name: ":" + namespace + "_" + name,
        claim = lambda **kwargs: _claim(name = namespace, **kwargs),
    )

def suite(name, **tests):
    test_targets = []
    for test_name, test in tests.items():
        test(case(test_name))

    native.test_suite(
        name = name,
        tests = test_targets,
    )
