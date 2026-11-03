package io.bazel.kotlin.plugin.jdeps

import org.jetbrains.kotlin.compiler.plugin.AbstractCliOption
import org.jetbrains.kotlin.compiler.plugin.CliOption
import org.jetbrains.kotlin.compiler.plugin.CliOptionProcessingException
import org.jetbrains.kotlin.compiler.plugin.CommandLineProcessor
import org.jetbrains.kotlin.config.CompilerConfiguration
import org.jetbrains.kotlin.config.CompilerConfigurationKey

@OptIn(org.jetbrains.kotlin.compiler.plugin.ExperimentalCompilerApi::class)
class JdepsGenCommandLineProcessor : CommandLineProcessor {
  companion object {
    val COMPILER_PLUGIN_ID = "io.bazel.kotlin.plugin.jdeps.JDepsGen"

    val OUTPUT_OPTION: CliOption =
      CliOption(
        "output",
        "<path>",
        "Records the dependencies of each analyzed source in this file, keeping the other sources'",
        required = true,
      )
    val FULL_CLASSPATH_OPTION: CliOption =
      CliOption(
        "full_classpath",
        "<List>",
        "Full classpath used for compilation (includes all transitive dependencies and stdlib)",
        required = false,
        allowMultipleOccurrences = true,
      )
  }

  override val pluginId: String
    get() = COMPILER_PLUGIN_ID
  override val pluginOptions: Collection<AbstractCliOption>
    get() =
      listOf(
        OUTPUT_OPTION,
        FULL_CLASSPATH_OPTION,
      )

  override fun processOption(
    option: AbstractCliOption,
    value: String,
    configuration: CompilerConfiguration,
  ) {
    when (option) {
      OUTPUT_OPTION -> {
        configuration.put(JdepsGenConfigurationKeys.OUTPUT, value)
      }

      FULL_CLASSPATH_OPTION -> {
        configuration.appendList(
          JdepsGenConfigurationKeys.FULL_CLASSPATH,
          value,
        )
      }

      else -> {
        throw CliOptionProcessingException("Unknown option: ${option.optionName}")
      }
    }
  }

  override fun <T> CompilerConfiguration.appendList(
    option: CompilerConfigurationKey<List<T>>,
    value: T,
  ) {
    val paths = getList(option).toMutableList()
    paths.add(value)
    put(option, paths)
  }

  override fun <T> CompilerConfiguration.appendList(
    option: CompilerConfigurationKey<List<T>>,
    values: List<T>,
  ) {
    val paths = getList(option).toMutableList()
    paths.addAll(values)
    put(option, paths)
  }
}
