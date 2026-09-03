def configure_modules_and_repositories(modules, kotlin_repositories, kotlinc_version, ksp_version, kotlinc_embeddable_version):
    kotlinc = None
    ksp = None
    embeddable = None
    for mod in modules:
        for override in mod.tags.kotlinc_version:
            if kotlinc:
                fail("Only one kotlinc_version is supported right now!")
            kotlinc = kotlinc_version(release = override.version, sha256 = override.sha256)
        for override in mod.tags.compiler_embeddable_release:
            if embeddable:
                fail("Only one compiler_embeddable_release is supported right now!")
            embeddable = kotlinc_embeddable_version(
                version = override.version,
                compiler_sha256 = override.compiler_sha256,
                annotation_processing_sha256 = override.annotation_processing_sha256,
                jvm_abi_gen_sha256 = override.jvm_abi_gen_sha256,
            )
        for override in mod.tags.ksp_version:
            if ksp:
                fail("Only one ksp_version is supported right now!")
            ksp = ksp_version(release = override.version, sha256 = override.sha256)

    kotlin_repositories_args = dict(is_bzlmod = True)
    if kotlinc:
        kotlin_repositories_args["compiler_release"] = kotlinc
    if ksp:
        kotlin_repositories_args["ksp_compiler_release"] = ksp
    if embeddable:
        kotlin_repositories_args["compiler_embeddable_release"] = embeddable

    kotlin_repositories(**kotlin_repositories_args)

_version_tag = tag_class(
    attrs = {
        "sha256": attr.string(mandatory = True),
        "version": attr.string(mandatory = True),
    },
)

_embeddable_release_tag = tag_class(
    attrs = {
        "annotation_processing_sha256": attr.string(mandatory = True),
        "compiler_sha256": attr.string(mandatory = True),
        "jvm_abi_gen_sha256": attr.string(mandatory = True),
        "version": attr.string(mandatory = True),
    },
)

tag_classes = {
    "compiler_embeddable_release": _embeddable_release_tag,
    "kotlinc_version": _version_tag,
    "ksp_version": _version_tag,
}
