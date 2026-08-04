# Copyright 2025 The Bazel Authors. All rights reserved.
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
"""Declares Kotlin compiler artifact coordinates."""

KOTLINC_ARTIFACTS = struct(
    jvm = struct(
        plugin = {
            "allopen-compiler-plugin": "lib/allopen-compiler-plugin.jar",
            "assignment-compiler-plugin": "lib/assignment-compiler-plugin.jar",
            "kotlin-serialization-compiler-plugin": "lib/kotlin-serialization-compiler-plugin.jar",
            "kotlinx-serialization-compiler-plugin": "lib/kotlinx-serialization-compiler-plugin.jar",
            "lombok-compiler-plugin": "lib/lombok-compiler-plugin.jar",
            "mutability-annotations-compat": "lib/mutability-annotations-compat.jar",
            "noarg-compiler-plugin": "lib/noarg-compiler-plugin.jar",
            "parcelize-compiler-plugin": "lib/parcelize-compiler.jar",
            "sam-with-receiver-compiler-plugin": "lib/sam-with-receiver-compiler-plugin.jar",
        },
        runtime = {
            "jvm-abi-gen": "lib/jvm-abi-gen.jar",
            "kotlin-stdlib": "lib/kotlin-stdlib.jar",
            "kotlin-stdlib-jdk7": "lib/kotlin-stdlib-jdk7.jar",
            "kotlin-stdlib-jdk7-sources": "lib/kotlin-stdlib-jdk7-sources.jar",
            "kotlin-stdlib-jdk8": "lib/kotlin-stdlib-jdk8.jar",
            "kotlin-stdlib-jdk8-sources": "lib/kotlin-stdlib-jdk8-sources.jar",
            "kotlin-stdlib-sources": "lib/kotlin-stdlib-sources.jar",
            "kotlin-test-junit": "lib/kotlin-test-junit.jar",
            "kotlin-test-junit-sources": "lib/kotlin-test-junit-sources.jar",
            "kotlin-test-junit5": "lib/kotlin-test-junit5.jar",
            "kotlin-test-junit5-sources": "lib/kotlin-test-junit5-sources.jar",
            "kotlin-test-testng": "lib/kotlin-test-testng.jar",
            "parcelize-runtime": "lib/parcelize-runtime.jar",
        },
        compile = {},
    ),
    core = struct(
        plugin = {},
        runtime = {
            "kotlin-reflect": "lib/kotlin-reflect.jar",
            "kotlin-reflect-sources": "lib/kotlin-reflect-sources.jar",
            "kotlin-script-runtime": "lib/kotlin-script-runtime.jar",
            "kotlin-script-runtime-sources": "lib/kotlin-script-runtime-sources.jar",
            "kotlin-test": "lib/kotlin-test.jar",
            "kotlin-test-sources": "lib/kotlin-test-sources.jar",
            "kotlin-test-testng-sources": "lib/kotlin-test-testng-sources.jar",
            "kotlinx-coroutines-core-jvm": "lib/kotlinx-coroutines-core-jvm.jar",
        },
        compile = {
            "annotations": "lib/annotations-13.0.jar",
            "kotlin-annotation-processing": "lib/kotlin-annotation-processing.jar",
            "kotlin-annotation-processing-cli": "lib/kotlin-annotation-processing-cli.jar",
            "kotlin-annotation-processing-runtime": "lib/kotlin-annotation-processing-runtime.jar",
            "kotlin-annotations-jvm": "lib/kotlin-annotations-jvm.jar",
            "kotlin-annotations-jvm-sources": "lib/kotlin-annotations-jvm-sources.jar",
            "kotlin-compiler": "lib/kotlin-compiler.jar",
            "kotlin-daemon": "lib/kotlin-daemon.jar",
            "kotlin-daemon-client": "lib/kotlin-daemon-client.jar",
            "kotlin-main-kts": "lib/kotlin-main-kts.jar",
            "kotlin-runner": "lib/kotlin-runner.jar",
            "kotlin-scripting-common": "lib/kotlin-scripting-common.jar",
            "kotlin-scripting-compiler": "lib/kotlin-scripting-compiler.jar",
            "kotlin-scripting-compiler-impl": "lib/kotlin-scripting-compiler-impl.jar",
            "kotlin-scripting-jvm": "lib/kotlin-scripting-jvm.jar",
            "scripting-compiler": "lib/scripting-compiler.jar",
        },
    ),
)

KOTLINC_ARTIFACT_LIST = {
    label: file
    for lang in ["jvm", "core"]
    for type in ["compile", "plugin", "runtime"]
    for (label, file) in getattr(getattr(KOTLINC_ARTIFACTS, lang), type).items()
}

# List of Kotlin standard library targets for runtime dependencies
KOTLIN_STDLIBS = [
    "//kotlin/compiler:annotations",
    "//kotlin/compiler:kotlin-stdlib",
    "//kotlin/compiler:kotlin-stdlib-jdk7",
    "//kotlin/compiler:kotlin-stdlib-jdk8",
    "//kotlin/compiler:kotlinx-coroutines-core-jvm",
]
