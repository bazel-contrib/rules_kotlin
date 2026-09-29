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
"""Bootstraps for building the rules_kotlin builder."""

load("@rules_java//java:defs.bzl", "java_binary", "java_library")
load("//kotlin:lint.bzl", _ktlint_fix = "ktlint_fix", _ktlint_test = "ktlint_test")
load("//src/main/starlark/core/compile:rules.bzl", "core_kt_jvm_library")
load("//third_party:jarjar.bzl", "reshade_java_info")

def kt_bootstrap_library(name, deps = [], neverlink_deps = [], srcs = [], visibility = [], kotlinc_opts = [], **kwargs):
    """Simple compilation of a kotlin library using a non-persistent worker.

    The target is a JavaInfo provider.

    Args:
        name:  for the library target.
        deps: dependencies, set as runtime of the library.
        neverlink_deps: compile only dependencies.
        srcs: Kotlin sources compiled into the library.
        visibility: the visibility of the library target.
        kotlinc_opts: the kotlinc options applied to the compilation.
        **kwargs: additional arguments forwarded to the underlying rules.
    """
    core_kt_jvm_library(
        name = "%s_neverlink" % name,
        exports = neverlink_deps,
        neverlink = True,
    )

    core_kt_jvm_library(
        name = name,
        srcs = srcs,
        visibility = visibility,
        deps = deps + ["%s_neverlink" % name],
        kotlinc_opts = kotlinc_opts,
        **kwargs
    )

    _ktlint_test(
        name = "%s_ktlint_test" % name,
        srcs = srcs,
        visibility = ["//visibility:private"],
        config = "//:ktlint_editorconfig",
        tags = ["no-ide", "ktlint"],
        **kwargs
    )

    _ktlint_fix(
        name = "%s_ktlint_fix" % name,
        srcs = srcs,
        visibility = ["//visibility:public"],
        config = "//:ktlint_editorconfig",
        tags = ["no-ide", "ktlint"],
        **kwargs
    )

def kt_bootstrap_worker_jar(name, deps, shade_rules, visibility = ["//visibility:public"]):
    """Builds ONE reusable shaded busybox LIBRARY consumed by thin launchers via runtime_deps.

    Aggregates all worker code (mains + worker framework + tasks + SPI plugins)
    into a java_library, then reshades every jar in its transitive runtime closure per-jar
    (guava-shielding) into a single shaded JavaInfo. No java_binary(create_executable=False)
    fat/deploy jar is materialized.

    Args:
        name: name of the shaded library target (a JavaInfo provider).
        deps: runtime deps whose transitive runtime jars are aggregated then reshaded.
        shade_rules: jarjar shade rules applied per jar.
        visibility: the visibility of the shaded library target.
    """
    java_library(
        name = "%s_lib" % name,
        runtime_deps = deps,
        visibility = ["//visibility:private"],
    )

    reshade_java_info(
        name = name,
        target = ":%s_lib" % name,
        rules = shade_rules,
        visibility = visibility,
    )

def kt_bootstrap_worker_launcher(
        name,
        main_class,
        worker_jar,
        jvm_flags = [],
        data = [],
        final_runtime_deps = [],
        visibility = ["//visibility:public"]):
    """A thin java_binary launcher over the shared shaded busybox library.

    No --add-opens / IgnoreUnrecognizedVMOptions are injected here; those belong to the
    individual launcher's explicit jvm_flags (only the build launcher needs them).

    Args:
        name: name of the launcher binary target.
        main_class: fully qualified main class to launch.
        worker_jar: the shaded busybox library consumed via runtime_deps.
        jvm_flags: JVM flags passed to the launched binary.
        data: files bundled with the binary.
        final_runtime_deps: additional (unshaded) runtime deps, e.g. the Kotlin stdlibs.
        visibility: the visibility of the launcher target.
    """
    java_binary(
        name = name,
        data = data,
        jvm_flags = jvm_flags,
        main_class = main_class,
        visibility = visibility,
        runtime_deps = [worker_jar] + final_runtime_deps,
    )
