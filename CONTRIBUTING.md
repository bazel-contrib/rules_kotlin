# Contributing

Want to contribute? Great! First, read this page (including the small print at the end).

# Contribution process

Explain your idea and discuss your plan with members of the team. The best way to do this is to create an issue or comment on an existing issue.

Prepare a git commit with your change. Don't forget to add tests. Before opening a pull request, run `bazel test //src/...`, `bazel run //docs:write_docs`, and `bazel run //tools:buildifier.fix`. Update README.md if appropriate.

Create a pull request. This will start the code review process. All submissions, including submissions by project members, require review.

You may be asked to make some changes. Buildkite CI will test your change automatically on supported platforms after you open the pull request. Once everything looks good, your change will be merged.

## Formatting

Starlark files should be formatted by buildifier.
You can fix formatting issues locally with `bazel run //tools:buildifier.fix`.
We suggest using a pre-commit hook to automate this.
First [install pre-commit](https://pre-commit.com/#installation),
then run

```shell
pre-commit install
```

Otherwise, the Buildkite CI will yell at you about formatting/linting violations.

## Packaging

Build the source-only release with `bazel build //tools:rules_kotlin_release`. The archive contains
the same MODULE and BUILD files used during development; consumers compile the workers and compiler
plugins themselves. Source-only releases require Bzlmod. Packaging uses `rules_pkg` without generated release BUILD files or bundled binaries.

The example integration tests unpack this same archive and use it as a dependency. When changing
packaging, run representative examples (such as `//examples:trivial_bzlmod` and `//examples:ksp_bzlmod`)
for a single Bazel version rather than the entire expensive matrix.

### Compiler repositories and versioning

The `rules_kotlin_extensions` Bzlmod extension creates external repositories for the Kotlin compiler,
KSP, and supporting tools. The rules and worker sources live in `@rules_kotlin` itself.

The extension selects one Kotlin compiler release and one KSP release. It accepts at most one
`kotlinc_version` tag and one `ksp_version` tag across participating modules; duplicate tags are
rejected even if they specify the same version. Using multiple Kotlin compiler versions through
this extension is not currently supported.

## Idioms and Styles
TBD

### Kotlin
TBD

### Starlark
  1. New starlark should be placed under `src/main/starlark`:
      1. `core` of the `rules_kotlin` module, limited to generic structures  
      1. `<feature>` new features like `ktlint`, `android`, etc. etc. should live here.
  1. Tests. As much as possible all new starlark features should have tests. PRs that extend coverage a very welcome.
  1. Prefer toolchain to implicit dependencies on rules. Toolchains are handled lazily and offer more versatility.
  1. Avoid wrapping rule in macros. `rules_kotlin` should be considered a building block for an organization specific DSL, as such macros should be used sparingly.
  1. Restrict, then Open new rule apis. It's much better to add features based on feedback than to try and remove them. 
  
