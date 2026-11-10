#!/usr/bin/env bash
# Runs the test with the Kover agent writing to $COVERAGE_DIR. Bazel's LCOV merger step converts it.
set -euo pipefail

child="$(dirname "$0")"/%child%
# Skip the agent when nothing this test runs is instrumented.
if [[ -z "${COVERAGE_DIR:-}" ]] || ! grep -qE '\.(kt|java)$' "${COVERAGE_MANIFEST:-/dev/null}"; then
  exec "$child" "$@"
fi

printf 'report.file=%s\n' "$COVERAGE_DIR/kover.ic" > "$TEST_TMPDIR/kover.args"
exec "$child" "--jvm_flag=-Xbootclasspath/a:"%agent% \
  "--jvm_flag=-javaagent:"%agent%"=file:$TEST_TMPDIR/kover.args" "$@"
