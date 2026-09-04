"""Stubs for stardoc generation."""

load(
    "//src/main/starlark/core/repositories:initialize.release.bzl",
    _kotlin_repositories = "kotlin_repositories",
    _versions = "versions",
)

kotlin_repositories = _kotlin_repositories
versions = _versions
