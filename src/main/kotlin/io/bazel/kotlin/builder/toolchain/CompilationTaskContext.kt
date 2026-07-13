/*
 * Copyright 2018 The Bazel Authors. All rights reserved.
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
package io.bazel.kotlin.builder.toolchain

import com.google.protobuf.MessageOrBuilder
import com.google.protobuf.TextFormat
import io.bazel.kotlin.model.CompilationTaskInfo
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.PrintStream
import java.nio.file.FileSystems

class CompilationTaskContext(
  val info: CompilationTaskInfo,
  private val out: PrintStream,
  private val executionRoot: String =
    FileSystems
      .getDefault()
      .getPath("")
      .toAbsolutePath()
      .toString() + File.separator,
) {
  private val start = System.currentTimeMillis()
  private var timings: MutableList<String>?
  private var level = -1
  private val isTracing: Boolean

  init {
    val debugging = info.debugList.toSet()
    timings = if (debugging.contains("timings")) mutableListOf() else null
    isTracing = debugging.contains("trace")
  }

  @Suppress("unused")
  fun print(msg: String) {
    out.println(msg)
  }

  /**
   * Print a list of debugging lines.
   *
   * @param header a header string
   * @param lines a list of lines to print out
   * @param prefix a prefix to add to each line
   * @param filterEmpty if empty lines should be discarded or not
   */
  fun printLines(
    header: String,
    lines: List<String>,
    prefix: String = "|  ",
    filterEmpty: Boolean = false,
  ) {
    check(header.isNotEmpty())
    out.println(if (header.endsWith(":")) header else "$header:")
    lines.forEach {
      if (it.isNotEmpty() || !filterEmpty) {
        out.println("$prefix$it")
      }
    }
    out.println()
  }

  fun <T> whenTracing(block: CompilationTaskContext.() -> T): T? =
    if (isTracing) {
      block()
    } else {
      null
    }

  /**
   * Print a proto message if debugging is enabled for the task.
   */
  fun printProto(
    header: String,
    msg: MessageOrBuilder,
  ) {
    printLines(header, TextFormat.printer().printToString(msg).split("\n"), filterEmpty = true)
  }

  /**
   * This method normalizes and reports the output from the Kotlin compiler.
   */
  fun printCompilerOutput(lines: List<String>) {
    lines.map(::trimExecutionRootPrefix).forEach(out::println)
  }

  private fun trimExecutionRootPrefix(toPrint: String): String {
    // trim off the workspace component
    return if (toPrint.startsWith(executionRoot)) {
      toPrint.replaceFirst(executionRoot, "")
    } else {
      toPrint
    }
  }

  /**
   * Execute a compilation task.
   *
   * @throws CompilationStatusException if the compiler returns a status of anything but zero.
   * @param printOnFail if this is true the output will be printed if the task fails else the caller is responsible
   *  for logging it by catching the [CompilationStatusException] exception.
   * @param compile the compilation method reporting its output to the given stream.
   */
  fun executeCompilerTask(
    compile: (PrintStream) -> Int,
    printOnFail: Boolean = true,
    printOnSuccess: Boolean = true,
  ): List<String> {
    val outputStream = ByteArrayOutputStream()
    val ps = PrintStream(outputStream)
    val result = compile(ps)
    val output =
      ByteArrayInputStream(outputStream.toByteArray())
        .bufferedReader()
        .readLines()
    if (result != 0) {
      if (printOnFail) {
        printCompilerOutput(output)
        throw CompilationStatusException("compile phase failed", result)
      }
      throw CompilationStatusException("compile phase failed", result, output)
    } else if (printOnSuccess) {
      printCompilerOutput(output)
    }
    return output
  }

  /**
   * Runs a task and records the timings.
   */
  fun <T> execute(
    name: String,
    task: () -> T,
  ): T = execute({ name }, task)

  /**
   * Runs a task and records the timings.
   */
  @Suppress("MemberVisibilityCanBePrivate")
  fun <T> execute(
    name: () -> String,
    task: () -> T,
  ): T =
    if (timings == null) {
      task()
    } else {
      pushTimedTask(name(), task)
    }

  private inline fun <T> pushTimedTask(
    name: String,
    task: () -> T,
  ): T {
    level += 1
    val previousTimings = timings
    timings = mutableListOf()
    return try {
      System.currentTimeMillis().let { start ->
        task().also {
          val stop = System.currentTimeMillis()
          previousTimings!! += "${"  ".repeat(level)} * $name: ${stop - start} ms"
          previousTimings.addAll(timings!!)
        }
      }
    } finally {
      level -= 1
      timings = previousTimings
    }
  }

  /**
   * This method should be called at the end of builder invocation.
   *
   * @param successful true if the task finished successfully.
   */
  fun finalize(successful: Boolean) {
    if (successful) {
      timings?.also {
        printLines(
          "Task timings for ${info.label} (total: ${System.currentTimeMillis() - start} ms)",
          it,
        )
      }
    }
  }
}
