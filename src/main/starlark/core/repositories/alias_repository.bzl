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
Repository to provide a facade for targets.
"""

def _alias_repository(r_ctx):
    """Generate BUILD file that aliases labels to repository."""
    r_ctx.file(
        "BUILD",
        content = "\n".join(
            [
                """package(default_visibility = ["%s"])""" % r_ctx.attr.default_visibility,
            ] + [
                """alias(name="%s", actual="%s")""" % (lbl.name, lbl)
                for lbl in r_ctx.attr.labels
            ],
        ),
    )
    if not hasattr(r_ctx, "repo_metadata"):
        return None
    return r_ctx.repo_metadata(
        reproducible = True,
    )

alias_repository = repository_rule(
    implementation = _alias_repository,
    attrs = {
        "default_visibility": attr.string(
            doc = "Alias visibility",
            default = "//visibility:public",
        ),
        "labels": attr.label_list(
            doc = "List of labels to expose.",
        ),
    },
)
