# Nested Module Resources Example

## What This Tests

This example tests **resource path resolution across Bazel module boundaries** when using `resource_strip_prefix`.

## Problem Statement

When a target in one Bazel module depends on a library in an external Bazel module that has resources with a custom `resource_strip_prefix`, the resource paths need to be correctly resolved.

### Module Structure

```
nested_module_resources/          # Main module
├── MODULE.bazel                   # bazel_dep(name = "nested")
├── Main.kt                        # Calls @nested//:printer
└── nested/                        # SEPARATE BAZEL MODULE
    ├── MODULE.bazel               # module(name = "nested")
    ├── Printer.kt
    ├── BUILD.bazel                # resource_strip_prefix = "resourcez"
    └── resourcez/
        └── resource.txt
```

**Key Point:** `nested/` is a separate Bazel module with its own `MODULE.bazel`, not just a subdirectory.

## The Bug (Before Fix)

Without the fix in PR #1390, resource paths from external modules included the module path prefix, causing the strip prefix check to fail:

### With nested/ in .bazelignore:
```
Error in fail: Resource file ../nested+/resourcez/resource.txt is not under
the specified prefix to strip resourcez
```
- Resource path: `../nested+/resourcez/resource.txt`
- Strip prefix: `resourcez`
- Check fails: `../nested+/resourcez/resource.txt` doesn't start with `resourcez`

### Without .bazelignore:
```
Error in fail: Resource file nested/resourcez/resource.txt is not under
the specified prefix to strip resourcez
```
- Resource path: `nested/resourcez/resource.txt`
- Strip prefix: `resourcez`
- Check fails: `nested/resourcez/resource.txt` doesn't start with `resourcez`
