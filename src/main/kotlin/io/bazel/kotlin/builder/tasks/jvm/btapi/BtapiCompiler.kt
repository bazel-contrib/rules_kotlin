/*
 * Copyright 2026 The Bazel Authors. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package io.bazel.kotlin.builder.tasks.jvm.btapi

import io.bazel.kotlin.model.JvmCompilationTask
import org.jetbrains.kotlin.buildtools.api.CompilationResult
import org.jetbrains.kotlin.buildtools.api.CompilerArgumentsParseException
import org.jetbrains.kotlin.buildtools.api.ExperimentalBuildToolsApi
import org.jetbrains.kotlin.buildtools.api.KotlinLogger
import org.jetbrains.kotlin.buildtools.api.KotlinToolchains
import org.jetbrains.kotlin.buildtools.api.arguments.CommonCompilerArguments
import org.jetbrains.kotlin.buildtools.api.arguments.CompilerPlugin
import org.jetbrains.kotlin.buildtools.api.arguments.CompilerPluginOption
import org.jetbrains.kotlin.buildtools.api.arguments.ExperimentalCompilerArgument
import org.jetbrains.kotlin.buildtools.api.arguments.JvmCompilerArguments
import org.jetbrains.kotlin.buildtools.api.arguments.enums.JvmTarget
import org.jetbrains.kotlin.buildtools.api.jvm.JvmPlatformToolchain.Companion.jvm
import java.io.File
import java.io.PrintStream
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.Paths
import org.jetbrains.kotlin.buildtools.api.arguments.enums.KotlinVersion as BtapiKotlinVersion

/**
 * Compiler that uses the Kotlin Build Tools API directly from protobuf task data.
 *
 * Constructs typed BTAPI arguments directly from the JvmCompilationTask protobuf.
 */
@OptIn(ExperimentalBuildToolsApi::class)
class BtapiCompiler(
  val toolchains: KotlinToolchains,
  private val jdepsJar: Path,
  private val abiGenJar: Path,
  private val skipCodeGenJar: Path,
  private val kaptJar: Path,
) : AutoCloseable {
  companion object {
    private const val ZIP_CRC_PROPERTY = "zip.handler.uses.crc.instead.of.timestamp"
    private const val ZIP_CRC_VALUE = "true"

    private const val JDEPS_PLUGIN_ID = "io.bazel.kotlin.plugin.jdeps.JDepsGen"
    private const val ABI_GEN_PLUGIN_ID = "org.jetbrains.kotlin.jvm.abi"
    private const val SKIP_CODE_GEN_PLUGIN_ID = "io.bazel.kotlin.plugin.SkipCodeGen"

    init {
      System.setProperty(ZIP_CRC_PROPERTY, ZIP_CRC_VALUE)
    }
  }

  private val lazyBuildSession = lazy { toolchains.createBuildSession() }
  private val buildSession by lazyBuildSession

  override fun close() {
    if (lazyBuildSession.isInitialized()) {
      buildSession.close()
    }
  }

  /**
   * Compiles Kotlin sources using the Build Tools API.
   *
   * @param task The compilation task protobuf containing all compilation info
   * @return CompilationResult indicating success or failure
   */
  fun compile(
    task: JvmCompilationTask,
    out: PrintStream,
    verbose: Boolean = false,
  ): CompilationResult {
    val compilerPlugins = buildCompilerPlugins(task)
    val logger = createCompilerLogger(out, verbose = verbose)

    return executeCompilation(
      task = task,
      outputDir = Path.of(task.directories.classes),
      compilerPlugins = compilerPlugins,
      logger = logger,
    )
  }

  /**
   * Common compilation execution logic shared by compile and compileKapt.
   */
  private fun executeCompilation(
    task: JvmCompilationTask,
    outputDir: Path,
    compilerPlugins: List<CompilerPlugin>,
    logger: KotlinLogger,
  ): CompilationResult {
    val sources =
      (task.inputs.kotlinSourcesList + task.inputs.javaSourcesList)
        .map(Path::of)

    val operationBuilder = toolchains.jvm.jvmCompilationOperationBuilder(sources, outputDir)
    val compilerArgs = operationBuilder.compilerArguments

    configureCompilerArguments(compilerArgs, task)

    // Prefer the typed COMPILER_PLUGINS setter (BTAPI >= 2.3.20), which avoids a
    // serialize/deserialize round-trip of already-typed arguments. For older toolchains
    // that do not expose this setter, fall back to the string-based round-trip:
    // all currently-typed args are serialized back to strings, the plugin strings are
    // appended, and the whole list is re-applied. The round-trip is necessary because
    // applyArgumentStrings() applies all fields from the parsed arg object, including nulls,
    // which would otherwise wipe out previously-typed settings.
    //
    // TODO: Remove the string fallback path when BTAPI < 2.3.20 compat is no longer needed.
    if (compilerPlugins.isNotEmpty()) {
      if (CommonCompilerArguments.COMPILER_PLUGINS in compilerArgs) {
        compilerArgs[CommonCompilerArguments.COMPILER_PLUGINS] = compilerPlugins
      } else {
        // Fallback: string round-trip for BTAPI < 2.3.20
        try {
          val pluginArgumentStrings = BtapiPluginArguments.toArgumentStrings(compilerPlugins)
          compilerArgs.applyArgumentStrings(
            compilerArgs.build().toArgumentStrings() + pluginArgumentStrings,
          )
        } catch (e: CompilerArgumentsParseException) {
          throw IllegalArgumentException("Invalid compiler plugin arguments: ${e.message}", e)
        }
      }
    }

    // Execute the compilation
    return buildSession.executeOperation(operationBuilder.build(), logger = logger)
  }

  /**
   * Configures compiler arguments from protobuf fields via BTAPI builders.
   */
  @OptIn(ExperimentalCompilerArgument::class)
  private fun configureCompilerArguments(
    args: JvmCompilerArguments.Builder,
    task: JvmCompilationTask,
  ) {
    // Apply passthrough flags FIRST, before other settings.
    // This ensures that explicit typed settings below take precedence over passthrough flags,
    // preventing passthrough flags from accidentally clobbering required settings.
    if (task.info.passthroughFlagsList.isNotEmpty()) {
      try {
        args.applyArgumentStrings(task.info.passthroughFlagsList)
      } catch (e: CompilerArgumentsParseException) {
        throw IllegalArgumentException(
          "Invalid passthrough flag in kotlin_passthrough_flags: ${e.message}",
          e,
        )
      }
    }

    // Module name
    args[JvmCompilerArguments.MODULE_NAME] = task.info.moduleName
    args[JvmCompilerArguments.NO_STDLIB] = true
    args[JvmCompilerArguments.NO_REFLECT] = true

    // JVM target
    args[JvmCompilerArguments.JVM_TARGET] =
      requireJvmTarget(task.info.toolchainInfo.jvm.jvmTarget)

    // Language/API versions
    args[CommonCompilerArguments.API_VERSION] =
      requireKotlinVersion(
        version = task.info.toolchainInfo.common.apiVersion,
        fieldName = "kotlin_api_version",
      )
    args[CommonCompilerArguments.LANGUAGE_VERSION] =
      requireKotlinVersion(
        version = task.info.toolchainInfo.common.languageVersion,
        fieldName = "kotlin_language_version",
      )

    val classpath =
      BtapiClasspathResolver
        .computeClasspath(task)
        .map { File(it).absolutePath }
    if (classpath.isNotEmpty()) {
      args[JvmCompilerArguments.CLASSPATH] = classpath.joinToString(File.pathSeparator)
    }

    // Friend paths (for internal visibility)
    if (task.info.friendPathsList.isNotEmpty()) {
      args[JvmCompilerArguments.X_FRIEND_PATHS] =
        task.info.friendPathsList
          .map { File(it).absolutePath }
          .toTypedArray()
    }
  }

  /**
   * Builds compiler plugins for BTAPI using the typed CompilerPlugin API.
   */
  private fun buildCompilerPlugins(task: JvmCompilationTask): List<CompilerPlugin> {
    val result = mutableListOf<CompilerPlugin>()
    val pluginBuilder = BtapiPluginBuilder(task)

    if (task.outputs.jdeps.isNotEmpty()) {
      result.add(buildJdepsPlugin(task))
    }

    if (task.outputs.abijar.isNotEmpty()) {
      result.add(buildAbiGenPlugin(task))

      if (task.outputs.jar.isEmpty()) {
        result.add(
          CompilerPlugin(
            pluginId = SKIP_CODE_GEN_PLUGIN_ID,
            classpath = listOf(skipCodeGenJar),
            rawArguments = emptyList(),
            orderingRequirements = emptySet(),
          ),
        )
      }
    }

    result.addAll(pluginBuilder.buildUserPlugins())
    return result
  }

  /**
   * Builds jdeps plugin using the typed CompilerPlugin API.
   */
  private fun buildJdepsPlugin(task: JvmCompilationTask): CompilerPlugin {
    val options = mutableListOf<CompilerPluginOption>()
    options.add(CompilerPluginOption("output", task.outputs.jdeps))
    options.add(CompilerPluginOption("target_label", task.info.label))
    task.inputs.directDependenciesList.forEach {
      options.add(CompilerPluginOption("direct_dependencies", it))
    }
    task.inputs.classpathList.forEach {
      options.add(CompilerPluginOption("full_classpath", it))
    }
    options.add(CompilerPluginOption("strict_kotlin_deps", task.info.strictKotlinDeps))
    return CompilerPlugin(
      pluginId = JDEPS_PLUGIN_ID,
      classpath = listOf(jdepsJar),
      rawArguments = options,
      orderingRequirements = emptySet(),
    )
  }

  private fun buildAbiGenPlugin(task: JvmCompilationTask): CompilerPlugin {
    val options = mutableListOf<CompilerPluginOption>()
    options.add(CompilerPluginOption("outputDir", task.directories.abiClasses))
    if (task.info.treatInternalAsPrivateInAbiJar) {
      options.add(CompilerPluginOption("treatInternalAsPrivate", "true"))
    }
    if (task.info.removePrivateClassesInAbiJar) {
      options.add(CompilerPluginOption("removePrivateClasses", "true"))
    }
    if (task.info.removeDebugInfo) {
      options.add(CompilerPluginOption("removeDebugInfo", "true"))
    }
    return CompilerPlugin(
      pluginId = ABI_GEN_PLUGIN_ID,
      classpath = listOf(abiGenJar),
      rawArguments = options,
      orderingRequirements = emptySet(),
    )
  }

  /**
   * Parse JVM target string to BTAPI enum and fail fast for unsupported values.
   */
  private fun requireJvmTarget(target: String): JvmTarget {
    val normalizedTarget = normalizeJvmTarget(target.trim())
    return JvmTarget.entries.firstOrNull { it.stringValue == normalizedTarget }
      ?: throw IllegalArgumentException(
        "Unsupported kotlin_jvm_target '$target'. Supported values: " +
          JvmTarget.entries.joinToString(", ") { it.stringValue },
      )
  }

  // Bazel historically emits "8", while BTAPI uses the enum spelling "1.8".
  private fun normalizeJvmTarget(target: String): String =
    when (target) {
      "8" -> "1.8"
      else -> target
    }

  /**
   * Parse Kotlin version string to BTAPI enum and fail fast for unsupported values.
   */
  private fun requireKotlinVersion(
    version: String,
    fieldName: String,
  ): BtapiKotlinVersion =
    BtapiKotlinVersion.entries.firstOrNull { it.stringValue == version.trim() }
      ?: throw IllegalArgumentException(
        "Unsupported $fieldName '$version'. Supported values: " +
          BtapiKotlinVersion.entries.joinToString(", ") { it.stringValue },
      )

  /**
   * Creates a logger for compiler diagnostics.
   * Errors and warnings are always emitted; info/debug logs are emitted in verbose mode.
   */
  private fun createCompilerLogger(
    out: PrintStream,
    verbose: Boolean,
  ): KotlinLogger =
    object : KotlinLogger {
      override val isDebugEnabled: Boolean = verbose

      override fun error(
        msg: String,
        throwable: Throwable?,
      ) {
        out.println(msg)
        throwable?.printStackTrace(out)
      }

      override fun warn(
        msg: String,
        throwable: Throwable?,
      ) {
        out.println(msg)
        throwable?.printStackTrace(out)
      }

      override fun info(msg: String) {
        if (verbose) {
          out.println(msg)
        }
      }

      override fun debug(msg: String) {
        if (verbose) {
          out.println(msg)
        }
      }

      override fun lifecycle(msg: String) {
        if (verbose) {
          out.println(msg)
        }
      }
    }

  /**
   * Compiles Kotlin sources with KAPT (annotation processing) using the Build Tools API.
   *
   * This runs KAPT as a separate compilation phase before main compilation.
   * KAPT generates stubs and processes annotations, producing:
   * - Generated Java sources in directories.generatedJavaSources
   * - Generated classes in directories.generatedClasses
   * - Stubs in directories.temp/stubs, matching legacy {stubs} expansion
   *
   * @param task The compilation task protobuf containing all compilation info
   * @param aptMode KAPT mode: "stubsAndApt" (default), "stubs", or "apt"
   * @param verbose Whether to enable verbose KAPT output
   * @return CompilationResult indicating success or failure
   */
  fun compileKapt(
    task: JvmCompilationTask,
    aptMode: String = "stubsAndApt",
    verbose: Boolean = false,
    out: PrintStream,
  ): CompilationResult {
    val pluginBuilder = BtapiPluginBuilder(task)
    val compilerPlugins =
      listOf(
        pluginBuilder.buildKaptCompilerPlugin(
          kaptJar = kaptJar,
          aptMode = aptMode,
          verbose = verbose,
        ),
      ) + pluginBuilder.buildStubsPlugins()

    val logger = createCompilerLogger(out, verbose = verbose)

    return executeCompilation(
      task = task,
      outputDir = Path.of(task.directories.generatedClasses),
      compilerPlugins = compilerPlugins,
      logger = logger,
    )
  }
}

internal val JvmCompilationTask.Directories.stubs: String
  get() =
    Files
      .createDirectories(
        Paths.get(temp).resolve("stubs"),
      ).toString()

internal val JvmCompilationTask.Directories.incrementalData: String
  get() =
    Files
      .createDirectories(
        Paths.get(temp).resolve("incrementalData"),
      ).toString()
