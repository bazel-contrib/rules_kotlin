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

// Assembles kotlinc compiler-plugin arguments (-Xplugin / -P) from the JvmCompilationTask
// protocol buffer. These describe kotlinc's plugin CLI contract, which every compilation path
// uses; the strings produced here are identical regardless of how the compiler is invoked.
package io.bazel.kotlin.builder.tasks.jvm

import io.bazel.kotlin.builder.toolchain.CompilationTaskContext
import io.bazel.kotlin.model.JvmCompilationTask
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.ObjectOutputStream
import java.util.Base64

internal fun JvmCompilationTask.plugins(
  options: List<String>,
  classpath: List<String>,
): CompilationArgs =
  CompilationArgs().apply {
    classpath.forEach {
      xFlag("plugin", it)
    }

    val optionTokens =
      mapOf(
        "{generatedClasses}" to directories.generatedClasses,
        "{stubs}" to directories.stubs,
        "{temp}" to directories.temp,
        "{generatedSources}" to directories.generatedSources,
        "{classpath}" to classpath.joinToString(File.pathSeparator),
      )
    options.forEach { opt ->
      val formatted =
        optionTokens.entries.fold(opt) { formatting, (token, value) ->
          formatting.replace(token, value)
        }
      flag("-P", "plugin:$formatted")
    }
  }

internal fun encodeMap(options: Map<String, String>): String {
  val os = ByteArrayOutputStream()
  val oos = ObjectOutputStream(os)

  oos.writeInt(options.size)
  for ((key, value) in options.entries) {
    oos.writeUTF(key)
    oos.writeUTF(value)
  }

  oos.flush()
  return Base64
    .getEncoder()
    .encodeToString(os.toByteArray())
}

internal fun JvmCompilationTask.kaptArgs(
  context: CompilationTaskContext,
  plugins: InternalCompilerPlugins,
  aptMode: String,
): CompilationArgs {
  // KAPT does not run javac's CLI argument parser and feeds options directly to javac.
  // Javac reads option values via each option flag's canonical primaryName. That primaryName changed from
  // "-source"/"-target" (JDK <= 11) to "--source"/"--target" (JDK >= 14).
  // Pass both spelling variants, so that javac reads whichever is canonical on the running JDK and ignores the other.
  val jvmTarget = info.toolchainInfo.jvm.jvmTarget
  val javacArgs =
    mapOf<String, String>(
      "-target" to jvmTarget,
      "--target" to jvmTarget,
      "-source" to jvmTarget,
      "--source" to jvmTarget,
    )
  return CompilationArgs().apply {
    xFlag("plugin", plugins.kapt.jarPath)

    val values =
      arrayOf(
        "sources" to listOf(directories.generatedJavaSources),
        "classes" to listOf(directories.generatedClasses),
        "stubs" to listOf(directories.stubs),
        "incrementalData" to listOf(directories.incrementalData),
        "javacArguments" to listOf(javacArgs.let(::encodeMap)),
        "correctErrorTypes" to listOf("false"),
        "verbose" to listOf(context.whenTracing { "true" } ?: "false"),
        "apclasspath" to inputs.processorpathsList,
        "aptMode" to listOf(aptMode),
      )
    repeatFlag(
      "-P",
      *values + ("processors" to inputs.processorsList),
    ) { option, value ->
      "plugin:${plugins.kapt.id}:$option=$value"
    }
    // Read kapt options from the plugin options
    val optionPrefix = plugins.kapt.id + ":apoption="
    val options =
      (inputs.compilerPluginOptionsList + inputs.stubsPluginOptionsList)
        .filter { o -> o.startsWith(optionPrefix) }
        .map { o -> o.substring(optionPrefix.length).split(":", limit = 2) }
        .map { kv -> kv[0] to listOf(kv[1]) }
        .toTypedArray()

    if (options.isNotEmpty()) {
      base64Encode("-P", *options) { enc ->
        "plugin:${plugins.kapt.id}:apoptions=$enc"
      }
    }
  }
}
