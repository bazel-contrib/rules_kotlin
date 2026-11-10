# Kover Code Coverage Example

This example demonstrates how to use [Kover](https://kotlin.github.io/kotlinx-kover/) as an
alternative to JaCoCo for Kotlin code coverage in rules_kotlin.

Unlike JaCoCo, Kover uses a JVM agent for runtime instrumentation, so application code does not
need to be recompiled with coverage flags.

## Setup

Enable Kover in your toolchain definition:

```starlark
load("@rules_kotlin//kotlin:core.bzl", "define_kt_toolchain")

define_kt_toolchain(
    name = "kotlin_toolchain",
    experimental_kover_enabled = True,
    experimental_kover_agent = "@maven//:org_jetbrains_kotlinx_kover_jvm_agent",
    experimental_kover_cli = "@maven//:org_jetbrains_kotlinx_kover_cli",
)
```

Use the same version of the agent and CLI in your toolchain:

```starlark
maven.install(
    artifacts = [
        "org.jetbrains.kotlinx:kover-jvm-agent:0.8.3",
        "org.jetbrains.kotlinx:kover-cli:0.8.3",
        ...
    ],
)
```

Register the toolchain in `MODULE.bazel`:

```starlark
register_toolchains("//:kotlin_toolchain")
```

## Running coverage

From `examples/kover` on Linux or macOS:

```sh
bazel coverage --combined_report=lcov //app:all
cat bazel-testlogs/app/greeter_test/coverage.dat
diff expected_coverage.dat bazel-out/_coverage/_coverage_report.dat
```

The two tests exercise different returns in `Greeter.greet`. Each per-test report
records an executable line as covered (1) or missed (0). Bazel sums those counts
in the combined report. The integration suite checks the combined report against
`expected_coverage.dat`.

The Unix JVM test launcher points the Kover agent at `$COVERAGE_DIR`. Bazel's
LCOV merger step for `kt_jvm_test` runs the matching Kover CLI in-process,
converts its report to `kover.dat`, then merges as usual, so Kover adds no JVM
launches per test. The test target only depends on its application code and
test libraries.

This prototype reports line coverage. Android local tests and the Windows JVM
launcher do not implement this conversion. Omitting `experimental_kover_cli`
retains the existing agent-only behavior.
