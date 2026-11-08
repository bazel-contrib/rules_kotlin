#!/usr/bin/env bash
set -euo pipefail

child="$(dirname "$0")"/%child%
if [[ -z "${COVERAGE_DIR:-}" || ! -s "${COVERAGE_MANIFEST:-}" ]]; then
  exec "$child" "$@"
fi

raw="$TEST_TMPDIR/kover.ic"
xml="$TEST_TMPDIR/kover.xml"
agent=%agent%
printf 'report.file=%s\n' "$raw" > "$TEST_TMPDIR/kover.args"
"$child" "--jvm_flag=-Xbootclasspath/a:$agent" \
  "--jvm_flag=-javaagent:$agent=file:$TEST_TMPDIR/kover.args" "$@"

test -s "$raw"
%java% -jar %cli% %metadata% "$raw" --xml "$xml"
exec %java% -cp %writer% io.bazel.kotlin.coverage.KoverLcov "$xml" "$COVERAGE_MANIFEST" "$COVERAGE_DIR/kover.dat"
