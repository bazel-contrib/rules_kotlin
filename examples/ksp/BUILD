load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@rules_java//java:defs.bzl", "java_binary")

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

package(default_visibility = ["//visibility:public"])

define_kt_toolchain(
    name = "kotlin_toolchain",
    # KSP-generated code imports javax.annotation.processing.Generated (JDK 9+)
    jvm_target = "11",
)

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
    name = "generated_module_src",
    outs = ["generated_module_src.srcjar"],
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
    srcs = [":generated_module_src"],
    plugins = ["//third_party:dagger"],
    deps = ["@maven_rules_kotlin_example//:com_google_dagger_dagger"],
)

kt_jvm_library(
    name = "coffee_lib",
    srcs = glob([
        "*.kt",
        "*.java",
    ]) + [
        # Adding a file ending with .srcjar is how code generation patterns are implemented.
        ":tea_lib_src",
        ":chai_lib_src",
    ],
    plugins = [
        "//third_party:dagger",
        "//third_party:moshi",
        "//third_party:autovalue",
        "//third_party:autoservice",
    ],
    deps = [
        ":generated_lib",
        "@maven_rules_kotlin_example//:com_google_auto_service_auto_service_annotations",
        "@maven_rules_kotlin_example//:com_google_auto_value_auto_value_annotations",
        "@maven_rules_kotlin_example//:com_google_dagger_dagger",
        "@maven_rules_kotlin_example//:com_squareup_moshi_moshi",
        "@maven_rules_kotlin_example//:com_squareup_moshi_moshi_kotlin",
        "@maven_rules_kotlin_example//:org_jetbrains_kotlinx_kotlinx_coroutines_core",
    ],
)

java_binary(
    name = "coffee_app",
    main_class = "coffee.CoffeeApp",
    visibility = ["//visibility:public"],
    runtime_deps = [":coffee_lib"],
)

build_test(
    name = "force_build_app_test",
    targets = [
        "//:coffee_app",
        # build_test doesn't actually fail unless you force the deploy jar to be built
        "//:coffee_app_deploy.jar",
    ],
)

kt_jvm_library(
    name = "raw_ksp_coffee_app_lib",
    srcs = ["CoffeeAppModel.kt"],
    plugins = [
        "//third_party:moshi",
    ],
    deps = [
        "@maven_rules_kotlin_example//:com_google_auto_service_auto_service_annotations",
        "@maven_rules_kotlin_example//:com_google_auto_value_auto_value_annotations",
        "@maven_rules_kotlin_example//:com_squareup_moshi_moshi",
        "@maven_rules_kotlin_example//:com_squareup_moshi_moshi_kotlin",
    ],
)

build_test(
    name = "raw_ksp_lib_test",
    targets = [
        "//:raw_ksp_coffee_app_lib",
    ],
)
