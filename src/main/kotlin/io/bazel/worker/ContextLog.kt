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

import java.io.PrintStream
import java.nio.charset.StandardCharsets.UTF_8
import java.util.logging.Level

/** Log encapsulates standard out and error of execution. */
data class ContextLog(
  val out: CharSequence,
) : CharSequence by out {
  constructor(bytes: ByteArray) : this(String(bytes, UTF_8))

  enum class Granularity(
    val level: Level,
  ) {
    INFO(Level.INFO),
    ERROR(Level.SEVERE),
    DEBUG(Level.FINEST),
  }

  /** Logging runtime messages lazily */
  interface Logging {
    fun debug(msg: () -> String)

    fun info(msg: () -> String)

    fun error(
      t: Throwable,
      msg: () -> String,
    )

    fun error(msg: () -> String)
  }

  /** Summarize all logs at invocation of contents. */
  internal interface Summarize {
    fun contents(): ContextLog
  }

  /** ScopeLogging runtime messages to a namespace. */
  internal interface ScopeLogging :
    Summarize,
    Logging {
    fun narrowTo(name: String): ScopeLogging

    /** asPrintStream allows direct writing for backwards compatiblity. */
    fun asPrintStream(): PrintStream
  }
}
