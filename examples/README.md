# Examples

These are series of code samples useful for configuring a variety of use cases. They also serve as integration tests.

## Prebuilt protoc

Each example module depends on Protobuf 33.4 or later and enables its prebuilt
`protoc` toolchain in `.bazelrc`, avoiding the compiler's C++ build.

The upstream prebuilt toolchain requires Bzlmod. Examples that also support
legacy WORKSPACE builds keep their shared settings in `.bazelrc.common`.
To run those builds with Bazel 7 or 8, bypass the default rc file:

```sh
bazel --noworkspace_rc --bazelrc=.bazelrc.common build --enable_bzlmod=false --enable_workspace=true //...
```

The integration runner selects this configuration for WORKSPACE tests.

## Adding a new integration test
1. Create a new workspace in the `examples` directory
1. Ensure that the `rules_kotlin` repository is named `rules_kotlin`
1. If the example will not work on a bazel version, add an `exclude` directory with a file of that version. See examples/multiplex/exclude.
1. Update the bazel excluded packages via `bazel run @rules_bazel_integration_test//tools:update_deleted_packages`
