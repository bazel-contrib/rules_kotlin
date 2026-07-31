"""The Build Tools API compilation runtime as one target."""

# The artifacts of the runtime: one provider field and one rule attribute each.
_ARTIFACTS = {
    "build_tools_impl": "the Build Tools implementation.",
    "compiler": "the compiler, embeddable dialect.",
    "jdeps_gen": "the jdeps-gen compiler plugin, embeddable dialect.",
    "jvm_abi_gen": "the jvm-abi-gen compiler plugin, embeddable dialect.",
    "kapt": "the kapt compiler plugin, embeddable dialect.",
    "libraries": "the libraries the implementation and the compiler need.",
    "skip_code_gen": "the skip-code-gen compiler plugin, embeddable dialect.",
}

# The attributes of kt_btapi_runtime and the fields of BtapiRuntimeInfo: the contract a repository's
# generated BUILD file instantiates.
BTAPI_RUNTIME_ATTRIBUTES = sorted(_ARTIFACTS.keys())

BtapiRuntimeInfo = provider(
    doc = """The complete Build Tools API compilation runtime: the classloader group and the internal
    compiler plugins. Every jar is the embeddable compiler dialect.""",
    fields = {name: "list of File: " + doc for name, doc in _ARTIFACTS.items()},
)

# The CLI-distribution jars with the same role. They carry the other dialect and do not load next
# to the embeddable implementation.
_DISTRIBUTION_JARS = {
    "compiler": Label("//kotlin/compiler:kotlin-compiler"),
    "jdeps_gen": Label("//src/main/kotlin:jdeps-gen"),
    "jvm_abi_gen": Label("//kotlin/compiler:jvm-abi-gen"),
    "kapt": Label("//kotlin/compiler:kotlin-annotation-processing"),
    "skip_code_gen": Label("//src/main/kotlin:skip-code-gen"),
}

def _kt_btapi_runtime_impl(ctx):
    base = ctx.attr.base[BtapiRuntimeInfo] if ctx.attr.base else None
    values = {}
    for name in _ARTIFACTS:
        targets = getattr(ctx.attr, name)
        if targets:
            distribution_jar = _DISTRIBUTION_JARS.get(name)
            for target in targets:
                if distribution_jar != None and target.label == distribution_jar:
                    fail("%s: %s = %s is the CLI-distribution jar; the Build Tools API runtime is the embeddable dialect throughout" % (ctx.label, name, target.label))
            files = [f for target in targets for f in target[DefaultInfo].files.to_list()]
        elif base != None:
            files = getattr(base, name)
        else:
            fail("%s: %s is not set, and there is no base runtime to inherit it from" % (ctx.label, name))
        values[name] = files

    runtime = BtapiRuntimeInfo(**values)
    plugins = values["jvm_abi_gen"] + values["kapt"] + values["jdeps_gen"] + values["skip_code_gen"]
    return [
        runtime,
        DefaultInfo(files = depset(btapi_runtime_classpath(runtime) + plugins)),
    ]

def btapi_runtime_classpath(runtime):
    """The Build Tools API classloader group of a runtime, in load order.

    The implementation loads first. The libraries load before the compiler, so that a library jar
    shadows a copy the compiler jar bundles (the daemon client).

    Args:
        runtime: a BtapiRuntimeInfo.
    Returns:
        list of File.
    """
    return runtime.build_tools_impl + runtime.libraries + runtime.compiler

def _artifact_attr(doc):
    return attr.label_list(
        doc = doc,
        allow_files = True,
        cfg = "exec",
    )

kt_btapi_runtime = rule(
    doc = """The Build Tools API compilation runtime: the jars the worker loads into the Build Tools
    API classloader, and the internal compiler plugins it passes to the compiler. Every jar is the
    embeddable compiler dialect (the Maven-published form of the compiler and its plugins), because
    the Build Tools implementation is published in that dialect only.

    An artifact that is not set is inherited from `base`, so a runtime that replaces one artifact
    states only that artifact. The default runtime, `//kotlin/compiler:btapi_runtime`, takes every
    artifact from the configured Kotlin release.""",
    implementation = _kt_btapi_runtime_impl,
    attrs = dict(
        {
            "base": attr.label(
                doc = "The runtime that provides every artifact this target does not set.",
                providers = [BtapiRuntimeInfo],
                cfg = "exec",
            ),
        },
        **{name: _artifact_attr(doc[0].upper() + doc[1:]) for name, doc in _ARTIFACTS.items()}
    ),
    provides = [BtapiRuntimeInfo],
)
