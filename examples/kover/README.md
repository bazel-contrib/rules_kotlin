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
)
```

Add the Kover JVM agent to your Maven dependencies:

```starlark
maven.install(
    artifacts = [
        "org.jetbrains.kotlinx:kover-jvm-agent:0.8.3",
        ...
    ],
)
```

Register the toolchain in `MODULE.bazel`:

```starlark
register_toolchains("//:kotlin_toolchain")
```

## Running coverage

From `examples/kover` with Bazel 9.3.2 on Linux or macOS, run the same coverage test with output path
mapping disabled and enabled. Use `--modify_execution_info` to opt the sandboxed
`KotlinCompile` actions into path mapping for this run.

```sh
for mode in off strip; do
  bazel coverage --experimental_output_paths="$mode" --strategy=KotlinCompile=sandboxed \
    --modify_execution_info=KotlinCompile=+supports-path-mapping \
    --incompatible_enable_proto_toolchain_resolution --@@protobuf+//bazel/toolchains:prefer_prebuilt_protoc=true \
    --nocache_test_results //app:greeter_test || exit 1
done
```

To inspect the mapping, add `--execution_log_json_file=/tmp/kover-$mode.json` inside
the loop. In the `KotlinCompile` spawn for `//app:greeter`, the `--flagfile` path
uses `bazel-out/cfg/bin` in strip mode and the configuration directory in off mode.

These commands run the Kover agent. Its binary report is written inside the test's
runfiles workspace and is discarded with the test sandbox.

Report generation and validation live in `//src/test/kover:report_test`. From the
rules_kotlin repository root, run:

```sh
bazel test //src/test/kover:report_test
```

This test invokes the Kover CLI with Bazel-generated metadata and checks covered,
missed, and excluded code. It saves `report.xml` and `exercise_test-kover_report.ic`
under `bazel-testlogs/src/test/kover/report_test/test.outputs/`.
