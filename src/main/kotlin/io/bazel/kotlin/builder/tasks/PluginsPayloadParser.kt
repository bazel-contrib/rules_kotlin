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
package io.bazel.kotlin.builder.tasks

import com.google.protobuf.InvalidProtocolBufferException
import com.google.protobuf.util.JsonFormat
import io.bazel.kotlin.model.Plugin
import io.bazel.kotlin.model.PluginInputs
import io.bazel.kotlin.model.PluginOption
import io.bazel.kotlin.model.PluginPhase

/**
 * Decodes the `--plugins_payload` JSON wire schema into the hand-written
 * [io.bazel.kotlin.model.Plugin] model.
 *
 * The [PluginInputs] proto is used ONLY as a protobuf [JsonFormat] decoder; the parsed proto is
 * mapped onto the hand-written model so the internal model stays plugin-free.
 */
object PluginsPayloadParser {
  /**
   * Parses [json] (the `{"plugins":[...]}` payload) into a list of model [Plugin]s.
   *
   * @throws IllegalArgumentException if [json] is syntactically malformed; the wrapped
   *   [InvalidProtocolBufferException] is chained as the cause.
   */
  @JvmStatic
  fun parse(json: String): List<Plugin> {
    val builder = PluginInputs.newBuilder()
    try {
      JsonFormat.parser().ignoringUnknownFields().merge(json, builder)
    } catch (e: InvalidProtocolBufferException) {
      throw IllegalArgumentException("invalid plugins payload JSON: ${e.message}", e)
    }
    return builder.pluginsList.map { plugin ->
      Plugin
        .builder()
        .id(plugin.id)
        .classpathList(plugin.classpathList)
        .optionsList(
          plugin.optionsList.map {
            PluginOption
              .builder()
              .key(it.key)
              .value(it.value)
              .build()
          },
        ).phasesList(plugin.phasesList.map(::mapPhase))
        .build()
    }
  }

  /** Maps a proto [PluginInputs.PluginPhase] onto the model [PluginPhase] by enum-constant name. */
  private fun mapPhase(phase: PluginInputs.PluginPhase): PluginPhase =
    when (phase) {
      PluginInputs.PluginPhase.PLUGIN_PHASE_COMPILE -> PluginPhase.PLUGIN_PHASE_COMPILE

      PluginInputs.PluginPhase.PLUGIN_PHASE_STUBS -> PluginPhase.PLUGIN_PHASE_STUBS

      PluginInputs.PluginPhase.PLUGIN_PHASE_UNSPECIFIED,
      PluginInputs.PluginPhase.UNRECOGNIZED,
      -> PluginPhase.PLUGIN_PHASE_UNSPECIFIED
    }
}
