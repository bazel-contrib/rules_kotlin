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
"""Kotlin/WasmJs providers."""

KtWasmJsInfo = provider(
    doc = "Information required to compile Kotlin to Wasm/JS.",
    fields = {
        "compile_klibs": "depset(File): klibs visible on the compiler library path of *direct* dependents.",
        "klib": "File: klib of this module, or None for a target without sources.",
        "link_klibs": "depset(File): klibs that must be given to the Wasm/JS linker, propagated transitively.",
        "npm_packages": """depset(struct(specifier, label, files)): npm packages required at runtime by a
          binary linked with that library, propagated transitively along the runtime (link) closure.
          `specifier` is the bare import specifier (the npm package name), `label` the npm package
          target, and `files` its files depset (an npm package directory whose root contains a
          package.json).""",
        "source_jar": "File: sources of this module, or None.",
    },
)

KtWasmJsBinaryInfo = provider(
    doc = "Linked Kotlin/WasmJs application; binaryen-optimized when the `optimize` attribute resolves to on.",
    fields = {
        "dist_directory": """Directory: the Kotlin/WasmJs application. When wasm-opt ran (see the
          `optimize` attribute) this is the linked output with every .wasm optimized by wasm-opt
          (non-wasm files copied through), otherwise the plain KotlinLinkWasmJs output
          (`<ir_output_name>-js`).""",
        "functions_map_directory": """Directory of per-wasm-file symbol maps (wasm-opt --symbolmap),
          named `<wasm basename without extension>.txt`. None unless wasm-opt ran.""",
        "npm_packages": """dict[str, struct(specifier, label, files)]: npm packages required at runtime
          by that binary, keyed by bare import specifier, merged from the transitive runtime closure
          of the linked module (each `files` is an npm package directory whose root contains a
          package.json).""",
    },
)
