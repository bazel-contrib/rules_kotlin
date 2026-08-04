"""Utilities for resolving the ktlint editorconfig settings."""

load(":ktlint_config.bzl", "KtlintConfigInfo")

def is_experimental_rules_enabled(config):
    return config[KtlintConfigInfo].experimental_rules_enabled if config else False

def is_android_rules_enabled(config):
    return config[KtlintConfigInfo].android_rules_enabled if config else False

def get_editorconfig(config):
    return config[KtlintConfigInfo].editorconfig if config else None
