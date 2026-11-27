# Copyright 2026 The Bazel Authors. All rights reserved.
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
"""Kotlin/WasmJs rule definitions."""

load(
    "//kotlin/internal:defs.bzl",
    _KtCompilerPluginInfo = "KtCompilerPluginInfo",
    _KtJvmInfo = "KtJvmInfo",
)
load(":npm.bzl", "npm_package_entries")
load(":providers.bzl", "KtWasmJsInfo")

def _kt_wasmjs_import_impl(ctx):
    deps = ctx.attr.deps + ctx.attr.exported_deps
    return [
        KtWasmJsInfo(
            # The compile visibility follows the exported deps only.
            compile_klibs = depset([ctx.file.klib], transitive = [d[KtWasmJsInfo].compile_klibs for d in ctx.attr.exported_deps]),
            # The link visibility follows the full runtime closure, unless the target is neverlink.
            link_klibs = depset() if ctx.attr.neverlink else depset([ctx.file.klib], transitive = [d[KtWasmJsInfo].link_klibs for d in deps]),
            klib = ctx.file.klib,
            source_jar = ctx.file.source_jar,
            npm_packages = depset() if ctx.attr.neverlink else depset(
                npm_package_entries(ctx.attr.npm_packages),
                transitive = [d[KtWasmJsInfo].npm_packages for d in deps],
            ),
        ),
        _KtJvmInfo(exported_compiler_plugins = depset(ctx.attr.exported_compiler_plugins)),
        DefaultInfo(files = depset([ctx.file.klib])),
    ]

kt_wasmjs_import = rule(
    doc = "Imports a prebuilt Kotlin/WasmJs klib.",
    attrs = {
        "deps": attr.label_list(
            doc = "Dependencies of the klib. They reach the link path of the dependents transitively.",
            providers = [KtWasmJsInfo],
        ),
        "exported_compiler_plugins": attr.label_list(
            doc = "Compiler plugins that apply to the direct dependents of this target.",
            cfg = "exec",
            providers = [[_KtCompilerPluginInfo]],
        ),
        "exported_deps": attr.label_list(
            doc = """Dependencies of the klib that are also on the compiler library path of the
              direct dependents. They reach the link path of the dependents transitively.""",
            providers = [KtWasmJsInfo],
        ),
        "klib": attr.label(
            doc = "The klib. It is on the compiler library path of the direct dependents.",
            allow_single_file = True,
            mandatory = True,
        ),
        "neverlink": attr.bool(
            doc = """Whether this target is only on the compiler library path. A neverlink target,
              its runtime closure and its npm packages never reach a link. Use it for a library
              that the runtime host of the binary supplies.""",
            default = False,
        ),
        "npm_packages": attr.string_keyed_label_dict(
            doc = """Bare import specifier to npm package files, for the npm packages that the
              klib needs at runtime, as its embedded `package.json` declares. The npm packages of
              the dependencies propagate automatically.""",
            allow_files = True,
        ),
        "source_jar": attr.label(
            doc = "The sources of the klib.",
            allow_single_file = True,
        ),
    },
    implementation = _kt_wasmjs_import_impl,
    provides = [KtWasmJsInfo, _KtJvmInfo],
)
