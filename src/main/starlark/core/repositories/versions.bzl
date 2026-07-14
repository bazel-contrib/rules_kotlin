# All versions for development and release
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

version = provider(
    fields = {
        "sha256": "sha256 checksum for the version being downloaded.",
        "strip_prefix_template": "string template with the placeholder {version}.",
        "url_templates": "list of string templates with the placeholder {version}",
        "version": "the version in the form \\D+.\\D+.\\D+(.*)",
    },
)

def _use_repository(rule, name, version, **kwargs):
    rule_arguments = dict(kwargs)
    rule_arguments["sha256"] = version.sha256
    rule_arguments["urls"] = [u.format(version = version.version) for u in version.url_templates]
    if (hasattr(version, "strip_prefix_template")):
        rule_arguments["strip_prefix"] = version.strip_prefix_template.format(version = version.version)

    maybe(rule, name = name, **rule_arguments)

versions = struct(
    # IMPORTANT! rules_kotlin does not use the bazel_skylib unittest in production
    # This means the bazel_skylib_workspace call is skipped, as it only registers the unittest
    # toolchains. However, if a new workspace dependency is introduced, this precondition will fail.
    # Why skip it? Because it would introduce a 3rd function call to rules kotlin setup:
    # 1. Download archive
    # 2. Download dependencies and Configure rules
    # --> 3. Configure dependencies <--
    BAZEL_SKYLIB = version(
        version = "1.7.1",
        sha256 = "bc283cdfcd526a52c3201279cda4bc298652efa898b10b4db0837dc51652756f",
        url_templates = [
            "https://github.com/bazelbuild/bazel-skylib/releases/download/{version}/bazel-skylib-{version}.tar.gz",
        ],
    ),
    BAZEL_FEATURES = version(
        version = "1.39.0",
        sha256 = "5ab1a90d09fd74555e0df22809ad589627ddff263cff82535815aa80ca3e3562",
        strip_prefix_template = "bazel_features-{version}",
        url_templates = [
            "https://github.com/bazel-contrib/bazel_features/releases/download/v{version}/bazel_features-v{version}.tar.gz",
        ],
    ),
    BAZEL_LIB = version(
        version = "3.1.0",
        sha256 = "fd0fe4df9b6b7837d5fd765c04ffcea462530a08b3d98627fb6be62a693f4e12",
        strip_prefix_template = "bazel-lib-{version}",
        url_templates = [
            "https://github.com/bazel-contrib/bazel-lib/releases/download/v{version}/bazel-lib-v{version}.tar.gz",
        ],
    ),
    RULES_JVM_EXTERNAL = version(
        version = "6.10",
        sha256 = "e5f83b8f2678d2b26441e5eafefb1b061826608417b8d24e5e8e15e585eab1ba",
        strip_prefix_template = "rules_jvm_external-{version}",
        url_templates = [
            "https://github.com/bazelbuild/rules_jvm_external/releases/download/{version}/rules_jvm_external-{version}.tar.gz",
        ],
    ),
    PINTEREST_KTLINT = version(
        version = "1.8.0",
        url_templates = [
            "https://github.com/pinterest/ktlint/releases/download/{version}/ktlint",
        ],
        sha256 = "a3fd620207d5c40da6ca789b95e7f823c54e854b7fade7f613e91096a3706d75",
    ),
    KOTLIN_CURRENT_COMPILER_RELEASE = version(
        version = "2.4.10",
        url_templates = [
            "https://github.com/JetBrains/kotlin/releases/download/v{version}/kotlin-compiler-{version}.zip",
        ],
        sha256 = "473dd66c7a3ef4b182065b3da670466c1bf2773a9dbb0ed8b33a39fe9d4f876d",
    ),
    KSP_CURRENT_COMPILER_PLUGIN_RELEASE = version(
        version = "2.3.9",
        url_templates = [
            "https://github.com/google/ksp/releases/download/{version}/artifacts.zip",
        ],
        sha256 = "7f462f48a966051e733df463938c35d6da1c3c7191cc889fe5e3b04c7d91b5ab",
    ),
    KOTLIN_BUILD_TOOLS_IMPL = version(
        version = "2.4.10",
        url_templates = [
            "https://repo1.maven.org/maven2/org/jetbrains/kotlin/kotlin-build-tools-impl/{version}/kotlin-build-tools-impl-{version}.jar",
        ],
        sha256 = "4a32f63522ef4726afbdee1783f05698499abc7a5ecade3a6cafa3e4074562ee",
    ),
    # Starting with Kotlin 2.4.0 the Build Tools API interfaces are no longer bundled in
    # kotlin-compiler.jar, so they must be provided as a separate jar.
    KOTLIN_BUILD_TOOLS_API = version(
        version = "2.4.10",
        url_templates = [
            "https://repo1.maven.org/maven2/org/jetbrains/kotlin/kotlin-build-tools-api/{version}/kotlin-build-tools-api-{version}.jar",
        ],
        sha256 = "3953d283e7710c990672e403a87df393d9726a9bf3e172194ebb5c33e062fcb0",
    ),
    RULES_ANDROID = version(
        version = "0.7.0",
        url_templates = [
            "https://github.com/bazelbuild/rules_android/releases/download/v{version}/rules_android-v{version}.tar.gz",
        ],
        strip_prefix_template = "rules_android-{version}",
        sha256 = "ef1a446260b7f620e2aae11d4c96389369eb865ade01fcdd389a8196168b8d9b",
    ),
    RULES_JAVA = version(
        version = "8.9.0",
        url_templates = [
            "https://github.com/bazelbuild/rules_java/releases/download/{version}/rules_java-{version}.tar.gz",
        ],
        sha256 = "8daa0e4f800979c74387e4cd93f97e576ec6d52beab8ac94710d2931c57f8d8b",
    ),
    RULES_LICENSE = version(
        version = "1.0.0",
        url_templates = [
            "https://mirror.bazel.build/github.com/bazelbuild/rules_license/releases/download/{version}/rules_license-{version}.tar.gz",
            "https://github.com/bazelbuild/rules_license/releases/download/{version}/rules_license-{version}.tar.gz",
        ],
        sha256 = "26d4021f6898e23b82ef953078389dd49ac2b5618ac564ade4ef87cced147b38",
    ),
    KOTLINX_SERIALIZATION_CORE_JVM = version(
        version = "1.8.1",
        url_templates = [
            "https://repo1.maven.org/maven2/org/jetbrains/kotlinx/kotlinx-serialization-core-jvm/{version}/kotlinx-serialization-core-jvm-{version}.jar",
        ],
        sha256 = "3565b6d4d789bf70683c45566944287fc1d8dc75c23d98bd87d01059cc76f2b3",
    ),
    KOTLINX_SERIALIZATION_JSON = version(
        version = "1.8.1",
        url_templates = [
            "https://repo1.maven.org/maven2/org/jetbrains/kotlinx/kotlinx-serialization-json/{version}/kotlinx-serialization-json-{version}.jar",
        ],
        sha256 = "58adf3358a0f99dd8d66a550fbe19064d395e0d5f7f1e46515cd3470a56fbbb0",
    ),
    KOTLINX_SERIALIZATION_JSON_JVM = version(
        version = "1.8.1",
        url_templates = [
            "https://repo1.maven.org/maven2/org/jetbrains/kotlinx/kotlinx-serialization-json-jvm/{version}/kotlinx-serialization-json-jvm-{version}.jar",
        ],
        sha256 = "8769e5647557e3700919c32d508f5c5dad53c5d8234cd10846354fbcff14aa24",
    ),
    PY_ABSL = version(
        version = "2.1.0",
        sha256 = "8a3d0830e4eb4f66c4fa907c06edf6ce1c719ced811a12e26d9d3162f8471758",
        url_templates = [
            "https://github.com/abseil/abseil-py/archive/refs/tags/v{version}.tar.gz",
        ],
        strip_prefix_template = "abseil-py-{version}",
    ),
    RULES_CC = version(
        version = "0.0.16",
        url_templates = ["https://github.com/bazelbuild/rules_cc/releases/download/{version}/rules_cc-{version}.tar.gz"],
        sha256 = "bbf1ae2f83305b7053b11e4467d317a7ba3517a12cef608543c1b1c5bf48a4df",
        strip_prefix_template = "rules_cc-{version}",
    ),
    KOTLINX_COROUTINES_CORE_JVM = version(
        version = "1.10.2",
        url_templates = [
            "https://repo1.maven.org/maven2/org/jetbrains/kotlinx/kotlinx-coroutines-core-jvm/{version}/kotlinx-coroutines-core-jvm-{version}.jar",
        ],
        sha256 = "5ca175b38df331fd64155b35cd8cae1251fa9ee369709b36d42e0a288ccce3fd",
    ),
    use_repository = _use_repository,
)
