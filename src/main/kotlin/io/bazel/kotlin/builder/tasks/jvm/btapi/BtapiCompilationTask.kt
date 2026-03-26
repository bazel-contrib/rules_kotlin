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

import io.bazel.kotlin.builder.tasks.jvm.JDepsGenerator.emptyJdeps
import io.bazel.kotlin.builder.tasks.jvm.JDepsGenerator.writeJdeps
import io.bazel.kotlin.builder.tasks.jvm.expandWithGeneratedSources
import io.bazel.kotlin.builder.toolchain.CompilationStatusException
import io.bazel.kotlin.builder.toolchain.CompilationTaskContext
import io.bazel.kotlin.model.JvmCompilationTask
import org.jetbrains.kotlin.buildtools.api.CompilationResult
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.PrintStream
import java.nio.file.Paths
import kotlin.io.path.exists

internal fun JvmCompilationTask.runPluginsBtapi(
  context: CompilationTaskContext,
  btapiCompiler: BtapiCompiler,
): JvmCompilationTask {
  if (
    (
      inputs.processorsList.isEmpty() &&
        inputs.stubsPluginClasspathList.isEmpty()
    ) ||
    inputs.kotlinSourcesList.isEmpty()
  ) {
    return this
  }

  return context.execute("kapt") {
    val (result, lines) =
      captureBtapiOutput { output ->
        btapiCompiler.compileKapt(
          task = this,
          aptMode = "stubsAndApt",
          verbose = context.whenTracing { true } == true,
          out = output,
        )
      }

    if (lines.isNotEmpty()) {
      context.printCompilerOutput(lines)
    }

    when (result) {
      CompilationResult.COMPILATION_SUCCESS -> expandWithGeneratedSources()
      CompilationResult.COMPILATION_ERROR ->
        throw CompilationStatusException("KAPT failed", 1, lines)
      CompilationResult.COMPILATION_OOM_ERROR ->
        throw CompilationStatusException("KAPT failed with OOM", 3, lines)
      CompilationResult.COMPILER_INTERNAL_ERROR ->
        throw CompilationStatusException("KAPT compiler internal error", 2, lines)
    }
  }
}

internal fun captureBtapiOutput(
  action: (PrintStream) -> CompilationResult,
): Pair<CompilationResult, List<String>> {
  val output = ByteArrayOutputStream()
  val result = PrintStream(output).use(action)
  val lines =
    ByteArrayInputStream(output.toByteArray())
      .bufferedReader()
      .readLines()
  return result to lines
}

internal fun JvmCompilationTask.ensureBtapiJdepsExists() {
  if (outputs.jdeps.isEmpty()) {
    return
  }

  val jdepsPath = Paths.get(outputs.jdeps)
  if (!jdepsPath.exists()) {
    writeJdeps(outputs.jdeps, emptyJdeps(info.label))
  }
}
