# Copyright 2020 The Bazel Authors. All rights reserved.
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
"""Defines jar_jar rule and action for shading jars."""

load("@rules_java//java:defs.bzl", "JavaInfo", "java_common")

def jarjar_action(actions, rules, input, output, jarjar):
    actions.run(
        inputs = [rules, input],
        outputs = [output],
        executable = jarjar,
        progress_message = "jarjar %%{label}",
        arguments = ["process", rules.path, input.path, output.path],
    )
    return output

def _jar_jar_impl(ctx):
    jar = jarjar_action(
        actions = ctx.actions,
        rules = ctx.file.rules,
        input = ctx.file.input_jar,
        output = ctx.outputs.jar,
        jarjar = ctx.executable.jarjar_runner,
    )
    return [
        DefaultInfo(
            files = depset([jar]),
            runfiles = ctx.runfiles(files = [jar]),
        ),
        JavaInfo(
            output_jar = jar,
            compile_jar = jar,
        ),
    ]

jar_jar = rule(
    implementation = _jar_jar_impl,
    attrs = {
        "input_jar": attr.label(allow_single_file = True),
        "jarjar_runner": attr.label(
            executable = True,
            cfg = "exec",
            default = Label("//third_party:jarjar_runner"),
        ),
        "rules": attr.label(allow_single_file = True),
    },
    outputs = {
        "jar": "%{name}.jar",
    },
    provides = [JavaInfo],
)

def _reshade_java_info_impl(ctx):
    # Reshade every jar in the input JavaInfo's transitive runtime closure, mirroring
    # kotlin/internal/jvm/impl.bzl _reshade_kotlinc_jars: jarjar per jar (guava-shielded)
    # then merge the per-jar JavaInfos, since JavaInfo takes a single jar.
    jars = ctx.attr.target[JavaInfo].transitive_runtime_jars.to_list()
    reshaded = []
    for i, jar in enumerate(jars):
        output = ctx.actions.declare_file(
            "%s_reshaded_%d_%s" % (ctx.label.name, i, jar.basename),
        )
        jarjar_action(
            actions = ctx.actions,
            rules = ctx.file.rules,
            input = jar,
            output = output,
            jarjar = ctx.executable.jarjar_runner,
        )
        reshaded.append(output)

    java_info = java_common.merge([
        JavaInfo(output_jar = jar, compile_jar = jar)
        for jar in reshaded
    ])
    return [
        DefaultInfo(
            files = depset(reshaded),
            runfiles = ctx.runfiles(files = reshaded),
        ),
        java_info,
    ]

# Shared reshade helper: takes a JavaInfo's transitive runtime jars + a jarjar rules file,
# reshades each jar (guava-shielding), and returns a shaded JavaInfo reusable via runtime_deps.
# Single source of truth reused by the bootstrap busybox library and (future) release path.
reshade_java_info = rule(
    implementation = _reshade_java_info_impl,
    attrs = {
        "target": attr.label(providers = [JavaInfo]),
        "jarjar_runner": attr.label(
            executable = True,
            cfg = "exec",
            default = Label("//third_party:jarjar_runner"),
        ),
        "rules": attr.label(allow_single_file = True),
    },
    provides = [JavaInfo],
)
