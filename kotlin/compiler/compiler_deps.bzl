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

_COMPILER_TARGETS = [
    ("kotlin-stdlib", "org_jetbrains_kotlin_kotlin_stdlib"),
    ("kotlin-reflect", "org_jetbrains_kotlin_kotlin_reflect"),
    ("kotlin-test", "org_jetbrains_kotlin_kotlin_test"),
    ("annotations", "org_jetbrains_annotations"),
    ("kotlinx-coroutines-core-jvm", "org_jetbrains_kotlinx_kotlinx_coroutines_core_jvm"),
    ("kotlinx-serialization-core-jvm", "org_jetbrains_kotlinx_kotlinx_serialization_core_jvm"),
    ("kotlinx-serialization-json-jvm", "org_jetbrains_kotlinx_kotlinx_serialization_json_jvm"),
    ("kotlin-annotation-processing", "org_jetbrains_kotlin_kotlin_annotation_processing"),
    ("jvm-abi-gen", "org_jetbrains_kotlin_jvm_abi_gen"),
    ("kotlin-script-runtime", "org_jetbrains_kotlin_kotlin_script_runtime"),
    ("allopen-compiler-plugin", "org_jetbrains_kotlin_kotlin_allopen_compiler_plugin"),
    ("noarg-compiler-plugin", "org_jetbrains_kotlin_kotlin_noarg_compiler_plugin"),
    ("sam-with-receiver-compiler-plugin", "org_jetbrains_kotlin_kotlin_sam_with_receiver_compiler_plugin"),
    ("kotlinx-serialization-compiler-plugin", "org_jetbrains_kotlin_kotlin_serialization_compiler_plugin"),
    ("parcelize-compiler-plugin", "org_jetbrains_kotlin_kotlin_parcelize_compiler"),
    ("parcelize-runtime", "org_jetbrains_kotlin_kotlin_parcelize_runtime"),
    ("kotlin-daemon-client", "org_jetbrains_kotlin_kotlin_daemon_client"),
    ("kotlin-build-tools-impl", "org_jetbrains_kotlin_kotlin_build_tools_impl"),
    ("kotlin-compiler", "org_jetbrains_kotlin_kotlin_compiler"),
    ("kotlin-compiler-embeddable", "org_jetbrains_kotlin_kotlin_compiler_embeddable"),
    ("kotlin-annotation-processing-embeddable", "org_jetbrains_kotlin_kotlin_annotation_processing_embeddable"),
    ("symbol-processing-aa", "com_google_devtools_ksp_symbol_processing_aa"),
    ("symbol-processing-api", "com_google_devtools_ksp_symbol_processing_api"),
    ("symbol-processing-common-deps", "com_google_devtools_ksp_symbol_processing_common_deps"),
    ("ksp-intellij-kotlinx-coroutines-core-jvm", "org_jetbrains_intellij_deps_kotlinx_kotlinx_coroutines_core_jvm"),
]

def kt_define_compiler_targets():
    for name, actual in _COMPILER_TARGETS:
        native.alias(
            name = name,
            actual = "@rules_kotlin_maven//:%s" % actual,
        )

    native.alias(
        name = "kotlin-serialization-compiler-plugin",
        actual = ":kotlinx-serialization-compiler-plugin",
    )

# List of Kotlin standard library targets for runtime dependencies.
# Note: kotlin-stdlib-jdk7 and kotlin-stdlib-jdk8 are not needed as of Kotlin 1.8+,
# since JDK 8 extensions are included in the main stdlib.
KOTLIN_STDLIBS = [
    "//kotlin/compiler:annotations",
    "//kotlin/compiler:kotlin-reflect",
    "//kotlin/compiler:kotlin-stdlib",
    "//kotlin/compiler:kotlin-compiler",
    "//kotlin/compiler:kotlin-build-tools-impl",
    "//kotlin/compiler:kotlin-annotation-processing",
    "//kotlin/compiler:jvm-abi-gen",
    "//kotlin/compiler:kotlinx-coroutines-core-jvm",
    "//kotlin/compiler:kotlinx-serialization-core-jvm",
    "//kotlin/compiler:kotlinx-serialization-json-jvm",
]

# Build worker should not pull kotlin-compiler from final runtime deps to avoid classpath leakage.
KOTLIN_BUILD_RUNTIME_STDLIBS = [
    dep
    for dep in KOTLIN_STDLIBS
    if dep != "//kotlin/compiler:kotlin-compiler"
]

# KSP2 needs IntelliJ coroutines variant rather than the default kotlinx artifact.
KSP2_RUNTIME_STDLIBS = [
    dep
    for dep in KOTLIN_STDLIBS
    if dep != "//kotlin/compiler:kotlinx-coroutines-core-jvm"
] + [
    "//kotlin/compiler:ksp-intellij-kotlinx-coroutines-core-jvm",
]
