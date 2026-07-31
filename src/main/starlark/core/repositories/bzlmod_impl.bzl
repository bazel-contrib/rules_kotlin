load(":btapi_impl.bzl", "btapi_impl_version_from_tag")

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

    kotlin_repositories_args = dict(is_bzlmod = True)
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
