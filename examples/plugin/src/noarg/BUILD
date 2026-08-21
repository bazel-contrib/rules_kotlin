load("@rules_kotlin//kotlin:core.bzl", "kt_compiler_plugin")
load("@rules_kotlin//kotlin:jvm.bzl", "kt_jvm_library", "kt_jvm_test")

kt_compiler_plugin(
    name = "no_arg_plugin",
    compile_phase = True,
    id = "org.jetbrains.kotlin.noarg",
    options = {
        "annotation": ["plugin.noarg.NoArgConstructor"],
    },
    stubs_phase = True,
    deps = [
        "@rules_kotlin//kotlin/compiler:noarg-compiler-plugin",
    ],
)

kt_jvm_library(
    name = "no_arg_constructor",
    srcs = ["NoArgConstructor.kt"],
)

kt_jvm_library(
    name = "user",
    srcs = ["User.kt"],
    plugins = [":no_arg_plugin"],
    deps = [
        ":no_arg_constructor",
    ],
)

# The no-arg constructor that is generated cannot be compiled against, but should be discoverable at runtime.
kt_jvm_test(
    name = "user_has_noarg_constructor_test",
    srcs = ["UserHasNoargConstructorTest.kt"],
    test_class = "plugin.noarg.UserHasNoargConstructorTest",
    deps = [
        ":user",
        "@maven_rules_kotlin_example//:junit_junit",
        "@rules_kotlin//kotlin/compiler:kotlin-reflect",
    ],
)
