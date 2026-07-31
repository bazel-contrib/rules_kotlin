"""Tests for kt_btapi_runtime: the default runtime, inheritance through base, and the checks."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:truth.bzl", "matching")
load("//kotlin/internal:btapi_runtime.bzl", "BtapiRuntimeInfo", "btapi_runtime_classpath", "kt_btapi_runtime")
load("//src/test/starlark:case.bzl", "suite")
load("//src/test/starlark:truth.bzl", "fail_messages_in")

_DEFAULT_RUNTIME = str(Label("@rules_kotlin//kotlin/compiler:btapi_runtime"))
_DISTRIBUTION_COMPILER = str(Label("@rules_kotlin//kotlin/compiler:kotlin-compiler"))

_ATTRS = {
    "want_compiler": attr.string(),
    "want_failure": attr.string(),
}

def _basenames(files):
    return [f.basename for f in files]

def _default_runtime_assertion(env, target):
    info = target[BtapiRuntimeInfo]
    env.expect.that_collection(_basenames(info.build_tools_impl)).contains_exactly(["kotlin-build-tools-impl.jar"])
    env.expect.that_collection(_basenames(info.compiler)).contains_exactly(["kotlin-compiler-embeddable.jar"])
    env.expect.that_collection(_basenames(info.kapt)).contains_exactly(["kotlin-annotation-processing-embeddable.jar"])
    env.expect.that_collection(_basenames(info.jvm_abi_gen)).contains_exactly(["jvm-abi-gen.jar"])
    env.expect.that_collection(_basenames(info.jdeps_gen)).contains_exactly(["jdeps-gen-embeddable.jar"])
    env.expect.that_collection(_basenames(info.skip_code_gen)).contains_exactly(["skip-code-gen-embeddable.jar"])

    # Load order: the implementation, the libraries (the daemon client among them), the compiler.
    classpath = _basenames(btapi_runtime_classpath(info))
    env.expect.that_str(classpath[0]).equals("kotlin-build-tools-impl.jar")
    env.expect.that_str(classpath[-1]).equals("kotlin-compiler-embeddable.jar")
    env.expect.that_collection(classpath).contains_at_least([
        "kotlin-daemon-client.jar",
        "kotlin-stdlib.jar",
        "kotlin-reflect.jar",
        "kotlin-script-runtime.jar",
        "kotlinx-coroutines-core-jvm.jar",
        "kotlinx-serialization-core-jvm.jar",
    ])
    env.expect.that_collection(classpath).not_contains("kotlin-compiler.jar")

    # The record's own libraries: not the CLI distribution's copies.
    for f in info.libraries:
        if f.basename in ["kotlin-stdlib.jar", "kotlin-reflect.jar", "kotlin-daemon-client.jar", "kotlin-script-runtime.jar"]:
            env.expect.that_str(f.owner.workspace_name).contains("btapi_impl")

def _inherited_runtime_assertion(env, target):
    info = target[BtapiRuntimeInfo]
    env.expect.that_collection(_basenames(info.compiler)).contains_exactly([env.ctx.attr.want_compiler])
    env.expect.that_str(_basenames(btapi_runtime_classpath(info))[-1]).equals(env.ctx.attr.want_compiler)

    # Everything else comes from the base runtime.
    env.expect.that_collection(_basenames(info.build_tools_impl)).contains_exactly(["kotlin-build-tools-impl.jar"])
    env.expect.that_collection(_basenames(info.kapt)).contains_exactly(["kotlin-annotation-processing-embeddable.jar"])
    env.expect.that_collection(_basenames(info.libraries)).contains_at_least(["kotlin-daemon-client.jar"])

def _failure_assertion(env, target):
    fail_messages_in(env.expect.that_target(target)).contains_predicate(
        matching.str_matches("*" + env.ctx.attr.want_failure + "*"),
    )

def _default_runtime_case(test):
    analysis_test(
        name = test.name,
        impl = _default_runtime_assertion,
        target = _DEFAULT_RUNTIME,
    )

def _inherited_runtime_case(test):
    compiler = test.artifact(name = "marked-compiler-embeddable.jar")
    runtime = test.got(
        kt_btapi_runtime,
        name = "runtime",
        base = _DEFAULT_RUNTIME,
        compiler = [compiler],
    )
    analysis_test(
        name = test.name,
        impl = _inherited_runtime_assertion,
        target = runtime,
        attr_values = {"want_compiler": test.name + "_marked-compiler-embeddable.jar"},
        attrs = _ATTRS,
    )

def _make_failure_case(want_failure, **runtime_kwargs):
    def _case(test):
        kwargs = {}
        for name, value in runtime_kwargs.items():
            kwargs[name] = [test.artifact(name = artifact) if artifact.endswith(".jar") else artifact for artifact in value] if type(value) == "list" else value
        runtime = test.got(
            kt_btapi_runtime,
            name = "runtime",
            **kwargs
        )
        analysis_test(
            name = test.name,
            impl = _failure_assertion,
            target = runtime,
            expect_failure = True,
            attr_values = {"want_failure": want_failure},
            attrs = _ATTRS,
        )

    return _case

def btapi_runtime_tests(name):
    suite(
        name,
        default_runtime_is_the_embeddable_family = _default_runtime_case,
        inherited_runtime_replaces_one_artifact = _inherited_runtime_case,
        distribution_compiler_is_rejected = _make_failure_case(
            "is the CLI-distribution jar",
            base = _DEFAULT_RUNTIME,
            compiler = [_DISTRIBUTION_COMPILER],
        ),
        missing_artifact_without_base_is_rejected = _make_failure_case(
            "build_tools_impl is not set, and there is no base runtime",
            compiler = ["only-compiler.jar"],
        ),
    )
