load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@rules_java//java:defs.bzl", "java_binary", "java_plugin")
load("//kotlin:core.bzl", "kt_ksp_plugin")
load("//kotlin:jvm.bzl", "kt_jvm_library")

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
package(default_visibility = ["//visibility:private"])

kt_ksp_plugin(
    name = "dagger",
    generates_java = True,
    processor_class = "dagger.internal.codegen.KspComponentProcessor",
    target_embedded_compiler = True,
    deps = ["@rules_kotlin_maven_dev//:com_google_dagger_dagger_compiler"],
)

kt_ksp_plugin(
    name = "dagger_no_java",
    generates_java = False,
    processor_class = "dagger.internal.codegen.KspComponentProcessor",
    target_embedded_compiler = True,
    deps = ["@rules_kotlin_maven_dev//:com_google_dagger_dagger_compiler"],
)

kt_ksp_plugin(
    name = "autoservice",
    processor_class = "dev.zacsweers.autoservice.ksp.AutoServiceSymbolProcessor$Provider",
    deps = ["@rules_kotlin_maven_dev//:dev_zacsweers_autoservice_auto_service_ksp"],
)

kt_ksp_plugin(
    name = "moshi",
    processor_class = "com.squareup.moshi.kotlin.codegen.ksp.JsonClassSymbolProcessorProvider",
    deps = [
        "@rules_kotlin_maven_dev//:com_squareup_moshi_moshi",
        "@rules_kotlin_maven_dev//:com_squareup_moshi_moshi_kotlin",
        "@rules_kotlin_maven_dev//:com_squareup_moshi_moshi_kotlin_codegen",
    ],
)

kt_ksp_plugin(
    name = "generate_bytecode_plugin",
    processor_class = "com.example.BytecodeGeneratorProcessor",
    deps = [
        "//src/test/data/jvm/ksp/bytecodegenerator/processor/src/main/com/example:processor",
    ],
)

kt_jvm_library(
    name = "ksp_kotlin_resources",
    srcs = ["coffee/CoffeeAppModel.kt"],
    plugins = [":moshi"],
    deps = [
        "@rules_kotlin_maven_dev//:com_squareup_moshi_moshi",
        "@rules_kotlin_maven_dev//:com_squareup_moshi_moshi_kotlin",
        "@rules_kotlin_maven_dev//:com_squareup_moshi_moshi_kotlin_codegen",
    ],
)

kt_jvm_library(
    name = "ksp_kotlin_resources_missing_plugin",
    srcs = ["coffee/CoffeeAppModel.kt"],
    deps = [
        "@rules_kotlin_maven_dev//:com_squareup_moshi_moshi",
        "@rules_kotlin_maven_dev//:com_squareup_moshi_moshi_kotlin",
        "@rules_kotlin_maven_dev//:com_squareup_moshi_moshi_kotlin_codegen",
    ],
)

kt_jvm_library(
    name = "ksp_kotlin_resources_multiple_plugins",
    srcs = [
        "coffee/CoffeeAppModel.kt",
        "coffee/DripCoffeeModule.kt",
        "coffee/ElectricHeater.kt",
        "coffee/Heater.kt",
        "coffee/Pump.kt",
        "coffee/PumpModule.kt",
        "coffee/Thermosiphon.kt",
    ],
    plugins = [
        ":dagger",
        ":moshi",
    ],
    deps = [
        "@rules_kotlin_maven_dev//:com_google_dagger_dagger",
        "@rules_kotlin_maven_dev//:com_squareup_moshi_moshi",
        "@rules_kotlin_maven_dev//:com_squareup_moshi_moshi_kotlin",
        "@rules_kotlin_maven_dev//:com_squareup_moshi_moshi_kotlin_codegen",
    ],
)

kt_jvm_library(
    name = "ksp_kotlin_resources_multiple_plugins_no_java_gen",
    srcs = [
        "coffee/CoffeeAppModel.kt",
        "coffee/DripCoffeeModule.kt",
        "coffee/ElectricHeater.kt",
        "coffee/Heater.kt",
        "coffee/Pump.kt",
        "coffee/PumpModule.kt",
        "coffee/Thermosiphon.kt",
    ],
    plugins = [
        ":dagger_no_java",
        ":moshi",
    ],
    deps = [
        "@rules_kotlin_maven_dev//:com_google_dagger_dagger",
        "@rules_kotlin_maven_dev//:com_squareup_moshi_moshi",
        "@rules_kotlin_maven_dev//:com_squareup_moshi_moshi_kotlin",
        "@rules_kotlin_maven_dev//:com_squareup_moshi_moshi_kotlin_codegen",
    ],
)

kt_jvm_library(
    name = "ksp_mixed_resources",
    srcs = [
        "coffee/CoffeeApp.kt",
        "coffee/CoffeeAppJavaModel.java",
        "coffee/CoffeeAppModel.kt",
        "coffee/CoffeeBean.java",
        "coffee/CoffeeMaker.kt",
        "coffee/DripCoffeeModule.kt",
        "coffee/ElectricHeater.kt",
        "coffee/Heater.kt",
        "coffee/Pump.kt",
        "coffee/PumpModule.kt",
        "coffee/Thermosiphon.kt",
        ":chai_lib_src",
        ":tea_lib_src",
    ],
    plugins = [
        ":dagger",
        ":moshi",
        ":autovalue",
    ],
    deps = [
        ":generated_lib",
        "//kotlin/compiler:kotlinx-coroutines-core-jvm",
        "@rules_kotlin_maven_dev//:com_google_auto_value_auto_value_annotations",
        "@rules_kotlin_maven_dev//:com_google_dagger_dagger",
        "@rules_kotlin_maven_dev//:com_squareup_moshi_moshi",
        "@rules_kotlin_maven_dev//:com_squareup_moshi_moshi_kotlin",
    ],
)

kt_jvm_library(
    name = "ksp_only_java",
    srcs = [
        "coffee/CoffeeAppService.java",
        "coffee/CoffeeAppServiceUsage.kt",
    ],
    plugins = [":autoservice"],
    deps = ["@rules_kotlin_maven_dev//:dev_zacsweers_autoservice_auto_service_ksp"],
)

kt_jvm_library(
    name = "ksp_mixed_resources_multiple_plugins",
    srcs = [
        "coffee/CoffeeApp.kt",
        "coffee/CoffeeAppJavaModel.java",
        "coffee/CoffeeAppModel.kt",
        "coffee/CoffeeAppService.java",
        "coffee/CoffeeMaker.kt",
        "coffee/DripCoffeeModule.kt",
        "coffee/ElectricHeater.kt",
        "coffee/Heater.kt",
        "coffee/Pump.kt",
        "coffee/PumpModule.kt",
        "coffee/Thermosiphon.kt",
        ":chai_lib_src",
        ":tea_lib_src",
    ],
    plugins = [
        ":autoservice",
        ":autovalue",
        ":dagger",
        ":moshi",
    ],
    deps = [
        ":generated_lib",
        "//kotlin/compiler:kotlinx-coroutines-core-jvm",
        "@rules_kotlin_maven_dev//:com_google_auto_value_auto_value_annotations",
        "@rules_kotlin_maven_dev//:com_google_dagger_dagger",
        "@rules_kotlin_maven_dev//:com_squareup_moshi_moshi",
        "@rules_kotlin_maven_dev//:com_squareup_moshi_moshi_kotlin",
        "@rules_kotlin_maven_dev//:com_squareup_moshi_moshi_kotlin_codegen",
        "@rules_kotlin_maven_dev//:dev_zacsweers_autoservice_auto_service_ksp",
    ],
)

kt_jvm_library(
    name = "ksp_generate_bytecode",
    srcs = ["BytecodeExample.kt"],
    plugins = [":generate_bytecode_plugin"],
    deps = [
        "//src/test/data/jvm/ksp/bytecodegenerator/annotation",
    ],
)

kt_jvm_library(
    name = "ksp_bytecode_plugin_generates_no_classes_with_other_plugins",
    # these files don't have relevant annotations, and don't generate the bytecode/generated classes
    # from generate_bytecode_plugin
    srcs = [
        "coffee/CoffeeApp.kt",
        "coffee/CoffeeAppJavaModel.java",
        "coffee/CoffeeAppModel.kt",
        "coffee/CoffeeBean.java",
        "coffee/CoffeeMaker.kt",
        "coffee/DripCoffeeModule.kt",
        "coffee/ElectricHeater.kt",
        "coffee/Heater.kt",
        "coffee/Pump.kt",
        "coffee/PumpModule.kt",
        "coffee/Thermosiphon.kt",
        ":chai_lib_src",
        ":tea_lib_src",
    ],
    plugins = [
        ":generate_bytecode_plugin",
        ":autovalue",
        ":dagger",
        ":moshi",
    ],
    deps = [
        ":generated_lib",
        "//kotlin/compiler:kotlinx-coroutines-core-jvm",
        "@rules_kotlin_maven_dev//:com_google_auto_value_auto_value_annotations",
        "@rules_kotlin_maven_dev//:com_google_dagger_dagger",
        "@rules_kotlin_maven_dev//:com_google_dagger_dagger_compiler",
        "@rules_kotlin_maven_dev//:com_squareup_moshi_moshi",
        "@rules_kotlin_maven_dev//:com_squareup_moshi_moshi_kotlin",
    ],
)

filegroup(
    name = "ksp",
    srcs = [
        ":ksp_bytecode_plugin_generates_no_classes_with_other_plugins.jar",
        ":ksp_generate_bytecode.jar",
        ":ksp_kotlin_resources.jar",
        ":ksp_kotlin_resources_missing_plugin.jar",
        ":ksp_kotlin_resources_multiple_plugins.jar",
        ":ksp_kotlin_resources_multiple_plugins_no_java_gen.jar",
        ":ksp_mixed_resources.jar",
        ":ksp_mixed_resources_multiple_plugins.jar",
        ":ksp_only_java.jar",
    ],
    visibility = ["//visibility:public"],
)

# AutoValue java_plugin for the coffee app integration test
java_plugin(
    name = "autovalue",
    generates_api = True,
    processor_class = "com.google.auto.value.processor.AutoValueProcessor",
    deps = ["@rules_kotlin_maven_dev//:com_google_auto_value_auto_value"],
)

# Generate srcjars for the coffee app integration test
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
    plugins = [":dagger"],
    deps = ["@rules_kotlin_maven_dev//:com_google_dagger_dagger"],
)

kt_jvm_library(
    name = "coffee_lib",
    srcs = glob([
        "coffee/*.kt",
        "coffee/*.java",
    ]) + [
        ":chai_lib_src",
        ":tea_lib_src",
    ],
    plugins = [
        ":dagger",
        ":moshi",
        ":autovalue",
        ":autoservice",
    ],
    deps = [
        ":generated_lib",
        "//kotlin/compiler:kotlinx-coroutines-core-jvm",
        "@rules_kotlin_maven_dev//:com_google_auto_service_auto_service_annotations",
        "@rules_kotlin_maven_dev//:com_google_auto_value_auto_value_annotations",
        "@rules_kotlin_maven_dev//:com_google_dagger_dagger",
        "@rules_kotlin_maven_dev//:com_squareup_moshi_moshi",
        "@rules_kotlin_maven_dev//:com_squareup_moshi_moshi_kotlin",
    ],
)

java_binary(
    name = "coffee_app",
    main_class = "coffee.CoffeeApp",
    visibility = ["//visibility:public"],
    runtime_deps = [":coffee_lib"],
)

build_test(
    name = "coffee_app_test",
    targets = [
        ":coffee_app",
        ":coffee_app_deploy.jar",
    ],
)

kt_jvm_library(
    name = "raw_ksp_coffee_app_lib",
    srcs = ["coffee/CoffeeAppModel.kt"],
    plugins = [":moshi"],
    deps = [
        "@rules_kotlin_maven_dev//:com_google_auto_service_auto_service_annotations",
        "@rules_kotlin_maven_dev//:com_google_auto_value_auto_value_annotations",
        "@rules_kotlin_maven_dev//:com_squareup_moshi_moshi",
        "@rules_kotlin_maven_dev//:com_squareup_moshi_moshi_kotlin",
    ],
)

build_test(
    name = "raw_ksp_lib_test",
    targets = [":raw_ksp_coffee_app_lib"],
)
