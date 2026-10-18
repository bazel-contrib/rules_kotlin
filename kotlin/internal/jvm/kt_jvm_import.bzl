# Copyright 2018 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""kt_jvm_import rule and implementation."""

load("@rules_java//java:defs.bzl", "JavaInfo")
load(
    "//kotlin/internal:defs.bzl",
    "KtPluginConfiguration",
    _KspPluginInfo = "KspPluginInfo",
    _KtCompilerPluginInfo = "KtCompilerPluginInfo",
    _KtJvmInfo = "KtJvmInfo",
)
load("//kotlin/internal/utils:utils.bzl", _utils = "utils")

_ATTRS = {
    "deps": attr.label_list(
        doc = """Compile and runtime dependencies""",
        default = [],
        mandatory = False,
        providers = [JavaInfo],
    ),
    "exported_compiler_plugins": attr.label_list(
        doc = """\
Exported compiler plugins.

Compiler plugins listed here will be treated as if they were added in the plugins
attribute of any targets that directly depend on this target. Like java_plugins'
exported_plugins, this is not transitive""",
        default = [],
        cfg = "exec",
        providers = [[_KtCompilerPluginInfo], [KtPluginConfiguration], [_KspPluginInfo]],
    ),
    "exports": attr.label_list(
        doc = """\
Exported libraries.

Deps listed here will be made available to other rules, as if the parents explicitly depended on
these deps. This is not true for regular (non-exported) deps.""",
        default = [],
        providers = [JavaInfo, _KtJvmInfo],
    ),
    "jar": attr.label(
        doc = """The jar listed here is equivalent to an export attribute.""",
        allow_single_file = True,
        cfg = "target",
    ),
    "jars": attr.label_list(
        doc = """\
The jars listed here are equavalent to an export attribute. The label should be either to a single
class jar, or one or more filegroup labels.  The filegroups, when resolved, must contain  only one jar
containing classes, and (optionally) one peer file containing sources, named `<jarname>-sources.jar`.

DEPRECATED - please use `jar` and `srcjar` attributes.""",
        allow_files = True,
        cfg = "target",
    ),
    "neverlink": attr.bool(
        doc = """If true only use this library for compilation and not at runtime.""",
        default = False,
    ),
    "runtime_deps": attr.label_list(
        doc = """Additional runtime deps.""",
        default = [],
        mandatory = False,
        providers = [JavaInfo],
    ),
    "srcjar": attr.label(
        doc = """The sources for the class jar.""",
        allow_single_file = True,
        cfg = "target",
        # TODO(https://github.com/bazelbuild/intellij/issues/1616): Remove when the Intellij Aspect has the
        #  correct null checks.
        default = "//third_party:empty.jar",
    ),
}

# buildifier: disable=unused-variable
def _is_source_jar_stub(jar):
    """Workaround for intellij plugin expecting a source jar"""
    return jar.path.endswith("third_party/empty.jar")

def _unify_jars(ctx):
    if bool(ctx.attr.jar):
        return struct(class_jar = ctx.file.jar, source_jar = ctx.file.srcjar, ijar = None)
    else:
        # Legacy handling.
        jars = []
        source_jars = []
        if (ctx.file.srcjar and not ("%s" % ctx.file.srcjar.path).endswith("third_party/empty.jar")):
            source_jars.append(ctx.file.srcjar)

        # There must be a single jar jar and it can either be a filegroup or a JavaInfo.
        for jar in ctx.attr.jars:
            # If a JavaInfo is available it's because it was picked up from a `maven_jar` style attribute -- e.g.,
            # @com_google_guava_guava//jar. so the transitive_compile_jars or the transitive_runtime_jars should not be
            # visited -- descending into these results in ijars entering the graph.
            if JavaInfo in jar:
                jars += jar[JavaInfo].full_compile_jars.to_list()
                source_jars += jar[JavaInfo].transitive_source_jars.to_list()
            else:
                # this branch occurs when the attr was a filegroup.
                for file in jar.files.to_list():
                    if file.basename.endswith("-sources.jar"):
                        source_jars.append(file)
                    elif file.basename.endswith(".jar"):
                        jars.append(file)
                    else:
                        fail("a jar pointing to a filegroup must either end with -sources.jar or .jar: %s", file)

        if len(jars) > 1:
            fail("Got more than one jar, this is an error create an issue: %s" % jars)
        if len(source_jars) > 1:
            fail("Got more than one source jar. " +
                 "Did you include both srcjar and a sources jar in the jars attribute?: %s" % source_jars)
        return struct(class_jar = jars[0], source_jar = source_jars[0] if len(source_jars) == 1 else None, ijar = None)

def kt_jvm_import_impl(ctx):
    """Implements the kt_jvm_import rule.

    Args:
        ctx: the rule context providing the imported jar attributes.

    Returns:
        The list of providers exposing the imported jars.
    """
    if bool(ctx.attr.jars) and bool(ctx.attr.jar):
        fail("Cannot use both jars= and jar= attribute.  Prefer jar=")

    artifact = _unify_jars(ctx)
    kt_info = _KtJvmInfo(
        module_name = _utils.derive_module_name(ctx),
        module_jars = [],
        exported_compiler_plugins = depset(getattr(ctx.attr, "exported_compiler_plugins", [])),
        outputs = struct(
            jars = [artifact],
        ),
    )

    return [
        DefaultInfo(
            files = depset(direct = [artifact.class_jar]),
            runfiles = ctx.runfiles(
                # Append class jar with the optional sources jar
                files = [artifact.class_jar] + [artifact.source_jar] if artifact.source_jar else [],
            ).merge_all([d[DefaultInfo].default_runfiles for d in ctx.attr.deps]),
        ),
        JavaInfo(
            output_jar = artifact.class_jar,
            compile_jar = artifact.class_jar,
            source_jar = artifact.source_jar,
            runtime_deps = [dep[JavaInfo] for dep in ctx.attr.runtime_deps if JavaInfo in dep],
            deps = [dep[JavaInfo] for dep in ctx.attr.deps if JavaInfo in dep],
            exports = [d[JavaInfo] for d in getattr(ctx.attr, "exports", [])],
            neverlink = getattr(ctx.attr, "neverlink", False),
        ),
        kt_info,
    ]

kt_jvm_import = rule(
    doc = """\
Import Kotlin jars.

## examples

```bzl
# Old style usage -- reference file groups, do not used this.
kt_jvm_import(
    name = "kodein",
    jars = [
        "@com_github_salomonbrys_kodein_kodein//jar:file",
        "@com_github_salomonbrys_kodein_kodein_core//jar:file"
    ]
)

# This style will pull in the transitive runtime dependencies of the targets as well.
kt_jvm_import(
    name = "kodein",
    jars = [
        "@com_github_salomonbrys_kodein_kodein//jar",
        "@com_github_salomonbrys_kodein_kodein_core//jar"
    ]
)

# Import a single kotlin jar.
kt_jvm_import(
    name = "kotlin-stdlib",
    jars = ["lib/kotlin-stdlib.jar"],
    srcjar = "lib/kotlin-stdlib-sources.jar"
)
```
""",
    attrs = _ATTRS,
    implementation = kt_jvm_import_impl,
    provides = [JavaInfo, _KtJvmInfo],
)
