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

"""Kaptish helper functions for annotation processing optimization.

Kaptish is a performance optimization (1.75-2x faster than KAPT) that:
1. Compiles Kotlin sources first to .class files
2. Injects those compiled classes into javac's annotation processing phase
3. Runs annotation processors on the compiled classes (no stubs needed)
"""

def is_kaptish_enabled(ctx, toolchains, has_kt_sources, has_annotation_processors):
    """Determine if kaptish should be used for this target.

    Args:
        ctx: Rule context
        toolchains: Toolchains struct containing kt toolchain
        has_kt_sources: Whether the target has Kotlin sources
        has_annotation_processors: Whether annotation processors are configured

    Returns:
        True if kaptish should be used, False otherwise
    """
    return (
        has_kt_sources and
        has_annotation_processors and
        toolchains.kt.experimental_kaptish_enabled and
        "kaptish_disabled" not in ctx.attr.tags
    )

def create_kaptish_placeholder(ctx):
    """Create a placeholder Java file for annotation processing.

    When using kaptish without any Java source files, we need at least one
    Java file to trigger javac's annotation processing phase.

    Args:
        ctx: Rule context

    Returns:
        A File object for the generated placeholder Java file
    """

    # Sanitize the label name for use as a Java class name
    class_name = ctx.label.name.replace("-", "_").replace(".", "_") + "_KaptishPlaceholder"
    placeholder = ctx.actions.declare_file(class_name + ".java")
    ctx.actions.write(
        placeholder,
        "// Auto-generated placeholder for Kaptish annotation processing\n" +
        "@SuppressWarnings(\"unused\")\n" +
        "final class " + class_name + " {}\n",
    )
    return placeholder
