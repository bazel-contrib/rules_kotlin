# Kaptish Example

This example demonstrates annotation processing in Kotlin using **kaptish** — an
experimental optimization that replaces KAPT's stub generation phase with direct
class injection into javac's annotation processing phase.

## What is Kaptish?

KAPT (Kotlin Annotation Processing Tool) works in three passes:
1. **Stub generation** — parse all Kotlin sources and emit Java stubs (expensive)
2. **Annotation processing** — run Java annotation processors on the stubs
3. **Compilation** — compile Kotlin + Java + AP-generated sources

Kaptish eliminates stub generation by compiling Kotlin first and injecting the
resulting class names into javac's AP phase. The flow becomes:
1. **Kotlin compilation** — kotlinc compiles Kotlin sources to `.class` files
2. **Class injection** — `KotlinClassInjectorPlugin` scans for Kotlin JARs and
   injects their class names into `javac`'s internal class list
3. **Annotation processing** — Java annotation processors run on compiled classes
4. **Java compilation** — AP-generated Java sources are compiled

This typically yields **1.75–2× faster** annotation processing for Kotlin targets.

## Example Targets

### `shapes_lib`

A single Kotlin file (`src/Shape.kt`) annotated with `@AutoValue`.
AutoValue generates an immutable implementation class `AutoValue_Shape`.

### `geometry_lib`

Two Kotlin files (`src/Circle.kt`, `src/Rectangle.kt`) each annotated with
`@AutoValue`. Demonstrates kaptish working across multiple source files.

## Build

```bash
bazel build //...
```

To confirm the build succeeds including the `build_test`:

```bash
bazel test //:kaptish_build_test
```

## Enable Kaptish in Your Toolchain

The kaptish-enabled toolchain is defined in `BUILD.bazel`:

```starlark
define_kt_toolchain(
    name = "kotlin_toolchain",
    experimental_kaptish_enabled = True,
)
```

This is registered automatically. All `kt_jvm_library` targets in this workspace
use kaptish when they have annotation processor plugins.

## Opt Out Per Target

If a specific target has incompatible annotation processors, add the
`kaptish_disabled` tag to fall back to KAPT:

```starlark
kt_jvm_library(
    name = "my_lib",
    srcs = ["MyClass.kt"],
    plugins = ["//:my_processor"],
    tags = ["kaptish_disabled"],  # Falls back to KAPT
)
```

## Verify KAPT Is Not Run

Use `bazel aquery` to inspect the action graph and confirm that no KAPT
(`KotlinBuilder KaptGenerateStubs`) actions are present:

```bash
bazel aquery '//:shapes_lib' --output=text 2>/dev/null | grep -i "kapt\|KaptGenerate"
```

If kaptish is active, this command produces **no output** — there are no KAPT
actions in the build graph.

To see the kaptish action that runs instead (javac with the
`KotlinClassInjectorPlugin`):

```bash
bazel aquery '//:shapes_lib' --output=text 2>/dev/null | grep -A5 "JavaBuilder\|KotlinBuilder Kt"
```

You will see two main actions:
1. `KotlinBuilder Kt` — compiles Kotlin sources (no KAPT stub generation)
2. `JavaBuilder` — compiles the placeholder Java file with annotation processors,
   including `KotlinClassInjectorPlugin` which injects the Kotlin class names

## Limitations

- **Generated class visibility**: Because Kotlin compiles before AP runs,
  `AutoValue_Shape` is not visible to Kotlin code at compile time. Reference
  generated classes from Java code, or use the abstract factory pattern.
- **JDK internal APIs**: `KotlinClassInjectorPlugin` uses `com.sun.tools.javac.*`
  internal APIs that may change between JDK versions.
- **Experimental**: Test thoroughly before enabling globally.

## Files

```
examples/kaptish/
├── .bazelrc                       # JVM version configuration
├── BUILD.bazel                    # kt_jvm_library targets + kaptish toolchain
├── MODULE.bazel                   # Bazel module + Maven dependencies
├── maven_install.json             # Pinned Maven lock file
├── src/
│   ├── Shape.kt                   # @AutoValue value class (shapes_lib)
│   ├── Circle.kt                  # @AutoValue value class (geometry_lib)
│   └── Rectangle.kt               # @AutoValue value class (geometry_lib)
└── third_party/
    └── BUILD.bazel                # AutoValue java_plugin definition
```
