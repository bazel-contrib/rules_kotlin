/*
 * Copyright 2020 The Bazel Authors. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 */
package io.bazel.kotlin.plugin

import com.google.common.base.Preconditions
import com.intellij.openapi.project.Project
import org.jetbrains.kotlin.analyzer.AnalysisResult
import org.jetbrains.kotlin.compiler.plugin.CompilerPluginRegistrar
import org.jetbrains.kotlin.config.CompilerConfiguration
import org.jetbrains.kotlin.container.ComponentProvider
import org.jetbrains.kotlin.context.ProjectContext
import org.jetbrains.kotlin.descriptors.ModuleDescriptor
import org.jetbrains.kotlin.psi.KtFile
import org.jetbrains.kotlin.resolve.BindingTrace
import org.jetbrains.kotlin.resolve.jvm.extensions.AnalysisHandlerExtension

/**
 *  SkipCodeGen registers an extension to skip code generation. Must be the last compiler plugin.
 */
@OptIn(
  org.jetbrains.kotlin.compiler.plugin.ExperimentalCompilerApi::class,
  org.jetbrains.kotlin.K1Deprecation::class,
)
class SkipCodeGen : CompilerPluginRegistrar() {
  override val pluginId: String = COMPILER_PLUGIN_ID

  override val supportsK2: Boolean
    get() = false

  override fun ExtensionStorage.registerExtensions(configuration: CompilerConfiguration) {
    AnalysisHandlerExtension.registerExtension(SkipCodeGen)
  }

  companion object {
    const val COMPILER_PLUGIN_ID = "io.bazel.kotlin.plugin.SkipCodeGen"
  }

  /**
   * SkipCodeGen ends the compilation
   */
  private object SkipCodeGen : AnalysisHandlerExtension {
    override fun doAnalysis(
      project: Project,
      module: ModuleDescriptor,
      projectContext: ProjectContext,
      files: Collection<KtFile>,
      bindingTrace: BindingTrace,
      componentProvider: ComponentProvider,
    ): AnalysisResult? = null

    // analysisCompleted generates the module jvm abi and requests code generation to be skipped.
    override fun analysisCompleted(
      project: Project,
      module: ModuleDescriptor,
      bindingTrace: BindingTrace,
      files: Collection<KtFile>,
    ): AnalysisResult {
      // Ensure this is the last plugin, as it will short circuit any other plugin analysisCompleted
      // calls.
      Preconditions.checkState(
        AnalysisHandlerExtension.getInstances(project).last() == this,
        "SkipCodeGen must be the last plugin: ${AnalysisHandlerExtension.getInstances(project)}",
      )
      return AnalysisResult.Companion.success(bindingTrace.bindingContext, module, false)
    }
  }
}
