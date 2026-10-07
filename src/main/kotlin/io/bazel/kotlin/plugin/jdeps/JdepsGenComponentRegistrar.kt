package io.bazel.kotlin.plugin.jdeps

import io.bazel.kotlin.plugin.jdeps.k2.ClassUsageRecorder
import io.bazel.kotlin.plugin.jdeps.k2.JdepsFirExtensions
import io.bazel.kotlin.plugin.jdeps.k2.JdepsGenExtension2
import org.jetbrains.kotlin.codegen.extensions.ClassFileFactoryFinalizerExtension
import org.jetbrains.kotlin.compiler.plugin.CompilerPluginRegistrar
import org.jetbrains.kotlin.config.CompilerConfiguration
import org.jetbrains.kotlin.fir.extensions.FirExtensionRegistrarAdapter

@OptIn(org.jetbrains.kotlin.compiler.plugin.ExperimentalCompilerApi::class)
class JdepsGenComponentRegistrar : CompilerPluginRegistrar() {
  override val pluginId: String = "io.bazel.kotlin.plugin.jdeps.JdepsGenComponentRegistrar"

  override val supportsK2: Boolean
    get() = true

  override fun ExtensionStorage.registerExtensions(configuration: CompilerConfiguration) {
    val classUsageRecorder = ClassUsageRecorder()
    JdepsGenExtension2(classUsageRecorder, configuration).run {
      FirExtensionRegistrarAdapter.registerExtension(JdepsFirExtensions(classUsageRecorder))
      ClassFileFactoryFinalizerExtension.registerExtension(this)
    }
  }
}
