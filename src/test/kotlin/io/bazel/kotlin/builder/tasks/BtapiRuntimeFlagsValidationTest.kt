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

import com.google.common.truth.Truth.assertThat
import io.bazel.kotlin.builder.toolchain.CompilationTaskContext
import io.bazel.kotlin.model.JvmCompilationTask
import io.bazel.worker.Status
import io.bazel.worker.WorkerContext
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.JUnit4
import java.nio.file.Files
import java.nio.file.Path

/**
 * Pins the none-or-everything contract of the Build Tools API runtime flags: a request with no
 * runtime flags is a legacy request, while a partial flag set is rejected rather than silently
 * treated as either kind.
 */
@RunWith(JUnit4::class)
class BtapiRuntimeFlagsValidationTest {
  private var captured: JvmCompilationTask? = null
  private val capturingExecutor =
    object : JvmTaskExecutor {
      override fun execute(
        context: CompilationTaskContext,
        task: JvmCompilationTask,
      ) {
        captured = task
      }
    }

  private fun baseArgs(root: Path): List<String> =
    listOf(
      "--target_label",
      "//some:target",
      "--classpath",
      "dummy.jar",
      "--direct_dependencies",
      "--output",
      root.resolve("out.jar").toString(),
      "--rule_kind",
      "kt_jvm_library",
      "--kotlin_module_name",
      "some_module",
      "--kotlin_api_version",
      "2.0",
      "--kotlin_language_version",
      "2.0",
      "--kotlin_jvm_target",
      "11",
      "--kotlin_debug_tags",
      "--build_kotlin",
      "false",
      "--strict_kotlin_deps",
      "off",
      "--reduced_classpath_mode",
      "off",
      "--instrument_coverage",
      "false",
      "--plugins_payload",
      """{"plugins":[]}""",
    )

  @Test
  fun `absent runtime flags mean a legacy request`() {
    val root = Files.createTempDirectory("BtapiRuntimeFlagsValidationTest")
    WorkerContext.run(named = "test") {
      doTask("legacy", sandboxDir = root) { taskContext ->
        KotlinBuilder(capturingExecutor).build(taskContext, args = baseArgs(root))
        Status.SUCCESS
      }
    }
    val task = checkNotNull(captured) { "the task never reached the executor" }
    assertThat(task.info.toolchainInfo.hasBtapi()).isFalse()
  }

  @Test
  fun `partial runtime flag set is rejected`() {
    val root = Files.createTempDirectory("BtapiRuntimeFlagsValidationTest")
    var thrown: IllegalStateException? = null
    WorkerContext.run(named = "test") {
      doTask("partial", sandboxDir = root) { taskContext ->
        try {
          KotlinBuilder(capturingExecutor).build(
            taskContext,
            args = baseArgs(root) + listOf("--btapi_impl_classpath", "impl.jar"),
          )
        } catch (e: IllegalStateException) {
          thrown = e
        }
        Status.SUCCESS
      }
    }
    val message = checkNotNull(thrown) { "a partial runtime flag set was accepted" }.message
    assertThat(message).contains("incomplete Build Tools API runtime flag set")
    assertThat(message).contains("--internal_jvm_abi_gen_classpath")
    assertThat(message).contains("--internal_jdeps_gen_classpath")
    assertThat(message).doesNotContain("--btapi_impl_classpath")
  }
}
