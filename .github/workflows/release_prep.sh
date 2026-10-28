#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

# Set by GH actions, see
# https://docs.github.com/en/actions/learn-github-actions/environment-variables#default-environment-variables
TAG=${GITHUB_REF_NAME}
# The prefix is chosen to match what GitHub generates for source archives
PREFIX="rules_kotlin-${TAG:1}"
ARCHIVE="rules_kotlin-$TAG.tar.gz"
bazel --bazelrc=.github/workflows/ci.bazelrc --bazelrc=.bazelrc build \
  --//src/main/starlark/release:tag="$TAG" \
  //:rules_kotlin_release //src/main/kotlin:rules_kotlin_jars
cp bazel-bin/rules_kotlin_release.tgz $ARCHIVE
# The prebuilt jars are published as a separate release asset, see MODULE.release.bazel.
cp bazel-bin/src/main/kotlin/rules_kotlin_jars.tar.gz .
SHA=$(shasum -a 256 $ARCHIVE | awk '{print $1}')

# Write the release notes to release_notes.txt
cat > release_notes.txt << EOF
# Release notes for $TAG

## Setup

rules_kotlin requires Bzlmod. Add to your \`MODULE.bazel\` file:

\`\`\`starlark
bazel_dep(name = "rules_kotlin", version = "${TAG:1}")

rules_kotlin_extensions = use_extension(
    "@rules_kotlin//src/main/starlark/core/repositories:bzlmod_setup.bzl",
    "rules_kotlin_extensions",
)
use_repo(rules_kotlin_extensions, "com_github_jetbrains_kotlin")

register_toolchains("@rules_kotlin//kotlin/internal:default_toolchain")
\`\`\`

Archive \`${ARCHIVE}\` sha256: \`${SHA}\`.
EOF
