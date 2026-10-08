# All versions for development and release
"""Pinned dependency versions for the Kotlin rules."""

load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load(":btapi_impl.bzl", "btapi_impl_version")

version = provider(
    doc = "A pinned downloadable dependency version with its checksum and URL templates.",
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

# The Kotlin compiler release train: the CLI distribution, the Build Tools API jar, and the Build
# Tools API implementation record ship together under this one version. Bump them together; each
# entry keeps its own per-artifact sha256.
_KOTLIN_CURRENT_RELEASE = "2.4.21"

versions = struct(
    # IMPORTANT! rules_kotlin does not use the bazel_skylib unittest in production
    # This means the bazel_skylib_workspace call is skipped, as it only registers the unittest
    # toolchains. However, if a new workspace dependency is introduced, this precondition will fail.
    # Why skip it? Because it would introduce a 3rd function call to rules kotlin setup:
    # 1. Download archive
    # 2. Download dependencies and Configure rules
    # --> 3. Configure dependencies <--
    BAZEL_SKYLIB = version(
        version = "1.8.2",
        sha256 = "6e78f0e57de26801f6f564fa7c4a48dc8b36873e416257a92bbb0937eeac8446",
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
    JARJAR = version(
        version = "1.17.0",
        sha256 = "52566e0c865f7468a16b53020289658909ecc61ec3b1efbd7d98bcd3730712db",
        url_templates = [
            "https://repo.maven.apache.org/maven2/com/eed3si9n/jarjar/jarjar-assembly/{version}/jarjar-assembly-{version}.jar",
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
        version = _KOTLIN_CURRENT_RELEASE,
        url_templates = [
            "https://github.com/JetBrains/kotlin/releases/download/v{version}/kotlin-compiler-{version}.zip",
        ],
        sha256 = "7cc140e76daf416a0424a5557f99afd7ca89ebd463ea1101261e3e01c33e75cd",
    ),
    KSP_CURRENT_COMPILER_PLUGIN_RELEASE = version(
        version = "2.3.12",
        url_templates = [
            "https://github.com/google/ksp/releases/download/{version}/artifacts.zip",
        ],
        sha256 = "31e83f087c3e822d16d93b2fd240769872ba1fad26e7f3b5dfb3f71513e7399f",
    ),
    # Starting with Kotlin 2.4.0 the Build Tools API interfaces are no longer bundled in
    # kotlin-compiler.jar, so they must be provided as a separate jar.
    KOTLIN_BUILD_TOOLS_API = version(
        version = _KOTLIN_CURRENT_RELEASE,
        url_templates = [
            "https://repo1.maven.org/maven2/org/jetbrains/kotlin/kotlin-build-tools-api/{version}/kotlin-build-tools-api-{version}.jar",
        ],
        sha256 = "c5cd6a49bd072b529ae10809111c16a7aa0f92147e95d288354017fd65799461",
    ),
    # The Build Tools API implementation of the current release and the embeddable compiler family
    # it loads: the Maven-published kotlinc build whose bundled third-party packages are shaded
    # (e.g. org.jetbrains.kotlin.com.intellij), the dialect compiler plugins published for
    # Gradle/Maven consumption are compiled against. The repository @btapi_impl is built from it.
    BTAPI_IMPL_CURRENT_RELEASE = btapi_impl_version(
        version = _KOTLIN_CURRENT_RELEASE,
        build_tools_impl_sha256 = "3152b3e1fbaa4d48f3681734a2c0efc438359a48c8a3c5cac00d874670de1377",
        compiler_sha256 = "ef19419c765e7ac8404465fa026ca8fc4dbb8a822de0fc79aa53c8dce29f1d02",
        annotation_processing_sha256 = "b798fabf9adf246e3091d0e8ae06a1b3d19feee5e399e3d13b61e27871f19692",
        jvm_abi_gen_sha256 = "e8ef7a82bc2df9c140d204fc0362f59b0e6df51c0406fb7360d18312da3be1cf",
        stdlib_sha256 = "bd8250210584cb659847dce9cda660f8e9906e5def7fbebcea93dc6dcb6a88a3",
        reflect_sha256 = "7c9e8bda3cafa85b65692065acd22578b2843292b4e4baa8361bdc9175746e88",
        daemon_client_sha256 = "095903c4c4713bf91a562d226d7ba0464cf5424e76342d487deec494451ab29b",
        script_runtime_sha256 = "a658cf5902a1525a06c264a5e42b437e97a6679ddeef8ca641246f270cf6a013",
    ),
    RULES_ANDROID = version(
        version = "0.7.3",
        url_templates = [
            "https://github.com/bazelbuild/rules_android/releases/download/v{version}/rules_android-v{version}.tar.gz",
        ],
        strip_prefix_template = "rules_android-{version}",
        sha256 = "c4cd258d3761eff08ee044c0252179bb6ee8af8ab24f7dafb73b280eeda98243",
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
