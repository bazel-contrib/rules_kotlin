/*
 * Copyright 2025 The Bazel Authors. All rights reserved.
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
package io.bazel.kotlin.compiler

import org.jetbrains.kotlin.buildtools.api.CompilationResult
import org.jetbrains.kotlin.buildtools.api.ExperimentalBuildToolsApi
import org.jetbrains.kotlin.buildtools.api.KotlinLogger
import org.jetbrains.kotlin.buildtools.api.KotlinToolchains
import org.jetbrains.kotlin.buildtools.api.getToolchain
import org.jetbrains.kotlin.buildtools.api.jvm.JvmPlatformToolchain
import org.jetbrains.kotlin.cli.common.ExitCode
import java.io.PrintStream
import java.nio.file.Paths

@Suppress("unused")
class BuildToolsAPICompiler : KotlinCompiler {
  @OptIn(ExperimentalBuildToolsApi::class)
  override fun exec(
    errStream: PrintStream,
    args: Array<String>,
    sources: Array<String>,
    destination: String,
  ): ExitCode {
    System.setProperty("zip.handler.uses.crc.instead.of.timestamp", "true")

    val kotlinToolchains = KotlinToolchains.loadImplementation(this.javaClass.classLoader!!)

    val operationBuilder =
      kotlinToolchains
        .getToolchain<JvmPlatformToolchain>()
        .jvmCompilationOperationBuilder(
          sources.map { Paths.get(it) },
          Paths.get(destination),
        )

    // Apply raw CLI arguments - this parses the args and sets all compiler options
    // TODO: we can use actual typed API after we get rid of BazelK2JVMCompiler and use BTAPI exclusively
    operationBuilder.compilerArguments.applyArgumentStrings(args.toList())

    // Execute the compilation
    val result =
      kotlinToolchains.createBuildSession().use { session ->
        session.executeOperation(
          operationBuilder.build(),
          logger = createLogger(errStream, verbose = "-verbose" in args),
        )
      }

    // BTAPI returns a different type than K2JVMCompiler (CompilationResult vs ExitCode).
    return when (result) {
      CompilationResult.COMPILATION_SUCCESS -> ExitCode.OK
      CompilationResult.COMPILATION_ERROR -> ExitCode.COMPILATION_ERROR
      CompilationResult.COMPILATION_OOM_ERROR -> ExitCode.OOM_ERROR
      CompilationResult.COMPILER_INTERNAL_ERROR -> ExitCode.INTERNAL_ERROR
    }
  }

  private fun createLogger(
    out: PrintStream,
    verbose: Boolean,
  ): KotlinLogger =
    object : KotlinLogger {
      override val isDebugEnabled: Boolean = verbose

      override fun error(
        msg: String,
        throwable: Throwable?,
      ) {
        out.println(msg)
        throwable?.printStackTrace(out)
      }

      override fun warn(
        msg: String,
        throwable: Throwable?,
      ) {
        out.println(msg)
        throwable?.printStackTrace(out)
      }

      override fun info(msg: String) {
        if (verbose) {
          out.println(msg)
        }
      }

      override fun debug(msg: String) {
        if (verbose) {
          out.println(msg)
        }
      }

      override fun lifecycle(msg: String) {
        if (verbose) {
          out.println(msg)
        }
      }
    }
}
