"""Tests for the contents of the kt_compiler_plugin and kt_ksp_plugin classpath.

The plugin classpath is the transitive runtime classpath of the plugin deps, as Bazel defines it.
A neverlink library has an empty one, so it contributes nothing to the plugin classpath, and
neither does a library reachable only through it. A library that another edge reaches as well stays
on the plugin classpath. In a mismatched dialect every jar of the classpath needs a reshaded copy,
which the aspect declares for the libraries it visits, the associates included. A jar that reaches
the classpath through an attribute the aspect does not walk has no copy and stays as it is. The
runtime jars of the toolchain are such jars: the toolchain adds them to every Kotlin library.
"""

load("@rules_java//java:defs.bzl", "JavaInfo", "java_import", "java_library")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("//kotlin:core.bzl", "kt_compiler_plugin", "kt_ksp_plugin")
load("//kotlin:jvm.bzl", "kt_jvm_library")
load("//kotlin/internal:defs.bzl", "KspPluginInfo")
load("//src/test/starlark:case.bzl", "suite")

_BUILD_TOOLS_API_SETTING = str(Label("@rules_kotlin//kotlin/settings:experimental_build_tools_api"))

_ATTRS = {
    "want_basenames": attr.string_list(),
}

def _basenames(files):
    return [f.basename for f in files.to_list()]

def _plugin_classpath_assertion(env, target):
    env.expect.that_collection(_basenames(target[DefaultInfo].files)).contains_exactly(
        env.ctx.attr.want_basenames,
    ).in_order()

def _ksp_classpath_assertion(env, target):
    """The KSP processor classpath equals the plugin classpath, in the files and in the JavaPluginInfo."""
    env.expect.that_collection(_basenames(target[DefaultInfo].files)).contains_exactly(
        env.ctx.attr.want_basenames,
    ).in_order()
    processor_jars = target[KspPluginInfo].plugins[0].plugins.processor_jars
    env.expect.that_collection(_basenames(processor_jars)).contains_exactly(env.ctx.attr.want_basenames)

def _library_through_lib_impl(ctx):
    return [JavaInfo(output_jar = ctx.file.jar, compile_jar = ctx.file.jar, deps = [ctx.attr.lib[JavaInfo]])]

# A library that puts a dependency on its runtime classpath through an attribute the plugin aspect
# does not walk.
_library_through_lib = rule(
    implementation = _library_through_lib_impl,
    attrs = {
        "jar": attr.label(allow_single_file = True, mandatory = True),
        "lib": attr.label(providers = [JavaInfo], mandatory = True),
    },
)

def _plugin_library_over_neverlink(direct_compiler_dep):
    """A plugin library that reaches a compiler library through a neverlink library.

    With direct_compiler_dep the plugin library names the compiler library in its deps as well.
    """

    def _library(test):
        compiler_jar = test.artifact(name = "compiler.jar")
        compiler = test.have(
            java_import,
            name = "compiler_lib",
            jars = [compiler_jar],
        )
        provided = test.have(
            java_library,
            name = "compiler_provided",
            exports = [compiler],
            neverlink = True,
        )
        plugin_jar = test.artifact(name = "plugin_dep.jar")
        return test.have(
            java_import,
            name = "plugin_dep_lib",
            jars = [plugin_jar],
            deps = [provided] + ([compiler] if direct_compiler_dep else []),
        )

    return _library

def _plugin_library_through_lib(test):
    """A plugin library that reaches a library through an attribute the plugin aspect does not walk."""
    lib_jar = test.artifact(name = "lib.jar")
    lib = test.have(
        java_import,
        name = "lib",
        jars = [lib_jar],
    )
    plugin_jar = test.artifact(name = "plugin_dep.jar")
    return test.have(
        _library_through_lib,
        name = "plugin_dep_lib",
        jar = plugin_jar,
        lib = lib,
    )

def _kotlin_plugin_library(test):
    """A plugin library compiled from Kotlin sources: the toolchain adds its runtime jars to it."""
    return test.have(
        kt_jvm_library,
        name = "plugin_dep_lib",
        srcs = [test.artifact(name = "plugin_dep.kt")],
    )

def _kotlin_plugin_library_with_associate(test):
    """A plugin library split in two Kotlin libraries of one module: the second is an associate."""
    core = test.have(
        kt_jvm_library,
        name = "core",
        srcs = [test.artifact(name = "core.kt")],
    )
    return test.have(
        kt_jvm_library,
        name = "plugin_dep_lib",
        srcs = [test.artifact(name = "plugin_dep.kt")],
        associates = [core],
    )

def _make_classpath_test(
        library,
        target_embedded_compiler,
        want,
        ksp = False):
    """A case: a plugin over the library, analyzed under the legacy invocation.

    target_embedded_compiler sets the dialect of the plugin. The legacy invocation runs the CLI
    distribution, so a plugin of the embeddable dialect gets the reshaded copies. want lists the
    expected basenames in order.
    """

    def _case(test):
        if ksp:
            plugin = test.got(
                kt_ksp_plugin,
                name = "plugin",
                processor_class = "test.Processor",
                target_embedded_compiler = target_embedded_compiler,
                deps = [library(test)],
            )
        else:
            plugin = test.got(
                kt_compiler_plugin,
                name = "plugin",
                id = "test.classpath." + test.name,
                target_embedded_compiler = target_embedded_compiler,
                deps = [library(test)],
            )

        analysis_test(
            name = test.name,
            impl = _ksp_classpath_assertion if ksp else _plugin_classpath_assertion,
            target = plugin,
            # Pinned to the legacy invocation, whatever the flag of the test run says.
            config_settings = {_BUILD_TOOLS_API_SETTING: False},
            attr_values = {"want_basenames": [name.format(test = test.name) for name in want]},
            attrs = _ATTRS,
        )

    return _case

def plugin_classpath_tests(name):
    suite(
        name,
        neverlink_library_stays_off_the_plugin_classpath = _make_classpath_test(
            library = _plugin_library_over_neverlink(direct_compiler_dep = False),
            target_embedded_compiler = False,
            want = ["{test}_plugin_dep.jar"],
        ),
        library_reached_by_another_edge_stays_on_the_plugin_classpath = _make_classpath_test(
            library = _plugin_library_over_neverlink(direct_compiler_dep = True),
            target_embedded_compiler = False,
            want = ["{test}_plugin_dep.jar", "{test}_compiler.jar"],
        ),
        neverlink_library_stays_off_the_reshaded_plugin_classpath = _make_classpath_test(
            library = _plugin_library_over_neverlink(direct_compiler_dep = False),
            target_embedded_compiler = True,
            want = ["{test}_plugin_dep_lib_reshaded_{test}_plugin_dep.jar"],
        ),
        jar_through_an_unwalked_attribute_stays_original_on_the_reshaded_plugin_classpath = _make_classpath_test(
            library = _plugin_library_through_lib,
            target_embedded_compiler = True,
            want = ["{test}_plugin_dep_lib_reshaded_{test}_plugin_dep.jar", "{test}_lib.jar"],
        ),
        toolchain_runtime_jars_stay_original_on_the_reshaded_plugin_classpath = _make_classpath_test(
            library = _kotlin_plugin_library,
            target_embedded_compiler = True,
            want = ["{test}_plugin_dep_lib_reshaded_{test}_plugin_dep_lib.jar", "kotlin-stdlib.jar"],
        ),
        associate_jars_get_copies_on_the_reshaded_plugin_classpath = _make_classpath_test(
            library = _kotlin_plugin_library_with_associate,
            target_embedded_compiler = True,
            want = [
                "{test}_plugin_dep_lib_reshaded_{test}_plugin_dep_lib.jar",
                "{test}_core_reshaded_{test}_core.jar",
                "kotlin-stdlib.jar",
            ],
        ),
        ksp_neverlink_library_stays_off_the_processor_classpath = _make_classpath_test(
            library = _plugin_library_over_neverlink(direct_compiler_dep = False),
            target_embedded_compiler = False,
            ksp = True,
            want = ["{test}_plugin_dep.jar"],
        ),
        ksp_jar_through_an_unwalked_attribute_stays_original_on_the_reshaded_processor_classpath = _make_classpath_test(
            library = _plugin_library_through_lib,
            target_embedded_compiler = True,
            ksp = True,
            want = ["{test}_plugin_dep_lib_reshaded_{test}_plugin_dep.jar", "{test}_lib.jar"],
        ),
        ksp_toolchain_runtime_jars_stay_original_on_the_reshaded_processor_classpath = _make_classpath_test(
            library = _kotlin_plugin_library,
            target_embedded_compiler = True,
            ksp = True,
            want = ["{test}_plugin_dep_lib_reshaded_{test}_plugin_dep_lib.jar", "kotlin-stdlib.jar"],
        ),
    )
