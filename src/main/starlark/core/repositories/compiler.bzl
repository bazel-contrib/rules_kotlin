"""
Defines kotlin compiler repositories.
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_file")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "get_auth")
load("//src/main/starlark/core/repositories/kotlin:templates.bzl", "TEMPLATES")
load(":versions.bzl", "version", "versions")

def _kotlin_compiler_impl(repository_ctx):
    attr = repository_ctx.attr
    repository_ctx.download_and_extract(
        attr.urls,
        sha256 = attr.sha256,
        stripPrefix = "kotlinc",
        auth = get_auth(repository_ctx, attr.urls),
    )
    repository_ctx.template(
        "BUILD.bazel",
        attr._template,
        executable = False,
    )

    # Bazel <8.3.0 lacks repository_ctx.repo_metadata
    if not hasattr(repository_ctx, "repo_metadata"):
        return None

    return repository_ctx.repo_metadata(
        reproducible = attr.sha256 != "",
    )

def _kotlin_capabilities_impl(repository_ctx):
    """Creates the kotlinc repository."""
    attr = repository_ctx.attr
    repository_ctx.file(
        "WORKSPACE",
        content = """workspace(name = "%s")""" % attr.name,
    )
    repository_ctx.template(
        "BUILD.bazel",
        attr._template,
        executable = False,
        substitutions = {
            "$git_repo$": attr.git_repository_name,
        },
    )
    repository_ctx.template(
        "artifacts.bzl",
        attr._artifacts_template,
        executable = False,
    )
    template = _get_capability_template(
        attr.compiler_version,
        [repository_ctx.path(ct) for ct in attr._capability_templates],
    )
    repository_ctx.template(
        "capabilities.bzl",
        template,
        executable = False,
    )

    # Bazel <8.3.0 lacks repository_ctx.repo_metadata
    if not hasattr(repository_ctx, "repo_metadata"):
        return None

    return repository_ctx.repo_metadata(
        reproducible = True,
    )

def _coerce_int(string_value):
    digits = "".join([
        string_value[i]
        for i in range(len(string_value))
        if string_value[i].isdigit()
    ])
    return 0 if not digits else int(digits)

def _version(version_string):
    return tuple([
        _coerce_int(segment)
        for segment in version_string.split(".", 3)
    ])

def _parse_version(basename):
    if "capabilities" not in basename:
        return None
    version_string = basename[len("capabilities_"):basename.find(".bzl")]
    return _version(version_string)

def _get_capability_template(compiler_version, templates):
    version_index = {}
    target = _version(compiler_version)
    if len(target) > 2:
        target = target[0:2]
    for template in templates:
        version = _parse_version(template.basename)
        if not version:
            continue

        if target == version:
            return template
        version_index[version] = template

    last_version = sorted(version_index.keys(), reverse = True)[0]

    # After latest version, chosen by major revision
    if target[0] >= last_version[0]:
        return version_index[last_version]

    # Legacy
    return version_index[(0, 0, 0)]

kotlin_capabilities_repository = repository_rule(
    implementation = _kotlin_capabilities_impl,
    attrs = {
        "compiler_version": attr.string(
            doc = "compiler version",
        ),
        "git_repository_name": attr.string(
            doc = "Name of the repository containing kotlin compiler libraries",
        ),
        "_artifacts_template": attr.label(
            doc = "kotlinc artifacts template",
            default = "//src/main/starlark/core/repositories/kotlin:artifacts.bzl",
        ),
        "_capability_templates": attr.label_list(
            doc = "List of compiler capability templates.",
            default = TEMPLATES,
        ),
        "_template": attr.label(
            doc = "repository build file template",
            default = ":BUILD.kotlin_capabilities.bazel",
        ),
    },
)

kotlin_compiler_git_repository = repository_rule(
    implementation = _kotlin_compiler_impl,
    attrs = {
        "sha256": attr.string(
            doc = "sha256 of the compiler archive",
        ),
        "urls": attr.string_list(
            doc = "A list of urls for the kotlin compiler",
            mandatory = True,
        ),
        "_template": attr.label(
            doc = "repository build file template",
            default = ":BUILD.com_github_jetbrains_kotlin.bazel",
        ),
    },
)

def kotlin_compiler_repository(name, urls, sha256, compiler_version):
    """
    Creates two repositories, necessary for lazily loading the kotlin compiler binaries for git.
    """
    git_repo = name + "_git"
    kotlin_compiler_git_repository(
        name = git_repo,
        urls = urls,
        sha256 = sha256,
    )
    kotlin_capabilities_repository(
        name = name,
        git_repository_name = git_repo,
        compiler_version = compiler_version,
    )

def kotlin_embeddable_compiler_repository(release):
    """Creates every repository of the embeddable compiler dialect.

    The embeddable dialect is the Maven-published form of the compiler, with the bundled
    third-party packages shaded (e.g. org.jetbrains.kotlin.com.intellij). It mirrors the CLI
    distribution: the compiler, the kapt plugin, and the jvm-abi-gen plugin. One call creates
    @kotlin_compiler_embeddable, @kotlin_annotation_processing_embeddable, and @jvm_abi_gen.

    Args:
      release: a composite with one version attribute and one struct per artifact —
        compiler, annotation_processing, and jvm_abi_gen — each holding url_templates and
        sha256. See versions.KOTLIN_CURRENT_COMPILER_EMBEDDABLE_RELEASE for the default
        release.
    """
    versions.use_repository(
        http_file,
        name = "kotlin_compiler_embeddable",
        version = version(
            version = release.version,
            url_templates = release.compiler.url_templates,
            sha256 = release.compiler.sha256,
        ),
        downloaded_file_path = "kotlin-compiler-embeddable.jar",
    )
    versions.use_repository(
        http_file,
        name = "kotlin_annotation_processing_embeddable",
        version = version(
            version = release.version,
            url_templates = release.annotation_processing.url_templates,
            sha256 = release.annotation_processing.sha256,
        ),
        downloaded_file_path = "kotlin-annotation-processing-embeddable.jar",
    )
    versions.use_repository(
        http_file,
        name = "jvm_abi_gen",
        version = version(
            version = release.version,
            url_templates = release.jvm_abi_gen.url_templates,
            sha256 = release.jvm_abi_gen.sha256,
        ),
        downloaded_file_path = "jvm-abi-gen.jar",
    )
