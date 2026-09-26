#!/usr/bin/env bash
set -euo pipefail

# Use only declared inputs and private test directories. The outer Bazel build
# has already loaded Kotlin to produce the release, so test a separate consumer.
export BAZELISK_HOME="${TEST_TMPDIR}/bazelisk"
mkdir -p "${TEST_TMPDIR}/rules_kotlin" "${TEST_TMPDIR}/consumer"
# Read stdin so GNU tar does not treat a Windows drive letter as a remote host.
tar -xzf - -C "${TEST_TMPDIR}/rules_kotlin" < "${TEST_SRCDIR}/${RULES_KOTLIN_RELEASE}"
cd "${TEST_TMPDIR}/consumer"

cat > MODULE.bazel <<'EOF'
module(name = "unrelated_cpp")
bazel_dep(name = "rules_cc", version = "0.2.17")
bazel_dep(name = "rules_kotlin", version = "2.2.0")
EOF
cat > BUILD.bazel <<'EOF'
load("@rules_cc//cc:cc_library.bzl", "cc_library")
cc_library(name = "empty")
EOF

bazel=(
    "${BIT_BAZEL_BINARY}" --batch --ignore_all_rc_files
    # Honor the host's address ordering, including IPv6-only CI networks.
    --host_jvm_args=-Djava.net.preferIPv6Addresses=system
    "--output_user_root=${TEST_TMPDIR}/bazel"
    "--output_base=${TEST_TMPDIR}/output"
    build --repo_contents_cache= --jobs=2 --noshow_progress --color=no
    "--override_module=rules_kotlin=${TEST_TMPDIR}/rules_kotlin"
)

metadata_present() {
    # Identify contents, rather than depending on canonical repository names.
    for repo in "${TEST_TMPDIR}/output/external/"*; do
        if [[ -f "${repo}/capabilities.bzl" && -f "${repo}/artifacts.bzl" ]]; then
            return 0
        fi
    done
    return 1
}

"${bazel[@]}" //:empty
if metadata_present; then
    echo "Unrelated C++ build materialized Kotlin capabilities" >&2
    exit 1
fi

# Positive control: Kotlin options must load metadata, without the compiler.
"${bazel[@]}" @rules_kotlin//kotlin/internal:default_kotlinc_options
if ! metadata_present; then
    echo "Kotlin options did not materialize capabilities" >&2
    exit 1
fi
for repo in "${TEST_TMPDIR}/output/external/"*; do
    if [[ -f "${repo}/lib/kotlin-compiler.jar" ]]; then
        echo "Kotlin options unnecessarily fetched the compiler" >&2
        exit 1
    fi
done
