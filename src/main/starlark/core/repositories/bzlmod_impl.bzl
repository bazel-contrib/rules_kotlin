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

    kotlin_repositories_args = {}
    if kotlinc:
        kotlin_repositories_args["compiler_release"] = kotlinc
    if ksp:
        kotlin_repositories_args["ksp_compiler_release"] = ksp

    kotlin_repositories(**kotlin_repositories_args)

_version_tag = tag_class(
    attrs = {
        "sha256": attr.string(mandatory = True),
        "version": attr.string(mandatory = True),
    },
)

tag_classes = {
    "kotlinc_version": _version_tag,
    "ksp_version": _version_tag,
}
