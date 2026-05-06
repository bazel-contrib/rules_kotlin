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
load("@rules_java//java:defs.bzl", "java_binary")
load("@bazel_jar_jar//:jar_jar.bzl", "jar_jar")
load("//kotlin:lint.bzl", _ktlint_fix = "ktlint_fix", _ktlint_test = "ktlint_test")
load("//src/main/starlark/core/compile:rules.bzl", "core_kt_jvm_library")

def kt_bootstrap_library(name, deps = [], neverlink_deps = [], srcs = [], visibility = [], kotlinc_opts = [], **kwargs):
    """
    Simple compilation of a kotlin library using a non-persistent worker. The target is a JavaInfo provider.

    deps: the dependenices, the are setup as runtime_deps of the library.
    neverlink_deps: deps that won't be linked.
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

def kt_bootstrap_binary(
        name,
        main_class,
        runtime_deps,
        shade_rules,
        jvm_flags = [],
        data = [],
        final_runtime_deps = [],
        visibility = ["//visibility:public"]):
    raw = name + "_raw"
    jar_jared = name + "_jarjar"

    java_binary(
        name = raw,
        create_executable = False,
        runtime_deps = runtime_deps,
    )

    # Shaded to ensure that libraries it uses are not leaked to
    # the code it's running against (e.g. dagger)
    jar_jar(
        name = jar_jared,
        input_jar = ":" + raw + "_deploy.jar",
        rules = shade_rules,
    )

    java_binary(
        name = name,
        data = data,
        jvm_flags = jvm_flags + [
            "-XX:+IgnoreUnrecognizedVMOptions",
            "--add-opens=java.base/java.nio=ALL-UNNAMED",
            "--add-opens=java.base/java.lang=ALL-UNNAMED",
            "--add-opens=jdk.compiler/com.sun.tools.javac.main=ALL-UNNAMED",
            "--add-opens=jdk.jdeps/com.sun.tools.jdeps=ALL-UNNAMED",
        ],
        main_class = main_class,
        visibility = visibility,
        runtime_deps = [":" + jar_jared] + final_runtime_deps,
    )
