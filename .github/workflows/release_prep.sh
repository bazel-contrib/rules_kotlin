#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

# Set by GH actions, see
# https://docs.github.com/en/actions/learn-github-actions/environment-variables#default-environment-variables
export TAG=${GITHUB_REF_NAME}
# The prefix is chosen to match what GitHub generates for source archives
ARCHIVE="rules_kotlin-$TAG.tar.gz"
bazel --bazelrc=.github/workflows/ci.bazelrc --bazelrc=.bazelrc \
    build --stamp --embed_label "$TAG" //:rules_kotlin_release
cp bazel-bin/rules_kotlin_release.tgz $ARCHIVE

# Build build release metadata and stage.
bazel --bazelrc=.github/workflows/ci.bazelrc --bazelrc=.bazelrc \
    build --stamp --embed_label "$TAG" --output_groups=release "//:release_metadata"
cp -RL bazel-bin/release_metadata/jars/. blobs/
cp bazel-bin/release_metadata/release_notes.md release_notes.txt
