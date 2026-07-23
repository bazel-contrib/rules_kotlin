#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

# Set by GH actions, see
# https://docs.github.com/en/actions/learn-github-actions/environment-variables#default-environment-variables
TAG=${GITHUB_REF_NAME}
ARCHIVE="rules_kotlin-$TAG.tar.gz"
git archive --format=tar.gz --output="$ARCHIVE" "$TAG"
SHA=$(shasum -a 256 $ARCHIVE | awk '{print $1}')

# Write the release notes to release_notes.txt
cat > release_notes.txt << EOF
# Release notes for $TAG
## Using Bzlmod with Bazel 7

1. Enable with \`common --enable_bzlmod\` in \`.bazelrc\`.
2. Add to your \`MODULE.bazel\` file:

\`\`\`starlark
bazel_dep(name = "rules_kotlin", version = "${TAG:1}")
\`\`\`

## Using WORKSPACE

Paste this snippet into your \`WORKSPACE.bazel\` file:

\`\`\`starlark
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
http_archive(
    name = "rules_kotlin",
    sha256 = "${SHA}",
    url = "https://github.com/bazel-contrib/rules_kotlin/releases/download/${TAG}/${ARCHIVE}",
)

load("@rules_kotlin//kotlin:repositories.bzl", "kotlin_repositories")
kotlin_repositories() # if you want the default. Otherwise see custom kotlinc distribution below

load("@rules_kotlin//kotlin:core.bzl", "kt_register_toolchains")
kt_register_toolchains() # to use the default toolchain, otherwise see toolchains below
\`\`\`
EOF
