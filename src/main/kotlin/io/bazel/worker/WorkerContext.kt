/*
 * Copyright 2020 The Bazel Authors. All rights reserved.
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

package io.bazel.worker

import io.bazel.worker.ContextLog.Granularity
import io.bazel.worker.ContextLog.Granularity.INFO
import io.bazel.worker.ContextLog.ScopeLogging
import io.bazel.worker.Status.ERROR
import java.io.ByteArrayOutputStream
import java.io.Closeable
import java.io.InterruptedIOException
import java.io.PrintStream
import java.nio.file.Path
import java.util.logging.Level
import java.util.logging.Logger
import java.util.logging.SimpleFormatter
import java.util.logging.StreamHandler

/** WorkerContext encapsulates logging, filesystem, and profiling for a task invocation. */
class WorkerContext private constructor(
  private val name: String = Companion::class.java.canonicalName,
  private val verbose: Granularity = INFO,
) : Closeable,
  ScopeLogging by ContextLogger(name, verbose.level, null) {
  companion object {
    fun <T : Any?> run(
      named: String = "worker",
      verbose: Granularity = INFO,
      report: (ContextLog) -> Unit = {},
      work: WorkerContext.() -> T,
    ): T =
      WorkerContext(verbose = verbose, name = named).run {
        use(work).also {
          report(contents())
        }
      }
  }

  private class ContextLogger(
    val name: String,
    val level: Level,
    val propagateTo: ContextLogger? = null,
  ) : ScopeLogging {
    private val profiles = mutableListOf<String>()

    private val out by lazy {
      ByteArrayOutputStream()
    }

    private val handler by lazy {
      StreamHandler(out, SimpleFormatter()).also { h ->
        h.level = this.level
      }
    }

    private val logger: Logger by lazy {
      object : Logger(name, null) {}.apply {
        level = level
        propagateTo?.apply { parent = logger }
        addHandler(handler)
      }
    }

    private val sourceName by lazy {
      propagateTo?.name ?: "global"
    }

    override fun info(msg: () -> String) {
      logger.logp(Level.INFO, sourceName, name, msg)
    }

    override fun error(
      t: Throwable,
      msg: () -> String,
    ) {
      logger.logp(Level.SEVERE, sourceName, name, t, msg)
    }

    override fun error(msg: () -> String) {
      logger.logp(Level.SEVERE, sourceName, name, msg)
    }

    override fun debug(msg: () -> String) {
      logger.logp(Level.FINE, sourceName, name, msg)
    }

    override fun narrowTo(name: String): ScopeLogging = ContextLogger(name, level, this)

    override fun contents() = handler.flush().run { ContextLog(out.toByteArray(), profiles) }

    override fun asPrintStream(): PrintStream = PrintStream(out, true)
  }

  class TaskContext internal constructor(
    val directory: Path,
    logging: ScopeLogging,
  ) : ScopeLogging by logging {
    /** resultOf a status supplier that includes information collected in the Context. */
    fun resultOf(executeTaskIn: (TaskContext) -> Status): TaskResult {
      try {
        return TaskResult(
          executeTaskIn(this),
          contents(),
        )
      } catch (t: Throwable) {
        when (t.causes.lastOrNull()) {
          is InterruptedException, is InterruptedIOException -> error(t) { "ERROR: Interrupted" }
          else -> error(t) { "ERROR: unexpected exception" }
        }
        return TaskResult(
          ERROR,
          contents(),
        )
      }
    }

    private val Throwable.causes
      get(): Sequence<Throwable> {
        return cause?.let { c -> sequenceOf(c) + c.causes } ?: emptySequence()
      }
  }

  /** doTask work in a TaskContext. */
  fun doTask(
    name: String,
    sandboxDir: Path? = null,
    task: (sub: TaskContext) -> Status,
  ): TaskResult {
    info { "start task $name" }
    return if (sandboxDir != null) {
      TaskContext(sandboxDir, logging = narrowTo(name)).resultOf(task)
    } else {
      WorkingDirectoryContext
        .use {
          TaskContext(dir, logging = narrowTo(name)).resultOf(task)
        }
    }.also {
      info { "end task $name: ${it.status}" }
    }
  }

  override fun close() {
    info { "ending worker context" }
  }
}
