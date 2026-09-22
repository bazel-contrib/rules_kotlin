# Copyright 2026 The Bazel Authors. All rights reserved.
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
"""
Generates release metadata, including installation guidance and jar manifest.
"""

def _release_metadata_impl(ctx):
    out_bzl = ctx.actions.declare_file(ctx.label.name + "/release_manifest.bzl")
    out_notes = ctx.actions.declare_file(ctx.label.name + "/release_notes.txt")

    version_key = "BUILD_EMBED_LABEL"
    version_file = ctx.info_file
    if not (ctx.attr.stamp == 1 and ctx.configuration.stamp_enabled):
        version_file = ctx.actions.declare_file(ctx.label.name + "/dev_status.txt")
        ctx.actions.write(
            version_file,
            version_key + " 0.0.0-dev",
        )

    args = ctx.actions.args()
    args.add("--version_file", version_file)
    args.add("--version_key", version_key)
    args.add("--out_bzl", out_bzl)
    args.add("--out_notes", out_notes)

    default_url = ctx.attr.urls.get("*", "")
    symlinks = []
    for i, target in enumerate(ctx.attr.jars):
        # remove trailing extension from label
        jar = ctx.files.jars[i]
        name = ctx.attr.jars[target]
        args.add("--jar", name + "=" + jar.path)
        args.add("--url", name + "=" + ctx.attr.urls.get(name, default_url))
        symlink = ctx.actions.declare_file(ctx.label.name + "/jars/" + name)
        symlinks.append(symlink)
        ctx.actions.symlink(
            output = symlink,
            target_file = jar,
        )

    ctx.actions.run(
        mnemonic = "GenerateReleaseMetadata",
        executable = ctx.executable._tool,
        arguments = [args],
        inputs = depset(ctx.files.jars + [version_file]),
        outputs = [out_bzl, out_notes],
    )

    return [
        DefaultInfo(files = depset([out_bzl])),
        OutputGroupInfo(
            release = depset(symlinks + [out_notes]),
            jars = depset(symlinks),
        ),
    ]

release_metadata = rule(
    implementation = _release_metadata_impl,
    doc = "Generates release metadata.",
    attrs = {
        "jars": attr.label_keyed_string_dict(
            allow_files = [".jar"],
            doc = "jar file -> logical name.",
        ),
        "stamp": attr.int(doc = "special attribute that enables embedding build label", default = -1),
        "urls": attr.string_dict(
            doc = "logical name -> url template. '*' defines the default template",
        ),
        "_tool": attr.label(
            default = "//src/main/kotlin/io/bazel/kotlin/generate:release_metadata",
            executable = True,
            cfg = "exec",
        ),
    },
)
