package io.bazel.kotlin.plugin.jdeps.k2

import io.bazel.kotlin.plugin.jdeps.BaseJdepsGenExtension
import org.jetbrains.kotlin.codegen.ClassFileFactory
import org.jetbrains.kotlin.codegen.extensions.ClassFileFactoryFinalizerExtension
import org.jetbrains.kotlin.config.CompilerConfiguration

internal class JdepsGenExtension2(
  private val classUsageRecorder: ClassUsageRecorder,
  configuration: CompilerConfiguration,
) : BaseJdepsGenExtension(configuration),
  ClassFileFactoryFinalizerExtension {
  override fun finalizeClassFactory(factory: ClassFileFactory) {
    onAnalysisCompleted(
      classUsageRecorder.explicitClassesBySource,
      classUsageRecorder.implicitClassesBySource,
    )
  }
}
