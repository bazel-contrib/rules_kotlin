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
"""Rules for assembling rules_kotlin release archive."""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@rules_pkg//:pkg.bzl", "pkg_tar")

def release_archive(name, srcs = None, src_map = {}, package_dir = None, extension = "tgz", deps = None):
    """Creates a tar of the srcs and renamed label artifacts.

    Usage:

    //:BUILD
    load("//src/main/starlark/release:packager.bzl", "release_archive")
    release_archive(
        name = "release_archive",
        src_map = {
            "MODULE.release.bazel": "MODULE.bazel",
        },
        deps = [
            "//dep:pkg"
        ],
    )

    //dep:BUILD
    load("//src/main/starlark/release:packager.bzl", "release_archive")
    release_archive(
        name = "pkg",
        srcs = [
            ":label_of_artifact",
        ],
    )


    Args:
        name: target identifier, points to a pkg_tar target.
        srcs: files to include in the distribution.
        src_map: dict of <label>:<name string> for labels to be renamed and included in the distribution.
        package_dir: directory to place the srcs and src_map under. Defaults to the current directory.
        extension: Extension of the archive. Controls the type of tar file generated.
        deps: release_archives to be included.
    """

    if package_dir == None:
        pkg_name = native.package_name()
        local_pkg_index = pkg_name.rfind("/")
        if local_pkg_index > -1:
            pkg_name = pkg_name[local_pkg_index:]
        package_dir = pkg_name

    if srcs == None:
        srcs = []

    for source, target in src_map.items():
        rename_name = name + "_" + target
        _rename(
            name = rename_name,
            source = source,
            target = target,
        )
        srcs.append(rename_name)

    pkg_tar(
        name = name,
        srcs = srcs if srcs != None else [],
        extension = extension,
        package_dir = package_dir,
        visibility = ["//visibility:public"],
        deps = deps if deps != None else [],
    )

def _rename_impl(ctx):
    out_file = ctx.actions.declare_file(ctx.label.name + "/" + ctx.attr.target)
    in_file = ctx.file.source
    ctx.actions.run_shell(
        inputs = [in_file],
        outputs = [out_file],
        progress_message = "%s -> %s" % (in_file, ctx.attr.target),
        command = "mkdir -p {dir} && cp {in_file} {out_file}".format(
            dir = ctx.label.name,
            in_file = in_file.path,
            out_file = out_file.path,
        ),
    )
    return [DefaultInfo(files = depset([out_file]))]

_rename = rule(
    implementation = _rename_impl,
    attrs = {
        "source": attr.label(allow_single_file = True, mandatory = True),
        "target": attr.string(mandatory = True),
    },
)

def _release_module_impl(ctx):
    out_file = ctx.actions.declare_file(ctx.label.name + "/MODULE.bazel")
    args = ctx.actions.args()
    args.add(ctx.file.template)
    args.add(out_file)
    args.add(ctx.attr._tag[BuildSettingInfo].value)
    args.add_all(ctx.files.assets)
    ctx.actions.run_shell(
        inputs = [ctx.file.template] + ctx.files.assets,
        outputs = [out_file],
        arguments = [args],
        progress_message = "Generating release MODULE.bazel %{output}",
        command = """\
set -euo pipefail
template="$1"
out_file="$2"
tag="$3"
shift 3
sha256() {
  if command -v sha256sum > /dev/null; then sha256sum < "$1"; else shasum -a 256 < "$1"; fi | cut -d' ' -f1
}
expressions=(-e "s|{tag}|$tag|g")
for asset in "$@"; do
  expressions+=(-e "s|{sha256:$(basename "$asset")}|$(sha256 "$asset")|g")
done
sed "${expressions[@]}" "$template" > "$out_file"
if grep -q '{sha256:' "$out_file"; then
  echo "$template refers to a release asset that is not in assets" >&2
  exit 1
fi
""",
    )
    return [DefaultInfo(files = depset([out_file]))]

release_module = rule(
    implementation = _release_module_impl,
    doc = """Fills in the release tag and the checksums of release assets in a MODULE.bazel template.

    The template refers to the tag as `{tag}` and to the checksum of an asset as
    `{sha256:<basename of the asset>}`.
    """,
    attrs = {
        "assets": attr.label_list(allow_files = True),
        "template": attr.label(allow_single_file = True, mandatory = True),
        "_tag": attr.label(default = "//src/main/starlark/release:tag"),
    },
)
