load(
    "@bazel_skylib//lib:unittest.bzl",
    "asserts",
    "unittest",
)
load(
    "//src/main/starlark/core/repositories:initialize.release.bzl",
    "kotlinc_embeddable_version",
    "versions",
)

def _constructor_retargets_every_artifact_test(ctx):
    """The constructor carries the release version once and one checksum per artifact."""
    env = unittest.begin(ctx)

    release = kotlinc_embeddable_version(
        version = "2.3.11",
        compiler_sha256 = "compilersha",
        annotation_processing_sha256 = "kaptsha",
        jvm_abi_gen_sha256 = "abisha",
    )
    asserts.equals(env, "2.3.11", release.version)
    asserts.equals(env, "compilersha", release.compiler.sha256)
    asserts.equals(env, "kaptsha", release.annotation_processing.sha256)
    asserts.equals(env, "abisha", release.jvm_abi_gen.sha256)

    return unittest.end(env)

def _constructor_keeps_the_default_urls_test(ctx):
    """The constructor downloads from the same locations as the default release."""
    env = unittest.begin(ctx)

    release = kotlinc_embeddable_version(
        version = "2.3.11",
        compiler_sha256 = "compilersha",
        annotation_processing_sha256 = "kaptsha",
        jvm_abi_gen_sha256 = "abisha",
    )
    default_release = versions.KOTLIN_CURRENT_COMPILER_EMBEDDABLE_RELEASE
    asserts.equals(env, default_release.compiler.url_templates, release.compiler.url_templates)
    asserts.equals(
        env,
        default_release.annotation_processing.url_templates,
        release.annotation_processing.url_templates,
    )
    asserts.equals(env, default_release.jvm_abi_gen.url_templates, release.jvm_abi_gen.url_templates)

    return unittest.end(env)

def _default_release_matches_the_compiler_test(ctx):
    """The default embeddable release carries the version of the default CLI distribution."""
    env = unittest.begin(ctx)

    asserts.equals(
        env,
        versions.KOTLIN_CURRENT_COMPILER_RELEASE.version,
        versions.KOTLIN_CURRENT_COMPILER_EMBEDDABLE_RELEASE.version,
    )

    return unittest.end(env)

constructor_retargets_every_artifact_test = unittest.make(_constructor_retargets_every_artifact_test)
constructor_keeps_the_default_urls_test = unittest.make(_constructor_keeps_the_default_urls_test)
default_release_matches_the_compiler_test = unittest.make(_default_release_matches_the_compiler_test)

def embeddable_release_test_suite(name):
    unittest.suite(
        name,
        constructor_retargets_every_artifact_test,
        constructor_keeps_the_default_urls_test,
        default_release_matches_the_compiler_test,
    )
