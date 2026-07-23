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

Releases contain the source tree from the tagged commit. There is no separate release workspace or
release-specific set of BUILD files. Contributors changing packaging or dependencies should verify
that the repository builds both as the root module and as a dependency, then run the example tests
and regenerate the documentation.

### Multi-repo runtime

The `rules_kotlin` runtime is comprised of multiple repositories. The end user will interact with a single repository, that repository delegates to 
versioned feature sub-repositories. Currently, the delegation is managed by using well known names (e.g. core lives in `@rules_kotlin_configured`),
a necessity while the initial repository can be named arbitrarily. Future development intends to remove this restriction.

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
  
