"""Analysis tests for the release_metadata rule."""

load("@rules_testing//lib:truth.bzl", "matching")
load("//src/main/starlark/release:metadata.bzl", "release_metadata")
load("//src/test/starlark:case.bzl", "suite")

def _release_metadata_assertions(env, target):
    # Generates release_manifest.bzl.
    default_basenames = [f.basename for f in target[DefaultInfo].files.to_list()]
    env.expect.that_collection(default_basenames).contains("release_manifest.bzl")

    # "release" output group is one symlink FILE per jar.
    release_files = target[OutputGroupInfo].release.to_list()
    release_basenames = [f.basename for f in release_files]
    env.expect.that_collection(release_basenames).contains("kotlin_a")
    env.expect.that_collection(release_basenames).contains("kotlin_b")

    # Generates release_notes.md into DefaultInfo.
    env.expect.that_collection(release_basenames).contains("release_notes.txt")

    # GenerateJarMetadata action requires version file and
    # the argv carries --version_file.
    action = env.expect.that_target(target).action_named("GenerateReleaseMetadata")
    action.argv().contains("--version_file")
    action.argv().contains("--out_notes")
    action.inputs().contains_predicate(matching.file_basename_contains("_status.txt"))

def _test_release_metadata_wires_stamp_and_outputs(test):
    a_jar = test.artifact("dummy_a.jar")
    b_jar = test.artifact("dummy_b.jar")
    target = test.have(
        release_metadata,
        name = "release_metadata",
        jars = {
            a_jar: "kotlin_a",
            b_jar: "kotlin_b",
        },
        urls = {
            "kotlin_a": "https://example.com/{name}-{version}.jar",
            "kotlin_b": "https://example.com/{name}-{version}.jar",
        },
    )

    test.claim(
        got = target,
        what = _release_metadata_assertions,
        wants = {},
    )

def release_metadata_test_suite(name):
    suite(
        name,
        stamp_and_outputs = _test_release_metadata_wires_stamp_and_outputs,
    )
