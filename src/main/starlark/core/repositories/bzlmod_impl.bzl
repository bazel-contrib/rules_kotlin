"""Implementation of the rules_kotlin module extension."""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_file", "http_jar")
load(
    ":btapi_impl.bzl",
    "BTAPI_IMPL_DEFAULT_REPOSITORY",
    "btapi_impl_repository",
    "btapi_impl_version_from_tag",
)
load(":compiler.bzl", "kotlin_compiler_repository")
load(":ksp.bzl", "ksp_compiler_plugin_repository")
load(":versions.bzl", "version", "versions")

# Keep these names in sync with //kotlin/internal:defs.bzl.
_KT_COMPILER_REPO = "com_github_jetbrains_kotlin"
_KSP_COMPILER_PLUGIN_REPO = "com_github_google_ksp"

def kotlin_repositories(
        compiler_repository_name = _KT_COMPILER_REPO,
        ksp_repository_name = _KSP_COMPILER_PLUGIN_REPO,
        compiler_release = versions.KOTLIN_CURRENT_COMPILER_RELEASE,
        ksp_compiler_release = versions.KSP_CURRENT_COMPILER_PLUGIN_RELEASE,
        btapi_impl_releases = None):
    """Sets up the Kotlin compiler repositories for the Bzlmod module extension.

    Args:
        compiler_repository_name: for the kotlinc compiler repository.
        ksp_repository_name: for the KSP compiler plugin repository.
        compiler_release: version provider from versions.bzl.
        ksp_compiler_release: (internal) version provider from versions.bzl.
        btapi_impl_releases: the Build Tools API implementation records, a dict of repository
         name to a record built with btapi_impl_version. The record of the current release is
         always created as @btapi_impl unless the dict replaces it.
    """

    kotlin_compiler_repository(
        name = compiler_repository_name,
        urls = [url.format(version = compiler_release.version) for url in compiler_release.url_templates],
        sha256 = compiler_release.sha256,
        compiler_version = compiler_release.version,
    )

    ksp_compiler_plugin_repository(
        name = ksp_repository_name,
        urls = [url.format(version = ksp_compiler_release.version) for url in ksp_compiler_release.url_templates],
        sha256 = ksp_compiler_release.sha256,
        strip_version = ksp_compiler_release.version,
    )

    versions.use_repository(
        http_jar,
        name = "jarjar",
        version = versions.JARJAR,
    )

    versions.use_repository(
        http_file,
        name = "com_github_pinterest_ktlint",
        version = versions.PINTEREST_KTLINT,
        downloaded_file_path = "ktlint.jar",
    )

    versions.use_repository(
        http_file,
        name = "kotlinx_serialization_core_jvm",
        version = versions.KOTLINX_SERIALIZATION_CORE_JVM,
        downloaded_file_path = "kotlinx-serialization-core-jvm.jar",
    )

    versions.use_repository(
        http_file,
        name = "kotlinx_serialization_json",
        version = versions.KOTLINX_SERIALIZATION_JSON,
        downloaded_file_path = "kotlinx-serialization-json.jar",
    )

    versions.use_repository(
        http_file,
        name = "kotlinx_serialization_json_jvm",
        version = versions.KOTLINX_SERIALIZATION_JSON_JVM,
        downloaded_file_path = "kotlinx-serialization-json-jvm.jar",
    )

    versions.use_repository(
        http_file,
        name = "kotlinx_coroutines_core_jvm",
        version = versions.KOTLINX_COROUTINES_CORE_JVM,
        downloaded_file_path = "kotlinx-coroutines-core-jvm.jar",
    )

    versions.use_repository(
        http_file,
        name = "kotlin_build_tools_api",
        version = versions.KOTLIN_BUILD_TOOLS_API,
        downloaded_file_path = "kotlin-build-tools-api.jar",
    )

    releases = dict(btapi_impl_releases or {})
    if BTAPI_IMPL_DEFAULT_REPOSITORY not in releases:
        releases[BTAPI_IMPL_DEFAULT_REPOSITORY] = versions.BTAPI_IMPL_CURRENT_RELEASE
    for name, release in releases.items():
        btapi_impl_repository(name = name, release = release)

def kotlinc_version(release, sha256):
    return version(
        version = release,
        url_templates = [
            "https://github.com/JetBrains/kotlin/releases/download/v{version}/kotlin-compiler-{version}.zip",
        ],
        sha256 = sha256,
    )

def ksp_version(release, sha256):
    return version(
        version = release,
        url_templates = [
            "https://github.com/google/ksp/releases/download/{version}/artifacts.zip",
        ],
        sha256 = sha256,
    )

def collect_btapi_impl_releases(modules):
    """Collects the btapi_impl_version tags into a dict of repository name to record.

    Only the root module may declare the tags, so two modules cannot collide on a repository
    name. A name declared twice fails.

    Args:
      modules: the modules of the module extension context.

    Returns:
      a dict of repository name to the record built from the tag.
    """
    releases = {}
    for mod in modules:
        for tag in mod.tags.btapi_impl_version:
            if not mod.is_root:
                fail("btapi_impl_version is available to the root module only; module %s declares %s" % (mod.name, tag.name))
            if tag.name in releases:
                fail("btapi_impl_version %s is declared twice" % tag.name)
            releases[tag.name] = btapi_impl_version_from_tag(tag)
    return releases

def configure_modules_and_repositories(modules, kotlin_repositories, kotlinc_version, ksp_version):
    """Configures Kotlin repositories from the extension's version overrides.

    Args:
        modules: extensions whose kotlinc_version/ksp_version tags are read.
        kotlin_repositories: repositories macro invoked with the resolved versions.
        kotlinc_version: constructor for a kotlinc version override.
        ksp_version: constructor for a KSP version override.
    """
    kotlinc = None
    ksp = None
    for mod in modules:
        for override in mod.tags.kotlinc_version:
            if kotlinc:
                fail("Only one kotlinc_version is supported right now!")
            kotlinc = kotlinc_version(release = override.version, sha256 = override.sha256)
        for override in mod.tags.ksp_version:
            if ksp:
                fail("Only one ksp_version is supported right now!")
            ksp = ksp_version(release = override.version, sha256 = override.sha256)
    btapi_impl_releases = collect_btapi_impl_releases(modules)

    kotlin_repositories_args = dict()
    if kotlinc:
        kotlin_repositories_args["compiler_release"] = kotlinc
    if ksp:
        kotlin_repositories_args["ksp_compiler_release"] = ksp
    if btapi_impl_releases:
        kotlin_repositories_args["btapi_impl_releases"] = btapi_impl_releases

    kotlin_repositories(**kotlin_repositories_args)

_version_tag = tag_class(
    attrs = {
        "sha256": attr.string(mandatory = True),
        "version": attr.string(mandatory = True),
    },
)

_btapi_impl_version_tag = tag_class(
    doc = "A Build Tools API implementation record as a repository: the implementation, the " +
          "embeddable compiler, its kapt and jvm-abi-gen plugins, and the four libraries of one " +
          "Kotlin release, with the runtime target @<name>//:runtime for a toolchain. The name " +
          "btapi_impl replaces the record of the current release.",
    attrs = {
        "annotation_processing_sha256": attr.string(mandatory = True),
        "build_tools_impl_sha256": attr.string(mandatory = True),
        "compiler_sha256": attr.string(mandatory = True),
        "daemon_client_sha256": attr.string(mandatory = True),
        "jvm_abi_gen_sha256": attr.string(mandatory = True),
        "name": attr.string(mandatory = True, doc = "The repository name."),
        "reflect_sha256": attr.string(mandatory = True),
        "script_runtime_sha256": attr.string(mandatory = True),
        "stdlib_sha256": attr.string(mandatory = True),
        "version": attr.string(mandatory = True, doc = "The Kotlin release version."),
    },
)

tag_classes = {
    "btapi_impl_version": _btapi_impl_version_tag,
    "kotlinc_version": _version_tag,
    "ksp_version": _version_tag,
}
