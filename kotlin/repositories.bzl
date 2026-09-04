"""Repository & version functions for workspace support."""

load(
    "//src/main/starlark/core/repositories:initialize.bzl",
    _kotlin_repositories = "kotlin_repositories",
    _kotlinc_version = "kotlinc_version",
    _ksp_version = "ksp_version",
    _versions = "versions",
)

kotlin_repositories = _kotlin_repositories
versions = _versions
kotlinc_version = _kotlinc_version
ksp_version = _ksp_version
