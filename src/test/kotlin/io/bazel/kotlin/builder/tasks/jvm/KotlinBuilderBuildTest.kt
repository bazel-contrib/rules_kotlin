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
import io.bazel.kotlin.builder.tasks.KotlinBuilder
import io.bazel.kotlin.builder.toolchain.KotlinToolchain
import io.bazel.worker.Status
import io.bazel.worker.WorkerContext
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.JUnit4
import java.io.File
import java.nio.file.Files

@RunWith(JUnit4::class)
class KotlinBuilderBuildTest {
  @Test
  fun buildReturnsNonZeroWhenJarCreationThrowsGenericException() {
    val root = Files.createTempDirectory("KotlinBuilderBuildTest")
    // Use an existing directory as the declared output jar path so jar creation throws a generic
    // I/O exception after task setup succeeds, matching the issue's uncaught-exception path.
    val outputJarDirectory = Files.createDirectory(root.resolve("jar_output.jar"))
    var exitCode = Status.SUCCESS.exit

    WorkerContext.run(named = "test") {
      doTask("build", sandboxDir = root) { taskContext ->
        exitCode =
          KotlinBuilder(jvmTaskExecutor()).build(
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
        Status.SUCCESS
      }
    }

    assertThat(exitCode).isNotEqualTo(Status.SUCCESS.exit)
  }

  private fun jvmTaskExecutor(): KotlinJvmTaskExecutor {
    val toolchain =
      KotlinToolchain.createToolchain(
        File(Deps.Dep.fromLabel("//kotlin/compiler:kotlin-compiler").singleCompileJar()),
        File(Deps.Dep.fromLabel("//kotlin/compiler:kotlin-stdlib").singleCompileJar()),
        File(Deps.Dep.fromLabel("@rules_kotlin//kotlin/compiler:kotlin-reflect").singleCompileJar()),
        File(Deps.Dep.fromLabel("//kotlin/compiler:kotlin-daemon-client").singleCompileJar()),
        File(Deps.Dep.fromLabel("@kotlin_build_tools_impl//file").singleCompileJar()),
        File(Deps.Dep.fromLabel("@kotlin_build_tools_api//file").singleCompileJar()),
        File(
          Deps.Dep
            .fromLabel("//src/main/kotlin/io/bazel/kotlin/compiler:compiler.jar")
            .singleCompileJar(),
        ),
        File(Deps.Dep.fromLabel("//kotlin/compiler:jvm-abi-gen").singleCompileJar()),
        File(Deps.Dep.fromLabel("//src/main/kotlin:skip-code-gen").singleCompileJar()),
        File(Deps.Dep.fromLabel("//src/main/kotlin:jdeps-gen").singleCompileJar()),
        File(
          Deps.Dep
            .fromLabel("//kotlin/compiler:kotlin-annotation-processing")
            .singleCompileJar(),
        ),
        File(Deps.Dep.fromLabel("@kotlinx_serialization_core_jvm//file").singleCompileJar()),
        File(Deps.Dep.fromLabel("@kotlinx_serialization_json//file").singleCompileJar()),
        File(Deps.Dep.fromLabel("@kotlinx_serialization_json_jvm//file").singleCompileJar()),
      )
    return KotlinJvmTaskExecutor(
      toolchain,
      InternalCompilerPlugins(
        toolchain.jvmAbiGen,
        toolchain.skipCodeGen,
        toolchain.kapt3Plugin,
        toolchain.jdepsGen,
      ),
    )
  }
}
