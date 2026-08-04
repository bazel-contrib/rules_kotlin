"""Public ktlint rules."""

load("//kotlin/internal/lint:ktlint_config.bzl", _ktlint_config = "ktlint_config")
load("//kotlin/internal/lint:ktlint_fix.bzl", _ktlint_fix = "ktlint_fix")
load("//kotlin/internal/lint:ktlint_test.bzl", _ktlint_test = "ktlint_test")

ktlint_fix = _ktlint_fix
ktlint_test = _ktlint_test
ktlint_config = _ktlint_config
