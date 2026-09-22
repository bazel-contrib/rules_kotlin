#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

# Set by GH actions, see
# https://docs.github.com/en/actions/learn-github-actions/environment-variables#default-environment-variables
TAG=${GITHUB_REF_NAME}
ARCHIVE="rules_kotlin-$TAG.tar.gz"
bazel --bazelrc=.github/workflows/ci.bazelrc --bazelrc=.bazelrc test //tools:release_archive_test
cp bazel-bin/tools/rules_kotlin_release.tgz "$ARCHIVE"

# Write the release notes to release_notes.txt
cat > release_notes.txt << EOF
# Release notes for $TAG
## Using Bzlmod

1. Enable with \`common --enable_bzlmod\` in \`.bazelrc\`.
2. Add to your \`MODULE.bazel\` file:

\`\`\`starlark
bazel_dep(name = "rules_kotlin", version = "${TAG:1}")
\`\`\`

The release archive contains sources. Bazel compiles the workers and compiler plugins when
building your targets. Bzlmod is required; legacy WORKSPACE setup is no longer supported.
EOF
