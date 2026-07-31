"""The Build Tools API implementation record and the repository built from it.

A record names the artifacts of one Kotlin release that a Build Tools API compilation needs; a
repository built from the record holds their jars and a kt_btapi_runtime target a toolchain uses.
This module owns the shape of the record: the other modules see the functions below only.
"""

load("@bazel_tools//tools/build_defs/repo:utils.bzl", "get_auth", "maybe")

# The repository of the record of the current release. //kotlin/compiler:btapi_runtime is an alias
# to its runtime.
BTAPI_IMPL_DEFAULT_REPOSITORY = "btapi_impl"

# The artifacts of a record: the Maven artifact id, the record field, and the kt_btapi_runtime
# attribute the jar belongs to. A repository holds each artifact as <artifact id>.jar.
_ARTIFACTS = [
    struct(artifact_id = "kotlin-build-tools-impl", field = "build_tools_impl", runtime_attr = "build_tools_impl"),
    struct(artifact_id = "kotlin-compiler-embeddable", field = "compiler", runtime_attr = "compiler"),
    struct(artifact_id = "kotlin-annotation-processing-embeddable", field = "annotation_processing", runtime_attr = "kapt"),
    struct(artifact_id = "jvm-abi-gen", field = "jvm_abi_gen", runtime_attr = "jvm_abi_gen"),
    struct(artifact_id = "kotlin-daemon-client", field = "daemon_client", runtime_attr = "libraries"),
    struct(artifact_id = "kotlin-stdlib", field = "stdlib", runtime_attr = "libraries"),
    struct(artifact_id = "kotlin-reflect", field = "reflect", runtime_attr = "libraries"),
    struct(artifact_id = "kotlin-script-runtime", field = "script_runtime", runtime_attr = "libraries"),
]

# The runtime members every record shares. They are not versioned with the Kotlin release: the
# coroutines and serialization runtimes, the JetBrains annotations, and the two in-repo compiler
# plugins in the embeddable dialect.
_SHARED_LIBRARIES = [
    str(Label("@kotlinx_coroutines_core_jvm//file")),
    str(Label("//kotlin/compiler:annotations")),
    str(Label("@kotlinx_serialization_core_jvm//file")),
    str(Label("@kotlinx_serialization_json//file")),
    str(Label("@kotlinx_serialization_json_jvm//file")),
]
_SHARED_PLUGINS = {
    "jdeps_gen": [str(Label("//src/main/kotlin:jdeps-gen-embeddable"))],
    "skip_code_gen": [str(Label("//src/main/kotlin:skip-code-gen-embeddable"))],
}
_KT_CORE = str(Label("//kotlin:core.bzl"))

def _maven_artifact(artifact_id, sha256):
    return struct(
        url_templates = [
            "https://repo1.maven.org/maven2/org/jetbrains/kotlin/{artifact}/{{version}}/{artifact}-{{version}}.jar".format(artifact = artifact_id),
        ],
        sha256 = sha256,
    )

def btapi_impl_version(
        version,
        build_tools_impl_sha256,
        compiler_sha256,
        annotation_processing_sha256,
        jvm_abi_gen_sha256,
        stdlib_sha256,
        reflect_sha256,
        daemon_client_sha256,
        script_runtime_sha256):
    """Describes the Build Tools API implementation of one Kotlin release.

    The record is versioned by kotlin-build-tools-impl. It lists the implementation, the
    same-version embeddable compiler it loads, the two embeddable-dialect plugins of that compiler,
    and the four libraries of the release the compiler needs. Every checksum is required.

    The defined implementation is expected to be compatible with the Build Tools API jar from the rule_kotlin release the worker is compiled against.
    Expected compatibility guarantee: the API supports implementations from three version lines back to one line forward.

    Args:
        version: the release version, for example "2.4.0".
        build_tools_impl_sha256: the checksum of kotlin-build-tools-impl.
        compiler_sha256: the checksum of kotlin-compiler-embeddable.
        annotation_processing_sha256: the checksum of kotlin-annotation-processing-embeddable.
        jvm_abi_gen_sha256: the checksum of jvm-abi-gen.
        stdlib_sha256: the checksum of kotlin-stdlib.
        reflect_sha256: the checksum of kotlin-reflect.
        daemon_client_sha256: the checksum of kotlin-daemon-client.
        script_runtime_sha256: the checksum of kotlin-script-runtime.

    Returns:
        a composite with one version attribute and one struct per artifact, each holding
        url_templates and sha256.
    """
    sha256s = {
        "annotation_processing": annotation_processing_sha256,
        "build_tools_impl": build_tools_impl_sha256,
        "compiler": compiler_sha256,
        "daemon_client": daemon_client_sha256,
        "jvm_abi_gen": jvm_abi_gen_sha256,
        "reflect": reflect_sha256,
        "script_runtime": script_runtime_sha256,
        "stdlib": stdlib_sha256,
    }
    return struct(
        version = version,
        **{artifact.field: _maven_artifact(artifact.artifact_id, sha256s[artifact.field]) for artifact in _ARTIFACTS}
    )

def btapi_impl_version_from_tag(tag):
    """Builds the record from a btapi_impl_version module extension tag.

    Args:
        tag: the tag; its attributes are the parameters of btapi_impl_version.

    Returns:
        the record.
    """
    return btapi_impl_version(
        version = tag.version,
        **{artifact.field + "_sha256": getattr(tag, artifact.field + "_sha256") for artifact in _ARTIFACTS}
    )

def _jar(artifact_id):
    return artifact_id + ".jar"

def _quoted_list(items):
    return "[" + ", ".join(['"%s"' % item for item in items]) + "]"

def btapi_impl_build_file(release):
    """The BUILD file of a Build Tools API implementation repository.

    It exports the jars of the record and declares the target `runtime`, a kt_btapi_runtime of the
    record's jars, the shared libraries, and the in-repo compiler plugins in the embeddable dialect.

    Args:
      release: a composite built by btapi_impl_version.

    Returns:
      the BUILD file content.
    """
    runtime_attrs = dict(_SHARED_PLUGINS)
    for artifact in _ARTIFACTS:
        runtime_attrs[artifact.runtime_attr] = runtime_attrs.get(artifact.runtime_attr, []) + [":" + _jar(artifact.artifact_id)]
    runtime_attrs["libraries"] = runtime_attrs["libraries"] + _SHARED_LIBRARIES
    return "\n".join([
        "# The Build Tools API implementation %s. Generated by rules_kotlin." % release.version,
        'load("%s", "kt_btapi_runtime")' % _KT_CORE,
        "",
        'package(default_visibility = ["//visibility:public"])',
        "",
        "exports_files(%s)" % _quoted_list([_jar(artifact.artifact_id) for artifact in _ARTIFACTS]),
        "",
        "kt_btapi_runtime(",
        '    name = "runtime",',
    ] + [
        "    %s = %s," % (name, _quoted_list(runtime_attrs[name]))
        for name in sorted(runtime_attrs.keys())
    ] + [
        ")",
        "",
    ])

def _btapi_impl_repository_impl(repository_ctx):
    attr = repository_ctx.attr
    for artifact_id, urls in attr.urls.items():
        repository_ctx.download(
            url = urls,
            output = _jar(artifact_id),
            sha256 = attr.sha256s[artifact_id],
            auth = get_auth(repository_ctx, urls),
        )
    repository_ctx.file("BUILD.bazel", attr.build_file_content, executable = False)

    # Bazel <8.3.0 lacks repository_ctx.repo_metadata
    if not hasattr(repository_ctx, "repo_metadata"):
        return None

    return repository_ctx.repo_metadata(reproducible = True)

_btapi_impl_repository = repository_rule(
    implementation = _btapi_impl_repository_impl,
    doc = "One Build Tools API implementation record as a repository: the downloaded jars and " +
          "the runtime target.",
    attrs = {
        "build_file_content": attr.string(mandatory = True),
        "sha256s": attr.string_dict(mandatory = True, doc = "The checksum of each Maven artifact id."),
        "urls": attr.string_list_dict(mandatory = True, doc = "The download URLs of each Maven artifact id."),
        "version": attr.string(mandatory = True),
    },
)

def btapi_impl_repository(name, release):
    """Creates the repository of one Build Tools API implementation record.

    The repository holds the jars of the record as <artifact id>.jar and the target `runtime`, a
    kt_btapi_runtime a toolchain uses through its btapi_runtime attribute.

    Args:
      name: the repository name.
      release: a composite built by btapi_impl_version. See versions.BTAPI_IMPL_CURRENT_RELEASE
        for the record of the current release.
    """
    maybe(
        _btapi_impl_repository,
        name = name,
        build_file_content = btapi_impl_build_file(release),
        sha256s = {artifact.artifact_id: getattr(release, artifact.field).sha256 for artifact in _ARTIFACTS},
        urls = {
            artifact.artifact_id: [url.format(version = release.version) for url in getattr(release, artifact.field).url_templates]
            for artifact in _ARTIFACTS
        },
        version = release.version,
    )
