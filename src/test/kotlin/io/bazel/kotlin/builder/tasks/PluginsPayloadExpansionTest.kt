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

/**
 * Pins the worker-side expansion of the plugins payload into the per-phase task fields: the
 * exact "id:key=value" strings (with the bare "id:key" form for value-less options), their
 * order, and the per-phase routing that the retired per-phase worker flags used to carry.
 */
@RunWith(JUnit4::class)
class PluginsPayloadExpansionTest {
  @Test
  fun expandsPayloadPluginsIntoPerPhaseTaskFields() {
    val root = Files.createTempDirectory("PluginsPayloadExpansionTest")
    var captured: JvmCompilationTask? = null
    val capturingExecutor =
      object : JvmTaskExecutor {
        override fun execute(
          context: CompilationTaskContext,
          task: JvmCompilationTask,
        ) {
          captured = task
        }
      }

    WorkerContext.run(named = "test") {
      doTask("expand", sandboxDir = root) { taskContext ->
        KotlinBuilder(capturingExecutor).build(
          taskContext,
          args =
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
              PAYLOAD,
            ),
        )
        Status.SUCCESS
      }
    }

    val inputs = checkNotNull(captured) { "the task never reached the executor" }.inputs
    assertThat(inputs.stubsPluginClasspathList)
      .containsExactly("s.jar", "b1.jar", "b2.jar")
      .inOrder()
    assertThat(inputs.stubsPluginOptionsList)
      .containsExactly("p.stubs:a=1", "p.both:flagOnly", "p.both:k=a=b")
      .inOrder()
    assertThat(inputs.compilerPluginClasspathList)
      .containsExactly("c.jar", "b1.jar", "b2.jar")
      .inOrder()
    assertThat(inputs.compilerPluginOptionsList)
      .containsExactly("p.compile:b=2", "p.compile:b=3", "p.both:flagOnly", "p.both:k=a=b")
      .inOrder()
  }

  private companion object {
    val PAYLOAD =
      """
      plugins {
        id: "p.stubs"
        classpath: "s.jar"
        options { key: "a" value: "1" }
        phases: PLUGIN_PHASE_STUBS
      }
      plugins {
        id: "p.compile"
        classpath: "c.jar"
        options { key: "b" value: "2" }
        options { key: "b" value: "3" }
        phases: PLUGIN_PHASE_COMPILE
      }
      plugins {
        id: "p.both"
        classpath: "b1.jar"
        classpath: "b2.jar"
        options { key: "flagOnly" value: "" }
        options { key: "k" value: "a=b" }
        phases: PLUGIN_PHASE_STUBS
        phases: PLUGIN_PHASE_COMPILE
      }
      """.trimIndent()
  }
}
