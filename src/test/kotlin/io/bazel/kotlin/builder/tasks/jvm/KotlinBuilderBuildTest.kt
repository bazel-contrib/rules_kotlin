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
package io.bazel.kotlin.builder.tasks.jvm

import com.google.common.truth.Truth.assertThat
import io.bazel.kotlin.builder.Deps
import io.bazel.kotlin.builder.KotlinAbstractTestBuilder
import io.bazel.kotlin.builder.tasks.KotlinBuilder
import io.bazel.kotlin.builder.tasks.jvm.btapi.KotlinBtapiJvmTaskExecutor
import io.bazel.kotlin.builder.toolchain.KotlinToolchain
import io.bazel.worker.Status
import io.bazel.worker.WorkerContext
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.JUnit4
import java.nio.file.Files

@RunWith(JUnit4::class)
class KotlinBuilderBuildTest {
  @Test
  fun buildReturnsNonZeroWhenJarCreationThrowsGenericException() {
    val root = Files.createTempDirectory("KotlinBuilderBuildTest")
    // Use an existing directory as the declared output jar path so jar creation throws a generic
    // I/O exception after task setup succeeds, matching the issue's uncaught-exception path.
    val outputJarDirectory = Files.createDirectory(root.resolve("jar_output.jar"))
    var exitCode: Int? = null

    val result =
      WorkerContext.run(named = "test") {
      doTask("build", sandboxDir = root) { taskContext ->
        exitCode =
          KotlinBuilder(jvmTaskExecutor(), KotlinBtapiJvmTaskExecutor()).build(
            taskContext,
            args =
              listOf(
                "--target_label",
                "//some:target",
                "--classpath",
                Deps.Dep.fromLabel("//kotlin/compiler:kotlin-stdlib").singleCompileJar(),
                Deps.Dep.fromLabel("//kotlin/compiler:kotlin-stdlib-jdk7").singleCompileJar(),
                Deps.Dep.fromLabel("//kotlin/compiler:kotlin-stdlib-jdk8").singleCompileJar(),
                "--direct_dependencies",
                "--output",
                outputJarDirectory.toString(),
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
              ),
          )
        if (exitCode == Status.SUCCESS.exit) Status.SUCCESS else Status.ERROR
      }
    }

    assertThat(result.status).isEqualTo(Status.ERROR)
    exitCode?.let {
      assertThat(it).isNotEqualTo(Status.SUCCESS.exit)
    }
  }

  private fun jvmTaskExecutor(): KotlinJvmTaskExecutor {
    val toolchain = KotlinAbstractTestBuilder.toolchainForTest()
    return KotlinJvmTaskExecutor(
      KotlinToolchain.KotlincInvokerBuilder(toolchain),
      KotlinAbstractTestBuilder.internalPluginsForTest(),
    )
  }
}
