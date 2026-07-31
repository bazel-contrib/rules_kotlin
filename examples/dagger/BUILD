load("@rules_java//java:java_binary.bzl", "java_binary")

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
load("@rules_kotlin//kotlin:core.bzl", "define_kt_toolchain")
load("@rules_kotlin//kotlin:jvm.bzl", "kt_jvm_library")

package(default_visibility = ["//visibility:private"])

# Generate a srcjar to validate intellij plugin correctly attaches it.
genrule(
    name = "tea_lib_src",
    outs = ["tea_lib_src.srcjar"],
    cmd = """
cat << EOF > TeaPot.kt
package tea
object TeaPot {
    fun isEmpty() = true
}
EOF
$(JAVABASE)/bin/jar -cf $@ TeaPot.kt
rm TeaPot.kt
""",
    toolchains = ["@bazel_tools//tools/jdk:current_host_java_runtime"],
)

genrule(
    name = "chai_lib_src",
    outs = ["chai_lib_src.srcjar"],
    cmd = """
cat << EOF > ChaiCup.kt
package chai
object ChaiCup {
    fun isEmpty() = true
}
EOF
$(JAVABASE)/bin/jar -cf $@ ChaiCup.kt
rm ChaiCup.kt
""",
    toolchains = ["@bazel_tools//tools/jdk:current_host_java_runtime"],
)

genrule(
    name = "genereated_module_src",
    outs = ["genarated_module_src.srcjar"],
    cmd = """
cat << EOF > GeneratedModule.kt
package generated

import dagger.Provides
import dagger.Module

@Module
object GeneratedModule {
    @Provides
    fun provideString() = "Hello Coffee"
}
EOF
$(JAVABASE)/bin/jar -cf $@ GeneratedModule.kt
rm GeneratedModule.kt
""",
    toolchains = ["@bazel_tools//tools/jdk:current_host_java_runtime"],
)

kt_jvm_library(
    name = "generated_lib",
    srcs = [":genereated_module_src"],
    deps = [
        "//third_party:dagger",
    ],
)

kt_jvm_library(
    name = "coffee_lib",
    srcs = glob(["src/**"]) + [
        # Adding a file ending with .srcjar is how code generation patterns are implemented.
        ":tea_lib_src",
        ":chai_lib_src",
    ],
    deps = [
        ":generated_lib",
        "//third_party:dagger",
        "@maven_rules_kotlin_example//:org_jetbrains_kotlinx_kotlinx_coroutines_core",
    ],
)

java_binary(
    name = "coffee_app",
    main_class = "coffee.CoffeeApp",
    visibility = ["//visibility:public"],
    runtime_deps = [":coffee_lib"],
)

define_kt_toolchain(
    name = "kotlin_toolchain",
    api_version = "2.0",
    # Dagger-generated code imports javax.annotation.processing.Generated (JDK 9+)
    jvm_target = "11",
    language_version = "2.0",
)
