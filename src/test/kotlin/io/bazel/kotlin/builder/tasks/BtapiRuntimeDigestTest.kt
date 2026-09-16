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
import io.bazel.kotlin.builder.utils.fingerprintOf
import io.bazel.kotlin.model.JvmCompilationTask
import io.bazel.worker.Status
import io.bazel.worker.WorkerContext
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.JUnit4
import java.nio.file.Files
import java.nio.file.Path

/**
 * Pins the runtime digest: one value over the (path, digest) pairs of the implementation classpath,
 * built from the digests Bazel sent with the work request and recorded on the task's runtime. The
 * plugin classpaths are arguments of each compilation and stay out of it.
 */
@RunWith(JUnit4::class)
class BtapiRuntimeDigestTest {
  private val digests =
    mapOf(
      "impl.jar" to "d1",
      "compiler.jar" to "d2",
      "abi.jar" to "d3",
      "skip.jar" to "d4",
      "kapt.jar" to "d5",
      "jdeps.jar" to "d6",
    )

  private val classpath = listOf("impl.jar", "compiler.jar")

  private val expected get() = fingerprintOf(classpath, digests)

  @Test
  fun `the entry order is part of the digest`() {
    assertThat(fingerprintOf(classpath.reversed(), digests)).isNotEqualTo(expected)
  }

  @Test
  fun `a digest that ends where the next path starts does not collide`() {
    // Without a terminator after each digest both sequences would concatenate to a\0d1b\0d2.
    val first = fingerprintOf(listOf("a", "b"), mapOf("a" to "d1", "b" to "d2"))
    val second = fingerprintOf(listOf("a", "1b"), mapOf("a" to "d", "1b" to "d2"))
    assertThat(first).isNotEqualTo(second)
  }

  @Test
  fun `no request digests give an empty digest`() {
    assertThat(fingerprintOf(classpath, emptyMap())).isEmpty()
  }

  @Test
  fun `an entry without a request digest fails`() {
    var thrown: IllegalStateException? = null
    try {
      fingerprintOf(classpath, digests - "compiler.jar")
    } catch (e: IllegalStateException) {
      thrown = e
    }
    assertThat(checkNotNull(thrown) { "a missing entry was accepted" }.message)
      .contains("compiler.jar")
  }

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

  private fun runtimeArgs(root: Path): List<String> =
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
      "--btapi_impl_classpath",
      "impl.jar",
      "compiler.jar",
      "--internal_jvm_abi_gen_classpath",
      "abi.jar",
      "--internal_skip_code_gen_classpath",
      "skip.jar",
      "--internal_kapt_classpath",
      "kapt.jar",
      "--internal_jdeps_gen_classpath",
      "jdeps.jar",
    )

  private fun buildWith(inputDigests: Map<String, String>): JvmCompilationTask {
    val root = Files.createTempDirectory("BtapiRuntimeDigestTest")
    captured = null
    WorkerContext.run(named = "test") {
      doTask("build", sandboxDir = root, inputDigests = inputDigests) { taskContext ->
        KotlinBuilder(capturingExecutor).build(taskContext, args = runtimeArgs(root))
        Status.SUCCESS
      }
    }
    return checkNotNull(captured) { "the task never reached the executor" }
  }

  @Test
  fun `the request digests give the task its runtime digest`() {
    val btapi = buildWith(digests).info.toolchainInfo.btapi
    assertThat(btapi.classpathFingerprint).isEqualTo(expected)
    assertThat(btapi.toRuntime().classpathFingerprint).isEqualTo(expected)
  }

  @Test
  fun `a plugin entry digest does not change the runtime digest`() {
    val btapi = buildWith(digests + ("kapt.jar" to "d5-renewed")).info.toolchainInfo.btapi
    assertThat(btapi.classpathFingerprint).isEqualTo(expected)
  }

  @Test
  fun `a request without input digests leaves the runtime digest empty`() {
    val btapi = buildWith(emptyMap()).info.toolchainInfo.btapi
    assertThat(btapi.classpathFingerprint).isEmpty()
    assertThat(btapi.toRuntime().classpathFingerprint).isEmpty()
  }
}
