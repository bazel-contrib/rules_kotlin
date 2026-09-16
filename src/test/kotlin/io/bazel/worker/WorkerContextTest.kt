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

import com.google.common.truth.Truth.assertThat
import io.bazel.worker.ContextLog.Granularity.DEBUG
import io.bazel.worker.Status.SUCCESS
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class WorkerContextTest {
  @get:Rule
  val tmp = TemporaryFolder()

  @Test
  fun sandboxDirIsUsedWhenProvided() {
    val sandboxDir = tmp.newFolder("sandbox").toPath()
    var observedDir: java.nio.file.Path? = null
    WorkerContext.run {
      doTask("sandboxed", sandboxDir = sandboxDir) { ctx ->
        observedDir = ctx.directory
        SUCCESS
      }
    }
    assertThat(observedDir).isEqualTo(sandboxDir)
  }

  @Test
  fun inputDigestsReachTheTask() {
    val digests = mapOf("a.jar" to "0a")
    var observed: Map<String, String>? = null
    WorkerContext.run {
      doTask("digests", inputDigests = digests) { ctx ->
        observed = ctx.inputDigests
        SUCCESS
      }
    }
    assertThat(observed).isEqualTo(digests)
  }

  @Test
  fun tempDirIsUsedWhenSandboxDirAbsent() {
    var observedDir: java.nio.file.Path? = null
    WorkerContext.run {
      doTask("unsandboxed") { ctx ->
        observedDir = ctx.directory
        SUCCESS
      }
    }
    assertThat(observedDir).isNotNull()
    assertThat(observedDir?.fileName?.toString()).startsWith("pwd")
  }

  @Test
  fun logging() {
    var outerLog: List<String> = emptyList()
    val result = WorkerContext.run(
      named = "logging",
      verbose = DEBUG,
      report = { log -> outerLog = log.out.split("\n").map { it.trim() } }
    ) {
      info { "outer context" }
      return@run doTask("work") { ctx ->
        ctx.info { "inner context" }
        SUCCESS
      }
    }
    assertThat(result.status).isEqualTo(SUCCESS)
    // Check for key parts separately - Windows JUL may include timestamps in output
    assertThat(result.log.toString()).contains("logging work")
    assertThat(result.log.toString()).contains("INFO: inner context")
    assertThat(outerLog).containsAtLeast(
      "INFO: outer context",
      "INFO: inner context"
    )
  }
}
