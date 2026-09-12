#!/usr/bin/env bash
set -euo pipefail

unpack="$TEST_TMPDIR/archive"
mkdir -p "$unpack"
tar -xzf "$1" -C "$unpack"
cmp "$2" "$unpack/MODULE.bazel"
for source in BUILD LICENSE .editorconfig kotlin/repositories.bzl src/main/kotlin/bootstrap.bzl src/main/kotlin/io/bazel/kotlin/builder/tasks/jvm/CompilationTask.kt src/main/kotlin/io/bazel/kotlin/ksp2/Ksp2Invoker.kt src/main/protobuf/deps.proto; do
    test -f "$unpack/$source"
done
for excluded in examples src/test tools; do
    test ! -e "$unpack/$excluded"
done
if find "$unpack" -type f \( -name '*.jar' -o -name '*.class' -o -name '*.release.*' \) | grep .; then
    echo "Release archive must contain sources, without precompiled tools or release-specific files" >&2
    exit 1
fi
