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
load("@rules_java//java:defs.bzl", "java_test")
load("//kotlin:jvm.bzl", "kt_jvm_test")

def _get_class_name(kwargs):
    if len(kwargs.get("srcs", [])) == 1:
        return (
            native.package_name().replace("src/test/kotlin/", "") +
            "." + kwargs["srcs"][0]
        ).replace("/", ".").replace(".java", "").replace(".kt", "")
    else:
        return kwargs["test_classes"]

def kt_rules_test(name, **kwargs):
    args = dict(kwargs.items())
    args.setdefault("size", "small")
    args.setdefault("data", [])
    args.setdefault("jvm_flags", [])

    args["deps"] = args.setdefault("deps", []) + ["//src/test/kotlin/io/bazel/kotlin/builder:test_lib"]
    for dep in [
        "//src/main/kotlin:skip-code-gen",
        "//src/main/kotlin:jdeps-gen",
        "//src/main/kotlin:compiler",
        "//kotlin/compiler:annotations",
        "//kotlin/compiler:jvm-abi-gen",
        "//kotlin/compiler:kotlin-compiler",
        "//kotlin/compiler:kotlin-annotation-processing",
        "//kotlin/compiler:kotlin-stdlib",
        "//kotlin/compiler:kotlin-reflect",
        "//kotlin/compiler:kotlinx-coroutines-core-jvm",
        "//kotlin/compiler:kotlinx-serialization-core-jvm",
        "//kotlin/compiler:kotlinx-serialization-json-jvm",
        "//kotlin/compiler:kotlin-build-tools-impl",
        "@rules_kotlin_maven//:org_jetbrains_kotlin_kotlin_compiler_embeddable",
        "@rules_kotlin_maven//:org_jetbrains_kotlin_kotlin_annotation_processing_embeddable",
        "@rules_kotlin_maven//:org_jetbrains_kotlin_kotlin_daemon_client",
    ] + args["data"]:
        if dep not in args["data"]:
            args["data"].append(dep)
        args["jvm_flags"].append("-D%s=$(rlocationpath %s)" % (dep.replace("/", ".").replace(":", "."), dep))

    args.setdefault("test_class", _get_class_name(kwargs))
    for f in args.get("srcs"):
        if f.endswith(".kt"):
            kt_jvm_test(name = name, **args)
            return
    java_test(name = name, **args)

def kt_rules_e2e_test(name, **kwargs):
    kwargs.setdefault("size", "small")
    kwargs["deps"] = kwargs.setdefault("deps", []) + ["//src/test/kotlin/io/bazel/kotlin:assertion_test_case"]
    kwargs.setdefault("test_class", _get_class_name(kwargs))
    kt_jvm_test(name = name, **kwargs)
