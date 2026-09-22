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
"""Repository that downloads multiple files."""

def _build_content():
    return """
package(default_visibility = ["//visibility:public"])
exports_files(glob(["**"]))
"""

def _module_content(name, version):
    return """
module(
    name = "{name}",
    version = "{version}",
)
""".format(name = name, version = version)

def _multi_file_repository(repository_ctx):
    """Downloads multiple files and stages them."""
    attr = repository_ctx.attr

    if attr.urls.keys() != attr.sha256.keys():
        fail("`urls` and `sha256` keys must match.")

    for name, url in attr.urls.items():
        sha256 = attr.sha256.get(name, None)
        repository_ctx.download(
            url = url,
            output = name,
            sha256 = sha256,
        )

    repository_ctx.file(
        "MODULE.bazel",
        content = _module_content(name = attr.name, version = attr.version),
    )
    repository_ctx.file(
        "BUILD.bazel",
        content = _build_content(),
        executable = False,
    )

    # Bazel <8.3.0 lacks repository_ctx.repo_metadata
    if not hasattr(repository_ctx, "repo_metadata"):
        return None

    return repository_ctx.repo_metadata(
        attrs_for_reproducibility = {
            "sha256": attr.sha256,
            "version": attr.version,
        },
    )

multi_file_repository = repository_rule(
    implementation = _multi_file_repository,
    doc = "Download multiple files from urls and copies them to the provided name",
    attrs = {
        "sha256": attr.string_dict(),
        "urls": attr.string_dict(),
        "version": attr.string(),
    },
)
