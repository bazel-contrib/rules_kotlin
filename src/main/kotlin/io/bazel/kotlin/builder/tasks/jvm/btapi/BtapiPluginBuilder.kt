/*
 * Copyright 2026 The Bazel Authors. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package io.bazel.kotlin.builder.tasks.jvm.btapi

import io.bazel.kotlin.model.JvmCompilationTask
import org.jetbrains.kotlin.buildtools.api.arguments.CompilerPlugin
import org.jetbrains.kotlin.buildtools.api.arguments.CompilerPluginOption
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.ObjectOutputStream
import java.nio.file.Path
import java.util.Base64

class BtapiPluginBuilder(
  private val task: JvmCompilationTask,
) {
  companion object {
    private const val KAPT_PLUGIN_ID = "org.jetbrains.kotlin.kapt3"
    private const val KAPT_APOPTION_PREFIX = "$KAPT_PLUGIN_ID:apoption="
  }

  fun buildUserPlugins(): List<CompilerPlugin> =
    buildLegacyPlugins(
      pluginIds = task.inputs.compilerPluginsList,
      rawOptions = task.inputs.compilerPluginOptionsList,
      classpath = task.inputs.compilerPluginClasspathList,
    )

  fun buildKaptCompilerPlugin(
    kaptJar: Path,
    aptMode: String,
    verbose: Boolean,
  ): CompilerPlugin {
    val options = mutableListOf<CompilerPluginOption>()

    options.add(CompilerPluginOption("sources", task.directories.generatedJavaSources))
    options.add(CompilerPluginOption("classes", task.directories.generatedClasses))
    options.add(CompilerPluginOption("stubs", task.directories.stubs))
    options.add(CompilerPluginOption("incrementalData", task.directories.incrementalData))

    val javacArgs =
      mapOf(
        "-target" to task.info.toolchainInfo.jvm.jvmTarget,
        "-source" to task.info.toolchainInfo.jvm.jvmTarget,
      )
    options.add(CompilerPluginOption("javacArguments", encodeMapForKapt(javacArgs)))

    options.add(CompilerPluginOption("correctErrorTypes", "false"))
    options.add(CompilerPluginOption("verbose", verbose.toString()))
    options.add(CompilerPluginOption("aptMode", aptMode))

    task.inputs.processorpathsList.forEach { processorPath ->
      options.add(CompilerPluginOption("apclasspath", processorPath))
    }

    task.inputs.processorsList.forEach { processor ->
      options.add(CompilerPluginOption("processors", processor))
    }

    val apOptions =
      (task.inputs.compilerPluginOptionsList + task.inputs.stubsPluginOptionsList)
        .asSequence()
        .filter { it.startsWith(KAPT_APOPTION_PREFIX) }
        .map(::parseKaptApOption)
        .toMap()

    if (apOptions.isNotEmpty()) {
      options.add(CompilerPluginOption("apoptions", encodeMapForKapt(apOptions)))
    }

    return CompilerPlugin(
      pluginId = KAPT_PLUGIN_ID,
      classpath = listOf(kaptJar),
      rawArguments = options,
      orderingRequirements = emptySet(),
    )
  }

  fun buildStubsPlugins(): List<CompilerPlugin> =
    buildLegacyPlugins(
      pluginIds = task.inputs.stubsPluginsList,
      rawOptions = task.inputs.stubsPluginOptionsList,
      classpath = task.inputs.stubsPluginClasspathList,
      includeRawOption = { !it.startsWith("$KAPT_PLUGIN_ID:") },
    )

  // Note: All user plugins share a single merged classpath. This is by design from the Starlark
  // layer, where `plugins.compile_phase.classpath` is a depset merging all plugin classpaths.
  // BTAPI's CompilerPlugin model supports per-plugin classpath, but splitting requires Starlark changes.
  private fun buildLegacyPlugins(
    pluginIds: List<String>,
    rawOptions: List<String>,
    classpath: List<String>,
    includeRawOption: (String) -> Boolean = { true },
  ): List<CompilerPlugin> {
    val optionsByPluginId = linkedMapOf<String, MutableList<String>>()
    val filteredOptions = rawOptions.filter(includeRawOption)
    if (pluginIds.isEmpty()) {
      require(filteredOptions.isEmpty() && classpath.isEmpty()) {
        "Invalid compiler plugin configuration: plugin ids are required for BTAPI plugins."
      }
      return emptyList()
    }

    val orderedPluginIds =
      linkedSetOf<String>().apply {
        pluginIds.forEach { pluginId ->
          require(pluginId.isNotBlank()) {
            "Invalid compiler plugin configuration: plugin id is empty."
          }
          add(pluginId)
        }
      }

    filteredOptions.forEach { rawOption ->
      val separatorIndex = rawOption.indexOf(":")
      require(separatorIndex > 0) {
        "Invalid compiler plugin option '$rawOption'. Expected format <plugin-id>:<option>."
      }
      val pluginId = rawOption.substring(0, separatorIndex)
      val option = rawOption.substring(separatorIndex + 1)
      require(option.isNotEmpty()) {
        "Invalid compiler plugin option '$rawOption'. Empty plugin options are not supported."
      }
      require(pluginId in orderedPluginIds) {
        "Invalid compiler plugin option '$rawOption'. Plugin id '$pluginId' was not declared."
      }
      optionsByPluginId.getOrPut(pluginId) { mutableListOf() }.add(option)
    }

    require(classpath.isNotEmpty()) {
      "Invalid compiler plugin configuration: plugin classpath is empty."
    }

    return orderedPluginIds.map { pluginId ->
      CompilerPlugin(
        pluginId = pluginId,
        classpath = classpath.map(Path::of),
        rawArguments =
          (optionsByPluginId[pluginId] ?: emptyList()).map { rawOption ->
            parseLegacyPluginOption(classpath, rawOption)
          },
        orderingRequirements = emptySet(),
      )
    }
  }

  private fun parseLegacyPluginOption(
    classpath: List<String>,
    rawOption: String,
  ): CompilerPluginOption {
    val separatorIndex = rawOption.indexOf("=")
    val key = if (separatorIndex >= 0) rawOption.substring(0, separatorIndex) else rawOption
    val value = if (separatorIndex >= 0) rawOption.substring(separatorIndex + 1) else ""
    return CompilerPluginOption(
      key,
      expandPluginOptionValue(classpath, value),
    )
  }

  private fun expandPluginOptionValue(
    classpath: List<String>,
    value: String,
  ): String {
    val optionTokens =
      mapOf(
        "{generatedClasses}" to task.directories.generatedClasses,
        "{stubs}" to task.directories.stubs,
        "{temp}" to task.directories.temp,
        "{generatedSources}" to task.directories.generatedSources,
        "{classpath}" to classpath.joinToString(File.pathSeparator),
      )

    return optionTokens.entries.fold(value) { expandedValue, (token, replacement) ->
      expandedValue.replace(token, replacement)
    }
  }

  private fun parseKaptApOption(rawOption: String): Pair<String, String> {
    val value = rawOption.substring(KAPT_APOPTION_PREFIX.length)
    val separatorIndex = value.indexOf(":")
    require(separatorIndex > 0) {
      "Malformed kapt apoption '$rawOption': expected '$KAPT_PLUGIN_ID:apoption=<key>:<value>'."
    }
    return value.substring(0, separatorIndex) to value.substring(separatorIndex + 1)
  }
}

internal fun encodeMapForKapt(options: Map<String, String>): String {
  val os = ByteArrayOutputStream()
  ObjectOutputStream(os).use { oos ->
    oos.writeInt(options.size)
    for ((key, value) in options.entries) {
      oos.writeUTF(key)
      oos.writeUTF(value)
    }
    oos.flush()
  }
  return Base64.getEncoder().encodeToString(os.toByteArray())
}
