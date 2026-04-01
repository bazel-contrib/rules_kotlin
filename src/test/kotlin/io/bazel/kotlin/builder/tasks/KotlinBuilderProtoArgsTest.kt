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
import io.bazel.kotlin.builder.KotlinAbstractTestBuilder
import io.bazel.kotlin.builder.Deps.Dep
import io.bazel.kotlin.builder.tasks.KotlinBuilder.Companion.KotlinBuilderFlags
import io.bazel.kotlin.builder.tasks.jvm.KotlinJvmTaskExecutor
import io.bazel.kotlin.builder.tasks.jvm.btapi.KotlinBtapiJvmTaskExecutor
import io.bazel.kotlin.builder.toolchain.KotlinToolchain
import io.bazel.kotlin.builder.utils.ArgMap
import io.bazel.kotlin.builder.utils.ArgMaps
import io.bazel.kotlin.model.CompilationTaskInfo
import io.bazel.kotlin.model.JvmCompilationTask
import io.bazel.worker.Status
import io.bazel.worker.WorkerContext
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.JUnit4
import java.nio.file.Files
import java.nio.file.Path

@RunWith(JUnit4::class)
class KotlinBuilderProtoArgsTest {
  private val builder =
    KotlinBuilder(
      KotlinJvmTaskExecutor(
        KotlinToolchain.KotlincInvokerBuilder(KotlinAbstractTestBuilder.toolchainForTest()),
        KotlinAbstractTestBuilder.internalPluginsForTest(),
      ),
      KotlinBtapiJvmTaskExecutor(),
    )

  private val kotlinStdlib = dep("//kotlin/compiler:kotlin-stdlib")
  private val kotlinReflect = dep("//kotlin/compiler:kotlin-reflect")
  private val kotlinCoroutines = dep("//kotlin/compiler:kotlinx-coroutines-core-jvm")
  private val annotations = dep("//kotlin/compiler:annotations")

  private val btapiRuntimeClasspath =
    listOf(
      dep("//kotlin/compiler:kotlin-build-tools-impl"),
      dep("@rules_kotlin_maven//:org_jetbrains_kotlin_kotlin_compiler_embeddable"),
      dep("@rules_kotlin_maven//:org_jetbrains_kotlin_kotlin_daemon_client"),
      kotlinStdlib,
      kotlinReflect,
      kotlinCoroutines,
      annotations,
    )

  private val jvmAbiGen = dep("//kotlin/compiler:jvm-abi-gen")
  private val skipCodeGen = dep("//src/main/kotlin:skip-code-gen")
  private val kaptEmbeddable =
    dep("@rules_kotlin_maven//:org_jetbrains_kotlin_kotlin_annotation_processing_embeddable")
  private val jdepsGen = dep("//src/main/kotlin:jdeps-gen")

  @Test
  fun `worker-style request maps explicit plugin ids to compiler args`() {
    val taskRoot = Files.createTempDirectory("kotlin-builder-proto-request")
    val sourcePath =
      taskRoot.resolve("src/sample/WithNoArg.kt").also {
        Files.createDirectories(it.parent)
        Files.writeString(
          it,
          """
          package sample

          @Target(AnnotationTarget.CLASS)
          annotation class NoArg

          @NoArg
          class WithNoArg(val value: String)
          """.trimIndent(),
        )
      }
    val outputJar = taskRoot.resolve("out.jar")
    val missingPluginJar = taskRoot.resolve("missing-noarg-plugin.jar").toString()
    val args =
      requestArgs(
        source = sourcePath.toString(),
        output = outputJar.toString(),
        compilerPluginId = "example.no.options",
        compilerPluginJar = missingPluginJar,
      )

    val task = buildJvmTask(args, taskRoot)
    assertThat(task.inputs.compilerPluginsList).containsExactly("example.no.options")
    assertThat(task.inputs.compilerPluginClasspathList).containsExactly(missingPluginJar)
    assertThat(task.inputs.compilerPluginOptionsList).isEmpty()

    val result =
      WorkerContext.run {
        doTask("kotlin-builder-proto-request") { taskContext ->
          if (builder.build(taskContext, args) == 0) {
            Status.SUCCESS
          } else {
            Status.ERROR
          }
        }
      }

    assertThat(result.status).isEqualTo(Status.ERROR)
    assertThat(result.log.toString()).contains("missing-noarg-plugin.jar")
  }

  private fun buildJvmTask(
    args: List<String>,
    workingDir: Path,
  ): JvmCompilationTask {
    val argMap = ArgMaps.from(args)
    val info = builder.buildTaskInfo(argMap).build()
    return builder.buildJvmTask(info, workingDir, argMap)
  }

  private fun requestArgs(
    source: String,
    output: String,
    compilerPluginId: String,
    compilerPluginJar: String,
  ): List<String> {
    val args = mutableListOf<String>()
    args.addFlag(KotlinBuilderFlags.DEBUG, "trace")
    args.addFlag(KotlinBuilderFlags.TARGET_LABEL, "//sample:proto_test")
    args.addFlag(KotlinBuilderFlags.RULE_KIND, "kt_jvm_library")
    args.addFlag(KotlinBuilderFlags.MODULE_NAME, "proto_test")
    args.addFlag(KotlinBuilderFlags.CLASSPATH, kotlinStdlib)
    args.addFlag(KotlinBuilderFlags.DIRECT_DEPENDENCIES, kotlinStdlib)
    args.addFlag(KotlinBuilderFlags.SOURCES, source)
    args.addFlag(KotlinBuilderFlags.OUTPUT, output)
    args.addFlag(KotlinBuilderFlags.BUILD_KOTLIN, "true")
    args.addFlag(KotlinBuilderFlags.INSTRUMENT_COVERAGE, "false")
    args.addFlag(KotlinBuilderFlags.BUILD_TOOLS_API, "true")
    args.addFlag(KotlinBuilderFlags.STRICT_KOTLIN_DEPS, "off")
    args.addFlag(KotlinBuilderFlags.REDUCED_CLASSPATH_MODE, "NONE")
    args.addFlag(KotlinBuilderFlags.API_VERSION, "2.0")
    args.addFlag(KotlinBuilderFlags.LANGUAGE_VERSION, "2.0")
    args.addFlag(KotlinBuilderFlags.JVM_TARGET, "11")
    args.addFlag(KotlinBuilderFlags.COMPILER_PLUGINS, compilerPluginId)
    args.addFlag(KotlinBuilderFlags.COMPILER_PLUGIN_CLASS_PATH, compilerPluginJar)

    args.addFlag(
      KotlinBuilderFlags.BTAPI_RUNTIME_CLASSPATH,
      *btapiRuntimeClasspath.toTypedArray(),
    )

    args.addFlag(KotlinBuilderFlags.JDEPS_JAR, jdepsGen)
    args.addFlag(KotlinBuilderFlags.ABI_GEN_JAR, jvmAbiGen)
    args.addFlag(KotlinBuilderFlags.SKIP_CODE_GEN_JAR, skipCodeGen)
    args.addFlag(KotlinBuilderFlags.KAPT_JAR, kaptEmbeddable)
    return args
  }

  private fun MutableList<String>.addFlag(
    flag: KotlinBuilderFlags,
    vararg values: String,
  ) {
    add(flag.flag)
    addAll(values)
  }

  private fun dep(label: String): String = Dep.fromLabel(label).singleCompileJar()
}
