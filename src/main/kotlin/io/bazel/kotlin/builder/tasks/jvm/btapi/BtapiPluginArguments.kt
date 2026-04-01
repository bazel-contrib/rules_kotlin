/*
 * Copyright 2026 The Bazel Authors. All rights reserved.
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
package io.bazel.kotlin.builder.tasks.jvm.btapi

import org.jetbrains.kotlin.buildtools.api.arguments.CompilerPlugin
import org.jetbrains.kotlin.buildtools.api.arguments.CompilerPluginPartialOrderRelation
import kotlin.io.path.absolutePathString

/**
 * Converts typed BTAPI [CompilerPlugin] declarations into raw argument strings.
 *
 * Matches kotlin-build-tools-impl plugin argument formatting so the resulting
 * arguments can be applied with [org.jetbrains.kotlin.buildtools.api.arguments.CommonToolArguments.applyArgumentStrings].
 */
object BtapiPluginArguments {
  private const val RAW_PLUGIN_ID = "___RAW_PLUGINS_APPLIED___"

  fun toArgumentStrings(plugins: List<CompilerPlugin>): List<String> {
    val filteredPlugins = plugins.filter { it.pluginId != RAW_PLUGIN_ID }
    validatePluginsConfiguration(filteredPlugins)

    val pluginClasspaths =
      filteredPlugins
        .flatMap { it.classpath }
        .map { it.absolutePathString() }
    val pluginOptions =
      filteredPlugins.flatMap { plugin ->
        plugin.rawArguments.map { option ->
          if (option.value.isEmpty()) {
            "plugin:${plugin.pluginId}:${option.key}"
          } else {
            "plugin:${plugin.pluginId}:${option.key}=${option.value}"
          }
        }
      }
    val pluginOrderConstraints =
      filteredPlugins
        .flatMap { plugin ->
          plugin.orderingRequirements.map { ordering ->
            when (ordering.relation) {
              CompilerPluginPartialOrderRelation.BEFORE ->
                "${plugin.pluginId}>${ordering.otherPluginId}"
              CompilerPluginPartialOrderRelation.AFTER ->
                "${ordering.otherPluginId}>${plugin.pluginId}"
            }
          }
        }.toSet()
        .sorted()

    return buildList {
      if (pluginClasspaths.isNotEmpty()) {
        add("-Xplugin=${pluginClasspaths.joinToString(",")}")
      }
      if (pluginOptions.isNotEmpty()) {
        add("-P")
        add(pluginOptions.joinToString(","))
      }
      if (pluginOrderConstraints.isNotEmpty()) {
        add("-Xcompiler-plugin-order=${pluginOrderConstraints.joinToString(",")}")
      }
    }
  }

  private fun validatePluginsConfiguration(plugins: List<CompilerPlugin>) {
    for (plugin in plugins) {
      if (plugin.pluginId.isBlank()) {
        throw IllegalStateException(
          "Invalid compiler plugin configuration: plugin id is empty.",
        )
      }

      if (plugin.orderingRequirements.any { it.otherPluginId.isBlank() }) {
        throw IllegalStateException(
          "Invalid compiler plugin configuration: plugin id is empty " +
            "in the ordering requirements for plugin '${plugin.pluginId}'.",
        )
      }

      if (plugin.classpath.isEmpty()) {
        throw IllegalStateException(
          "Invalid compiler plugin configuration: plugin '${plugin.pluginId}' has empty classpath.",
        )
      }
    }
  }
}
