load(
    "@bazel_skylib//lib:unittest.bzl",
    "asserts",
    "unittest",
)
load("//kotlin/internal:btapi_runtime.bzl", "BTAPI_RUNTIME_ATTRIBUTES")
load("//src/main/starlark/core/repositories:btapi_impl.bzl", "btapi_impl_build_file")
load("//src/main/starlark/core/repositories:bzlmod_impl.bzl", "collect_btapi_impl_releases")
load(
    "//src/main/starlark/core/repositories:initialize.release.bzl",
    "btapi_impl_version",
    "versions",
)

# The artifacts a record names: record field, Maven artifact id.
_ARTIFACTS = [
    ("build_tools_impl", "kotlin-build-tools-impl"),
    ("compiler", "kotlin-compiler-embeddable"),
    ("annotation_processing", "kotlin-annotation-processing-embeddable"),
    ("jvm_abi_gen", "jvm-abi-gen"),
    ("stdlib", "kotlin-stdlib"),
    ("reflect", "kotlin-reflect"),
    ("daemon_client", "kotlin-daemon-client"),
    ("script_runtime", "kotlin-script-runtime"),
]

_CHECKSUMS = {
    "annotation_processing_sha256": "kaptsha",
    "build_tools_impl_sha256": "implsha",
    "compiler_sha256": "compilersha",
    "daemon_client_sha256": "daemonsha",
    "jvm_abi_gen_sha256": "abisha",
    "reflect_sha256": "reflectsha",
    "script_runtime_sha256": "scriptsha",
    "stdlib_sha256": "stdlibsha",
}

def _release(version = "2.4.0"):
    return btapi_impl_version(version = version, **_CHECKSUMS)

def _constructor_carries_every_artifact_test(ctx):
    """The constructor carries the release version once and one checksum per artifact."""
    env = unittest.begin(ctx)

    release = _release()
    asserts.equals(env, "2.4.0", release.version)
    for field, _ in _ARTIFACTS:
        asserts.equals(env, _CHECKSUMS[field + "_sha256"], getattr(release, field).sha256)

    return unittest.end(env)

def _constructor_keeps_the_default_urls_test(ctx):
    """The constructor downloads from the same locations as the record of the current release."""
    env = unittest.begin(ctx)

    release = _release()
    default_release = versions.BTAPI_IMPL_CURRENT_RELEASE
    for field, artifact_id in _ARTIFACTS:
        asserts.equals(env, getattr(default_release, field).url_templates, getattr(release, field).url_templates)
        asserts.true(env, artifact_id + "-{version}.jar" in getattr(release, field).url_templates[0], artifact_id)

    return unittest.end(env)

def _default_release_matches_the_compiler_test(ctx):
    """The record of the current release carries the version of the default CLI distribution."""
    env = unittest.begin(ctx)

    asserts.equals(
        env,
        versions.KOTLIN_CURRENT_COMPILER_RELEASE.version,
        versions.BTAPI_IMPL_CURRENT_RELEASE.version,
    )

    return unittest.end(env)

def _build_file_declares_the_runtime_test(ctx):
    """The generated BUILD file exports every jar and composes the runtime from them."""
    env = unittest.begin(ctx)

    build_file = btapi_impl_build_file(_release())
    asserts.true(env, '"kt_btapi_runtime")' in build_file, build_file)
    asserts.true(env, 'name = "runtime"' in build_file, build_file)
    for _, artifact_id in _ARTIFACTS:
        asserts.true(env, '":%s.jar"' % artifact_id in build_file, artifact_id)
    asserts.true(env, 'build_tools_impl = [":kotlin-build-tools-impl.jar"]' in build_file, build_file)
    asserts.true(env, 'compiler = [":kotlin-compiler-embeddable.jar"]' in build_file, build_file)
    asserts.true(env, 'kapt = [":kotlin-annotation-processing-embeddable.jar"]' in build_file, build_file)
    asserts.true(env, 'jvm_abi_gen = [":jvm-abi-gen.jar"]' in build_file, build_file)
    asserts.true(env, 'libraries = [":kotlin-daemon-client.jar", ":kotlin-stdlib.jar", ":kotlin-reflect.jar", ":kotlin-script-runtime.jar", ' in build_file, build_file)
    asserts.true(env, "jdeps-gen-embeddable" in build_file and "skip-code-gen-embeddable" in build_file, build_file)
    asserts.true(env, "kotlinx_coroutines_core_jvm" in build_file, build_file)
    asserts.true(env, "kotlin-compiler.jar" not in build_file, build_file)

    return unittest.end(env)

def _runtime_attributes_in(build_file):
    """The attribute names the kt_btapi_runtime declaration of the BUILD file sets, name excluded."""
    names = []
    in_runtime = False
    for line in build_file.splitlines():
        if line.startswith("kt_btapi_runtime("):
            in_runtime = True
        elif line == ")":
            in_runtime = False
        elif in_runtime and " = " in line:
            name = line.strip().split(" = ")[0]
            if name != "name":
                names.append(name)
    return sorted(names)

def _build_file_sets_every_runtime_attribute_test(ctx):
    """The generated declaration sets exactly the attributes kt_btapi_runtime defines.

    The repository layer writes the declaration as text and the rule layer parses it, so this is the
    one place both sides of that contract meet.
    """
    env = unittest.begin(ctx)

    asserts.equals(env, BTAPI_RUNTIME_ATTRIBUTES, _runtime_attributes_in(btapi_impl_build_file(_release())))

    return unittest.end(env)

def _tag(name, version):
    return struct(name = name, version = version, **_CHECKSUMS)

def _module(name, is_root, tags):
    return struct(name = name, is_root = is_root, tags = struct(btapi_impl_version = tags))

def _tags_become_named_records_test(ctx):
    """Every root-module tag becomes one record under the tag's name."""
    env = unittest.begin(ctx)

    releases = collect_btapi_impl_releases(
        [
            _module("root", True, [_tag("kotlin_2_4_0", "2.4.0"), _tag("btapi_impl", "2.4.20")]),
            _module("dependency", False, []),
        ],
    )
    asserts.equals(env, ["kotlin_2_4_0", "btapi_impl"], releases.keys())
    asserts.equals(env, "2.4.0", releases["kotlin_2_4_0"].version)
    asserts.equals(env, "2.4.20", releases["btapi_impl"].version)
    asserts.equals(env, "compilersha", releases["kotlin_2_4_0"].compiler.sha256)

    return unittest.end(env)

def _no_tags_keep_the_defaults_test(ctx):
    """Without tags the extension leaves the records to kotlin_repositories."""
    env = unittest.begin(ctx)

    asserts.equals(env, {}, collect_btapi_impl_releases([_module("root", True, [])]))

    return unittest.end(env)

constructor_carries_every_artifact_test = unittest.make(_constructor_carries_every_artifact_test)
constructor_keeps_the_default_urls_test = unittest.make(_constructor_keeps_the_default_urls_test)
default_release_matches_the_compiler_test = unittest.make(_default_release_matches_the_compiler_test)
build_file_declares_the_runtime_test = unittest.make(_build_file_declares_the_runtime_test)
build_file_sets_every_runtime_attribute_test = unittest.make(_build_file_sets_every_runtime_attribute_test)
tags_become_named_records_test = unittest.make(_tags_become_named_records_test)
no_tags_keep_the_defaults_test = unittest.make(_no_tags_keep_the_defaults_test)

def btapi_impl_release_test_suite(name):
    unittest.suite(
        name,
        constructor_carries_every_artifact_test,
        constructor_keeps_the_default_urls_test,
        default_release_matches_the_compiler_test,
        build_file_declares_the_runtime_test,
        build_file_sets_every_runtime_attribute_test,
        tags_become_named_records_test,
        no_tags_keep_the_defaults_test,
    )
