# Copyright 2018 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""This file contains the Kotlin compiler repository definitions."""

load(
    "@bazel_tools//tools/build_defs/repo:http.bzl",
    "http_file",
)
load(":compiler.bzl", "kotlin_compiler_repository")
load(":ksp.bzl", "ksp_compiler_plugin_repository")
load(":versions.bzl", "version", _versions = "versions")

versions = _versions

# Keep these names in sync with //kotlin/internal:defs.bzl.
_KT_COMPILER_REPO = "com_github_jetbrains_kotlin"
_KSP_COMPILER_PLUGIN_REPO = "com_github_google_ksp"

def kotlin_repositories(
        compiler_repository_name = _KT_COMPILER_REPO,
        ksp_repository_name = _KSP_COMPILER_PLUGIN_REPO,
        compiler_release = versions.KOTLIN_CURRENT_COMPILER_RELEASE,
        ksp_compiler_release = versions.KSP_CURRENT_COMPILER_PLUGIN_RELEASE):
    """Sets up the Kotlin compiler and KSP repositories used by rules_kotlin.

    Args:
        compiler_repository_name: for the kotlinc compiler repository.
        compiler_release: version provider from versions.bzl.
        ksp_compiler_release: (internal) version provider from versions.bzl.
    """

    kotlin_compiler_repository(
        name = compiler_repository_name,
        urls = [url.format(version = compiler_release.version) for url in compiler_release.url_templates],
        sha256 = compiler_release.sha256,
        compiler_version = compiler_release.version,
    )

    ksp_compiler_plugin_repository(
        name = ksp_repository_name,
        urls = [url.format(version = ksp_compiler_release.version) for url in ksp_compiler_release.url_templates],
        sha256 = ksp_compiler_release.sha256,
        strip_version = ksp_compiler_release.version,
    )

    versions.use_repository(
        http_file,
        name = "com_github_pinterest_ktlint",
        version = versions.PINTEREST_KTLINT,
        downloaded_file_path = "ktlint.jar",
    )

    versions.use_repository(
        http_file,
        name = "kotlinx_serialization_core_jvm",
        version = versions.KOTLINX_SERIALIZATION_CORE_JVM,
    )

    versions.use_repository(
        http_file,
        name = "kotlinx_serialization_json",
        version = versions.KOTLINX_SERIALIZATION_JSON,
    )

    versions.use_repository(
        http_file,
        name = "kotlinx_serialization_json_jvm",
        version = versions.KOTLINX_SERIALIZATION_JSON_JVM,
    )

    versions.use_repository(
        http_file,
        name = "kotlinx_coroutines_core_jvm",
        version = versions.KOTLINX_COROUTINES_CORE_JVM,
    )

    versions.use_repository(
        http_file,
        name = "kotlin_build_tools_impl",
        version = versions.KOTLIN_BUILD_TOOLS_IMPL,
    )

def kotlinc_version(release, sha256):
    return version(
        version = release,
        url_templates = [
            "https://github.com/JetBrains/kotlin/releases/download/v{version}/kotlin-compiler-{version}.zip",
        ],
        sha256 = sha256,
    )

def ksp_version(release, sha256):
    return version(
        version = release,
        url_templates = [
            "https://github.com/google/ksp/releases/download/{version}/artifacts.zip",
        ],
        sha256 = sha256,
    )
