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

import io.bazel.kotlin.builder.tasks.jvm.createAbiJar
import io.bazel.kotlin.builder.tasks.jvm.createCoverageInstrumentedJar
import io.bazel.kotlin.builder.tasks.jvm.createGeneratedClassJar
import io.bazel.kotlin.builder.tasks.jvm.createGeneratedJavaSrcJar
import io.bazel.kotlin.builder.tasks.jvm.createGeneratedKspKotlinSrcJar
import io.bazel.kotlin.builder.tasks.jvm.createGeneratedStubJar
import io.bazel.kotlin.builder.tasks.jvm.createOutputJar
import io.bazel.kotlin.builder.tasks.jvm.createdGeneratedKspClassesJar
import io.bazel.kotlin.builder.tasks.jvm.preProcessingSteps
import io.bazel.kotlin.builder.toolchain.CompilationStatusException
import io.bazel.kotlin.builder.toolchain.CompilationTaskContext
import io.bazel.kotlin.builder.toolchain.ToolchainSpec
import io.bazel.kotlin.model.JvmCompilationTask
import org.jetbrains.kotlin.buildtools.api.CompilationResult

class KotlinBtapiJvmTaskExecutor(
  private val compilerCache: BtapiCompilerCache = BtapiCompilerCache(),
) : AutoCloseable {
  override fun close() {
    compilerCache.close()
  }

  fun execute(
    context: CompilationTaskContext,
    task: JvmCompilationTask,
    toolchainSpec: ToolchainSpec,
  ) {
    val btapiCompiler = compilerCache[toolchainSpec]
    val preprocessedTask =
      task
        .preProcessingSteps(context)
        .runPluginsBtapi(context, btapiCompiler)

    context.execute("compile classes") {
      preprocessedTask.apply {
        if (compileKotlin && inputs.kotlinSourcesList.isNotEmpty()) {
          val (result, lines) =
            context.execute("kotlinc") {
              captureBtapiOutput { output ->
                btapiCompiler.compile(
                  this,
                  output,
                  verbose = context.whenTracing { true } == true,
                )
              }
            }

          if (lines.isNotEmpty()) {
            context.printCompilerOutput(lines)
          }

          when (result) {
            CompilationResult.COMPILATION_SUCCESS -> Unit
            CompilationResult.COMPILATION_ERROR ->
              throw CompilationStatusException("Compilation failed", 1, lines)
            CompilationResult.COMPILATION_OOM_ERROR ->
              throw CompilationStatusException("Compilation failed with OOM", 3, lines)
            CompilationResult.COMPILER_INTERNAL_ERROR ->
              throw CompilationStatusException("Compiler internal error", 2, lines)
          }
        }

        context.execute("ensure jdeps") { ensureBtapiJdepsExists() }

        if (outputs.jar.isNotEmpty()) {
          if (instrumentCoverage) {
            context.execute("create instrumented jar", ::createCoverageInstrumentedJar)
          } else {
            context.execute("create jar", ::createOutputJar)
          }
        }
        if (outputs.abijar.isNotEmpty()) {
          context.execute("create abi jar", ::createAbiJar)
        }
        if (outputs.generatedJavaSrcJar.isNotEmpty()) {
          context.execute("creating KAPT generated Java source jar", ::createGeneratedJavaSrcJar)
        }
        if (outputs.generatedJavaStubJar.isNotEmpty()) {
          context.execute("creating KAPT generated Kotlin stubs jar", ::createGeneratedStubJar)
        }
        if (outputs.generatedClassJar.isNotEmpty()) {
          context.execute("creating KAPT generated stub class jar", ::createGeneratedClassJar)
        }
        if (outputs.generatedKspSrcJar.isNotEmpty()) {
          context.execute("creating KSP generated src jar", ::createGeneratedKspKotlinSrcJar)
        }
        if (outputs.generatedKspClassesJar.isNotEmpty()) {
          context.execute("creating KSP generated classes jar", ::createdGeneratedKspClassesJar)
        }
      }
    }
  }
}
