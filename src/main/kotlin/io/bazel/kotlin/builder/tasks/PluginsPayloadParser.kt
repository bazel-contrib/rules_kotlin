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

import com.google.protobuf.TextFormat
import io.bazel.kotlin.model.JvmCompilationTask

/**
 * Parses the `--plugins_payload` value: a `JvmCompilationTask.Inputs` message in protobuf text format with one
 * `plugins { ... }` entry per compiler plugin, as `plugin_payload.text` in payload.bzl writes it.
 * The parser is strict: an unknown field or an unknown phase name is an error, not an omission.
 */
object PluginsPayloadParser {
  @JvmStatic
  fun parse(text: String): List<JvmCompilationTask.Inputs.Plugin> {
    val inputs = JvmCompilationTask.Inputs.newBuilder()
    try {
      TextFormat.merge(text, inputs)
    } catch (e: TextFormat.ParseException) {
      throw IllegalArgumentException("invalid plugins payload: ${e.message}", e)
    }
    return inputs.pluginsList
  }
}
