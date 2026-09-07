package io.bazel.kotlin.plugin.jdeps

import io.bazel.kotlin.plugin.jdeps.k2.ClassUsageRecorder
import io.bazel.kotlin.plugin.jdeps.k2.JdepsFirExtensions
import io.bazel.kotlin.plugin.jdeps.k2.JdepsGenExtension2
import org.jetbrains.kotlin.codegen.extensions.ClassFileFactoryFinalizerExtension
import org.jetbrains.kotlin.compiler.plugin.CompilerPluginRegistrar
import org.jetbrains.kotlin.config.CompilerConfiguration
import org.jetbrains.kotlin.config.languageVersionSettings
import org.jetbrains.kotlin.extensions.StorageComponentContainerContributor
import org.jetbrains.kotlin.fir.extensions.FirExtensionRegistrarAdapter
import org.jetbrains.kotlin.resolve.jvm.extensions.AnalysisHandlerExtension
import java.nio.file.Paths

@OptIn(org.jetbrains.kotlin.compiler.plugin.ExperimentalCompilerApi::class)
class JdepsGenComponentRegistrar : CompilerPluginRegistrar() {
  override val pluginId: String = "io.bazel.kotlin.plugin.jdeps.JdepsGenComponentRegistrar"

  override val supportsK2: Boolean
    get() = true

  override fun ExtensionStorage.registerExtensions(configuration: CompilerConfiguration) {
    when (configuration.languageVersionSettings.languageVersion.usesK2) {
      true -> registerForK2(configuration)
      false -> registerForK1(configuration)
    }
  }

  @OptIn(org.jetbrains.kotlin.K1Deprecation::class)
  private fun ExtensionStorage.registerForK1(configuration: CompilerConfiguration) {
    // Capture all types referenced by the compiler for this module and look up the jar from which
    // they were loaded from
    val extension = JdepsGenExtension(configuration)
    AnalysisHandlerExtension.registerExtension(extension)
    StorageComponentContainerContributor.registerExtension(extension)
  }

  private fun ExtensionStorage.registerForK2(configuration: CompilerConfiguration) {
    val projectRoot = Paths.get("").toAbsolutePath().toString() + "/"
    val classUsageRecorder = ClassUsageRecorder(rootPath = projectRoot)
    JdepsGenExtension2(classUsageRecorder, configuration).run {
      FirExtensionRegistrarAdapter.registerExtension(JdepsFirExtensions(classUsageRecorder))
      ClassFileFactoryFinalizerExtension.registerExtension(this)
    }
  }
}
