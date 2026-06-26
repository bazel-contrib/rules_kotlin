load("//kotlin:core.bzl", "kt_kotlinc_options")
load("//kotlin:jvm.bzl", "kt_jvm_library")
load(":java_language_version.bzl", "java_language_version_env")

package(default_visibility = ["//visibility:public"])

kt_kotlinc_options(
    name = "jvm8_opts",
    jvm_target = "1.8",
)

kt_jvm_library(
    name = "mixed_jvm8",
    srcs = [
        "Mixed.kt",
        "MixedJava.java",
    ],
    kotlinc_opts = ":jvm8_opts",
)

# Pin java_language_version so the test is independent of the repository's global Java config.
java_language_version_env(
    name = "mixed_jvm8_java11",
    java_language_version = "11",
    target = ":mixed_jvm8",
)
