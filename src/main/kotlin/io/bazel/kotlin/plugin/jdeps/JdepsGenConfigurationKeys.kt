package io.bazel.kotlin.plugin.jdeps

import org.jetbrains.kotlin.config.CompilerConfigurationKey

object JdepsGenConfigurationKeys {
  /**
   * The file that records the dependencies of each source, see
   * [io.bazel.kotlin.builder.utils.jars.SourceDependenciesFile]. The builder writes the jdeps of
   * the target from it.
   */
  val OUTPUT: CompilerConfigurationKey<String> =
    CompilerConfigurationKey.create(JdepsGenCommandLineProcessor.OUTPUT_OPTION.description)

  /**
   * Full classpath used for compilation (includes all transitive dependencies and stdlib).
   * Used for mapping canonical filesystem paths back to original classpath paths.
   */
  val FULL_CLASSPATH: CompilerConfigurationKey<List<String>> =
    CompilerConfigurationKey.create(
      JdepsGenCommandLineProcessor.FULL_CLASSPATH_OPTION.description,
    )
}
