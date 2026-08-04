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
"""Defines generate_jvm_service rule."""

load("@rules_java//java:defs.bzl", "JavaInfo")

def _generate_jvm_service_impl(ctx):
    """
    Creates service files for use in a jar META-INF/services directory.

    Args:
      ctx: rule context expected to have a "services" dict of impl to service:qualified classes, implicit dep on _zipper and outputs.jar
    Returns:
      a list of JavaInfo, DefaultInfo with runfiles.
    """
    impl_to_service = ctx.attr.services
    jar = ctx.outputs.jar

    service_to_impl = dict()
    zipper_args = ctx.actions.args()
    zipper_args.add_all(["c", jar])
    zipper_inputs = []
    for impl, srv in impl_to_service.items():
        service_to_impl.setdefault(srv, [])
        service_to_impl[srv].append(impl)

    for srv, impls in service_to_impl.items():
        f = _write_service_file(ctx, srv, impls)
        zipper_inputs.append(f)
        zipper_args.add("META-INF/services/" + srv + "=" + f.path)

    ctx.actions.run(
        mnemonic = "ServiceFilesJar",
        executable = ctx.executable._zipper,
        inputs = zipper_inputs,
        outputs = [jar],
        arguments = [zipper_args],
        progress_message = "JVM service info jar for %%{label}",
    )
    return [
        JavaInfo(
            output_jar = jar,
            compile_jar = jar,
            source_jar = jar,
            runtime_deps = [],
            exports = [],
            neverlink = False,
        ),
        DefaultInfo(
            files = depset([jar]),
            runfiles = ctx.runfiles(files = [jar]),
        ),
    ]

def _write_service_file(ctx, srv, impls):
    f = ctx.actions.declare_file(ctx.label.name + "/" + srv)
    ctx.actions.write(f, "\n".join(impls))
    return f

generate_jvm_service = rule(
    doc = """Rule to generate META-INF/services files in a jar.""",
    implementation = _generate_jvm_service_impl,
    attrs =
        {
            "services": attr.string_dict(
                doc = "a dictionary of <fully qualified class>:<service name>",
                mandatory = True,
            ),
            "_zipper": attr.label(
                executable = True,
                cfg = "exec",
                default = Label("@bazel_tools//tools/zip:zipper"),
                allow_files = True,
            ),
        },
    outputs = {
        "jar": "%{name}.jar",
    },
)
