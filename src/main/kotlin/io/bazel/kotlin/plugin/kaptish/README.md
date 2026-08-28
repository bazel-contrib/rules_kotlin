# Kaptish: Fast Annotation Processing for Kotlin

Kaptish is an experimental optimization for annotation processing in Kotlin that bypasses KAPT's stub generation phase, resulting in 1.75-2x faster builds.

## Background: How KAPT Works

KAPT (Kotlin Annotation Processing Tool) enables Java annotation processors to work with Kotlin code. It uses a 3-pass approach:

1. **Stub Generation**: Generate Java stubs (`.java` files) from Kotlin sources
2. **Annotation Processing**: Run Java annotation processors on the stubs
3. **Compilation**: Compile everything (Kotlin + Java + generated sources)

The stub generation phase is expensive because it requires parsing and analyzing all Kotlin sources to produce Java-compatible signatures.

## How Kaptish Works

Kaptish eliminates stub generation by compiling Kotlin first and injecting the compiled classes into javac's annotation processing phase:

1. **Kotlin Compilation**: Compile Kotlin sources to `.class` files (no stubs)
2. **Class Injection**: The `KotlinClassInjectorPlugin` annotation processor scans the classpath for Kotlin-compiled JARs and injects their class names into javac's `Arguments.classNames`
3. **Annotation Processing**: Java annotation processors run on the compiled Kotlin classes
4. **Java Compilation**: Compile any Java sources + AP-generated sources

This approach works because annotation processors primarily need type information (class names, method signatures, annotations), which is available in compiled `.class` files.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Kaptish Flow                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Kotlin Compilation                                          │
│     ┌──────────┐      ┌──────────────┐                         │
│     │ *.kt     │ ───► │ kotlinc     │ ───► kotlin.jar          │
│     └──────────┘      └──────────────┘      (.class files)     │
│                                                                 │
│  2. Java Compilation with AP                                    │
│     ┌──────────┐      ┌──────────────┐      ┌───────────────┐  │
│     │ *.java   │ ───► │ javac + AP   │ ───► │ java.jar      │  │
│     └──────────┘      └──────────────┘      │ + generated   │  │
│           │                  ▲               └───────────────┘  │
│           │                  │                                  │
│           │    ┌─────────────┴─────────────┐                   │
│           │    │ KotlinClassInjectorPlugin │                   │
│           │    │ - Scans classpath         │                   │
│           │    │ - Finds .kotlin_module    │                   │
│           │    │ - Injects class names     │                   │
│           │    └───────────────────────────┘                   │
│           │                  ▲                                  │
│           │                  │                                  │
│           └──────────────────┼──────────────────────────────── │
│                              │                                  │
│                        kotlin.jar (on classpath)               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Implementation Details

### KotlinClassInjectorPlugin

The core component is `KotlinClassInjectorPlugin.java`, an annotation processor that:

1. **Runs first** during annotation processing (registered via `javax.annotation.processing.Processor` service)
2. **Scans the classpath** for JARs containing `.kotlin_module` files (indicating Kotlin-compiled code)
3. **Extracts class names** from those JARs (excluding inner classes, module-info, package-info)
4. **Injects class names** into `Arguments.instance(context).getClassNames()` so javac processes them

```java
// Simplified injection logic
JavacProcessingEnvironment javacEnv = unwrap(processingEnv);
Context context = javacEnv.getContext();
Arguments arguments = Arguments.instance(context);
arguments.getClassNames().addAll(kotlinClassNames);
```

### Build Integration

The Bazel integration in `compile.bzl`:

1. Checks if kaptish is enabled via `is_kaptish_enabled()`
2. Skips KAPT when kaptish is active
3. Adds a placeholder Java file if no Java sources exist (to trigger AP)
4. Adds the Kotlin output JAR to the classpath
5. Adds `KotlinClassInjectorPlugin` to the annotation processor plugins

## Usage

### Enable Kaptish in Toolchain

Add `experimental_kaptish_enabled = True` to your Kotlin toolchain definition:

```starlark
load("@rules_kotlin//kotlin:core.bzl", "define_kt_toolchain")

define_kt_toolchain(
    name = "kotlin_toolchain",
    experimental_kaptish_enabled = True,
    # ... other options
)
```

### Opt-Out Per Target

If a specific target has issues with kaptish, add the `kaptish_disabled` tag to fall back to KAPT:

```starlark
kt_jvm_library(
    name = "my_library",
    srcs = ["MyClass.kt"],
    plugins = ["//path/to:my_annotation_processor"],
    tags = ["kaptish_disabled"],  # Falls back to KAPT
)
```

## When to Use Kaptish

**Good candidates:**
- Projects with many Kotlin files and annotation processors
- Annotation processors that primarily read type information (AutoValue, Dagger, etc.)
- Build performance is a priority

**Consider KAPT (use `kaptish_disabled`) when:**
- Annotation processors that require source-level information not available in bytecode
- Encountering issues with specific annotation processors
- Debugging annotation processor behavior

## Limitations

1. **JDK Internal APIs**: Uses internal javac APIs (`com.sun.tools.javac.*`) which may change between JDK versions
2. **Bytecode vs Source**: Some annotation processors may behave differently when processing bytecode vs source stubs
3. **Experimental**: This is an experimental feature; test thoroughly before enabling globally

## Files

```
src/main/kotlin/io/bazel/kotlin/plugin/kaptish/
├── BUILD.bazel                    # Build rules
├── KotlinClassInjectorPlugin.java # The annotation processor
└── README.md                      # This file

kotlin/internal/jvm/
├── kaptish.bzl                    # Helper functions
└── compile.bzl                    # Integration (modified)

kotlin/internal/
└── toolchains.bzl                 # Toolchain attribute (modified)
```

## Testing

Run the kaptish tests:

```bash
bazel test //src/test/kotlin/io/bazel/kotlin:KotlinJvmKaptishAssertionTest
```

Test targets are in `src/test/data/jvm/kaptish/`.
