/*
 * Copyright 2025 The Bazel Authors. All rights reserved.
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

import io.bazel.kotlin.builder.tasks.jvm.btapi.BtapiCompilerCache
import io.bazel.kotlin.builder.toolchain.ToolchainSpec
import io.bazel.kotlin.builder.utils.ArgMap
import io.bazel.kotlin.builder.utils.ArgMaps
import io.bazel.kotlin.builder.utils.Flag
import io.bazel.worker.Status
import io.bazel.worker.Work
import io.bazel.worker.WorkerContext
import org.jetbrains.kotlin.buildtools.api.ExperimentalBuildToolsApi
import org.jetbrains.kotlin.buildtools.api.KotlinToolchains
import org.jetbrains.kotlin.buildtools.api.jvm.ClassSnapshotGranularity
import org.jetbrains.kotlin.buildtools.api.jvm.JvmPlatformToolchain.Companion.jvm
import org.jetbrains.kotlin.buildtools.api.jvm.operations.JvmClasspathSnapshottingOperation
import org.jetbrains.kotlin.buildtools.api.jvm.operations.JvmClasspathSnapshottingOperation.Companion.PARSE_INLINED_LOCAL_CLASSES
import java.nio.charset.StandardCharsets
import java.nio.file.FileSystems
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.StandardCopyOption
import java.util.concurrent.ConcurrentHashMap
import java.util.regex.Pattern

/**
 * Worker task that generates classpath snapshots for incremental compilation.
 *
 * Each Kotlin target produces a classpath snapshot of its output JAR as a
 * declared Bazel output. These snapshots are then passed as explicit inputs
 * to downstream compilation actions for incremental compilation.
 */
@OptIn(ExperimentalBuildToolsApi::class)
class SnapshotTask : Work {
  companion object {
    private val FLAGFILE_RE = Pattern.compile("""^--flagfile=((.*)-(\d+).params)$""").toRegex()

    enum class SnapshotFlags(
      override val flag: String,
    ) : Flag {
      INPUT_JAR("--input_jar"),
      OUTPUT_SNAPSHOT("--output_snapshot"),
      BTAPI_RUNTIME_CLASSPATH("--btapi_runtime_classpath"),
      JDEPS_JAR("--jdeps_jar"),
      ABI_GEN_JAR("--abi_gen_jar"),
      SKIP_CODE_GEN_JAR("--skip_code_gen_jar"),
      KAPT_JAR("--kapt_jar"),
    }
  }

  private val compilerCache = BtapiCompilerCache()
  private val buildSessions = ConcurrentHashMap<ToolchainSpec, KotlinToolchains.BuildSession>()

  override fun invoke(
    ctx: WorkerContext.TaskContext,
    args: Iterable<String>,
  ): Status {
    val argsList = args.toList()
    check(argsList.isNotEmpty()) { "expected at least a single arg" }

    val lines =
      FLAGFILE_RE.matchEntire(argsList[0])?.groups?.get(1)?.let {
        Files.readAllLines(FileSystems.getDefault().getPath(it.value), StandardCharsets.UTF_8)
      } ?: argsList

    val argMap = ArgMaps.from(lines)

    return try {
      val inputJar = Path.of(argMap.mandatorySingle(SnapshotFlags.INPUT_JAR))
      val outputSnapshot = Path.of(argMap.mandatorySingle(SnapshotFlags.OUTPUT_SNAPSHOT))
      val toolchainSpec = buildToolchainSpec(argMap)

      generateSnapshot(inputJar, outputSnapshot, toolchainSpec)
      Status.SUCCESS
    } catch (e: Exception) {
      ctx.error(e) { "Classpath snapshot generation failed" }
      Status.ERROR
    }
  }

  private fun generateSnapshot(
    inputJar: Path,
    outputSnapshot: Path,
    toolchainSpec: ToolchainSpec,
  ) {
    val toolchains = compilerCache[toolchainSpec].toolchains
    val buildSession =
      buildSessions.computeIfAbsent(toolchainSpec) {
        toolchains.createBuildSession()
      }

    val operation = toolchains.jvm.createClasspathSnapshottingOperation(inputJar)
    operation.set(
      JvmClasspathSnapshottingOperation.GRANULARITY,
      ClassSnapshotGranularity.CLASS_MEMBER_LEVEL,
    )
    operation.set(PARSE_INLINED_LOCAL_CLASSES, true)

    val snapshot = buildSession.executeOperation(operation)

    // Write to temp file then atomically move for safety
    Files.createDirectories(outputSnapshot.parent)
    val tempFile = outputSnapshot.resolveSibling(outputSnapshot.fileName.toString() + ".tmp")
    snapshot.saveSnapshot(tempFile)
    Files.move(
      tempFile,
      outputSnapshot,
      StandardCopyOption.ATOMIC_MOVE,
      StandardCopyOption.REPLACE_EXISTING,
    )
  }

  private fun buildToolchainSpec(argMap: ArgMap): ToolchainSpec =
    ToolchainSpec(
      btapiClasspath = argMap.mandatory(SnapshotFlags.BTAPI_RUNTIME_CLASSPATH).map(Path::of),
      jdepsJar = Path.of(argMap.mandatorySingle(SnapshotFlags.JDEPS_JAR)),
      abiGenJar = Path.of(argMap.mandatorySingle(SnapshotFlags.ABI_GEN_JAR)),
      skipCodeGenJar = Path.of(argMap.mandatorySingle(SnapshotFlags.SKIP_CODE_GEN_JAR)),
      kaptJar = Path.of(argMap.mandatorySingle(SnapshotFlags.KAPT_JAR)),
    )
}
