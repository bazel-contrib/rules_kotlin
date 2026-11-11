#!/usr/bin/env bash
set -euo pipefail

"$@"

# Run the CLI in the same runfiles workspace as the agent, before Bazel discards the sandbox.
test -s app/greeter_test-kover_report.ic
test -r app/Greeter.kt
report="$TEST_UNDECLARED_OUTPUTS_DIR/greeter.xml"
app/kover_cli @app/greeter_test-kover_metadata.txt --xml "$report"
cp app/greeter_test-kover_report.ic "$TEST_UNDECLARED_OUTPUTS_DIR/"

awk '
    /<class name="app\/Greeter"/ { greeter = 1 }
    /<\/class>/ { greeter = 0 }
    /<method name="greet"/ { greet = greeter }
    /<\/method>/ { greet = 0 }
    greet && /<counter type="LINE"/ && /covered="[1-9][0-9]*"/ { hit = 1 }
    END { exit !hit }
' "$report"
