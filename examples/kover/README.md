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

```sh
bazel coverage //app:greeter_test
```

Kover produces two output files alongside each test target:

- `<target>-kover_report.ic` — raw binary coverage data
- `<target>-kover_metadata.txt` — arguments file for the Kover CLI to generate a report

To generate a human-readable report, pass the metadata file to the Kover CLI:

```sh
java -jar kover-cli.jar report @bazel-bin/app/greeter_test-kover_metadata.txt
```
