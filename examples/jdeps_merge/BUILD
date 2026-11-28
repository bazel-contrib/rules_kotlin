load("@rules_java//java:defs.bzl", "java_library", "java_plugin")
load("@rules_kotlin//kotlin:core.bzl", "define_kt_toolchain")
load("@rules_kotlin//kotlin:jvm.bzl", "kt_jvm_library")

# The Java half of a mixed or kapt target compiles against the target's own Kotlin output jar or
# kapt stub jar, so its jdeps names that jar. JdepsMerge has to drop it rather than read it.
define_kt_toolchain(
    name = "kotlin_toolchain",
    experimental_report_unused_deps = "warn",
)

kt_jvm_library(
    name = "greeting",
    srcs = ["Greeting.kt"],
)

# Kotlin and Java sources: the Java half compiles against this target's -kt.jar.
kt_jvm_library(
    name = "mixed",
    srcs = [
        "Mixed.kt",
        "MixedJava.java",
    ],
    deps = [":greeting"],
)

java_library(
    name = "noop_processor_lib",
    srcs = ["NoopProcessor.java"],
)

java_plugin(
    name = "noop_processor",
    processor_class = "jdeps.merge.NoopProcessor",
    deps = [":noop_processor_lib"],
)

# An annotation processor runs through kapt: the Java half compiles against the kapt stub jar.
kt_jvm_library(
    name = "kapt",
    srcs = ["Kapt.kt"],
    plugins = [":noop_processor"],
    deps = [":greeting"],
)
