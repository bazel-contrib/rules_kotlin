/*
 * Copyright 2025 The Bazel Authors. All rights reserved.
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

import com.google.devtools.build.lib.view.proto.Deps
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
import java.io.BufferedInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.ObjectOutputStream
import java.io.PrintStream
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.Paths
import java.util.Base64
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
  private val classLoader: AutoCloseable? = null,
) : AutoCloseable {
  companion object {
    private const val ZIP_CRC_PROPERTY = "zip.handler.uses.crc.instead.of.timestamp"
    private const val ZIP_CRC_VALUE = "true"

    private const val JDEPS_PLUGIN_ID = "io.bazel.kotlin.plugin.jdeps.JDepsGen"
    private const val ABI_GEN_PLUGIN_ID = "org.jetbrains.kotlin.jvm.abi"
    private const val SKIP_CODE_GEN_PLUGIN_ID = "io.bazel.kotlin.plugin.SkipCodeGen"
    private const val KAPT_PLUGIN_ID = "org.jetbrains.kotlin.kapt3"

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
    classLoader?.close()
  }

  /**
   * Compiles Kotlin sources using the Build Tools API.
   *
   * @param task The compilation task protobuf containing all compilation info
   * @param plugins Internal compiler plugins (jdeps, jvm-abi-gen, etc.)
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
    // Collect sources from protobuf
    val sources =
      (task.inputs.kotlinSourcesList + task.inputs.javaSourcesList)
        .map { Path.of(it) }

    // Create BTAPI compilation operation
    val operationBuilder = toolchains.jvm.jvmCompilationOperationBuilder(sources, outputDir)
    val compilerArgs = operationBuilder.compilerArguments

    // Configure compiler arguments directly from protobuf
    configureCompilerArguments(compilerArgs, task)

    // Configure compiler plugins.
    // Prefer the typed COMPILER_PLUGINS setter (BTAPI >= 2.3.20) which avoids a
    // serialize/deserialize round-trip of already-typed arguments. For older toolchains
    // that do not expose this setter, fall back to the string-based round-trip:
    // all currently-typed args are serialized back to strings, the plugin strings are
    // appended, and the whole list is re-applied. The round-trip is necessary because
    // applyArgumentStrings() applies *all* fields from the parsed arg object (including
    // nulls), which would otherwise wipe out previously-typed settings.
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
  fun configureCompilerArguments(
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

    // Classpath - convert to absolute paths
    val classpath = computeClasspath(task).map { File(it).absolutePath }
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
   * Computes the classpath for compilation.
   * Handles reduced classpath mode when enabled.
   *
   * IMPORTANT: Friend paths (associate jars) are placed FIRST on the classpath.
   * This ensures that when the same class exists in both a friend jar and a regular dep
   * (split package scenario), the friend's version is found first. This is critical for
   * internal visibility to work correctly - the compiler must find the class from the
   * friend module to allow access to internal members.
   */
  fun computeClasspath(task: JvmCompilationTask): List<String> {
    val baseClasspath =
      when (task.info.reducedClasspathMode) {
        "KOTLINBUILDER_REDUCED" -> {
          val transitiveDepsForCompile = mutableSetOf<String>()
          task.inputs.depsArtifactsList.forEach { jdepsPath ->
            BufferedInputStream(Files.newInputStream(Paths.get(jdepsPath))).use {
              val deps = Deps.Dependencies.parseFrom(it)
              deps.dependencyList.forEach { dep ->
                if (dep.kind == Deps.Dependency.Kind.EXPLICIT) {
                  transitiveDepsForCompile.add(dep.path)
                }
              }
            }
          }
          task.inputs.directDependenciesList + transitiveDepsForCompile
        }
        else -> task.inputs.classpathList
      }

    // Put friend paths FIRST on the classpath, then the rest (excluding duplicates).
    // This ensures associate jars shadow any conflicting classes from regular deps.
    val friendPathsSet = task.info.friendPathsList.toSet()
    val classpathWithoutFriends = baseClasspath.filter { it !in friendPathsSet }

    // Add generated classes directory to classpath
    return task.info.friendPathsList + classpathWithoutFriends + task.directories.generatedClasses
  }

  /**
   * Builds compiler plugins for BTAPI using the typed CompilerPlugin API.
   */
  private fun buildCompilerPlugins(task: JvmCompilationTask): List<CompilerPlugin> {
    val result = mutableListOf<CompilerPlugin>()

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

    result.addAll(buildUserPlugins(task))
    return result
  }

  /**
   * Builds user-specified compiler plugins from protobuf options.
   */
  private fun buildUserPlugins(task: JvmCompilationTask): List<CompilerPlugin> =
    buildLegacyPlugins(
      task = task,
      pluginIds = task.inputs.compilerPluginsList,
      rawOptions = task.inputs.compilerPluginOptionsList,
      classpath = task.inputs.compilerPluginClasspathList,
    )

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

  fun toBtapiPlugin(
    task: JvmCompilationTask,
    pluginId: String,
    classpath: List<String>,
    rawOptions: List<String>,
  ): CompilerPlugin =
    CompilerPlugin(
      pluginId = pluginId,
      classpath = classpath.map { Path.of(it) },
      rawArguments =
        rawOptions.map { rawOption ->
          parseLegacyPluginOption(
            task = task,
            classpath = classpath,
            rawOption = rawOption,
          )
        },
      orderingRequirements = emptySet(),
    )

  private fun parseLegacyPluginOption(
    task: JvmCompilationTask,
    classpath: List<String>,
    rawOption: String,
  ): CompilerPluginOption {
    val separatorIndex = rawOption.indexOf("=")
    val key = if (separatorIndex >= 0) rawOption.substring(0, separatorIndex) else rawOption
    val value = if (separatorIndex >= 0) rawOption.substring(separatorIndex + 1) else ""
    return CompilerPluginOption(
      key,
      expandPluginOptionValue(task, classpath, value),
    )
  }

  private fun expandPluginOptionValue(
    task: JvmCompilationTask,
    classpath: List<String>,
    value: String,
  ): String {
    val optionTokens =
      mapOf(
        "{generatedClasses}" to task.directories.generatedClasses,
        "{stubs}" to task.directories.stubs,
        "{temp}" to task.directories.temp,
        "{generatedSources}" to task.directories.generatedSources,
        "{classpath}" to classpath.joinToString(File.pathSeparator),
      )

    return optionTokens.entries.fold(value) { expandedValue, (token, replacement) ->
      expandedValue.replace(token, replacement)
    }
  }

  // Note: All user plugins share a single merged classpath. This is by design from the Starlark
  // layer, where `plugins.compile_phase.classpath` is a depset merging all plugin classpaths.
  // BTAPI's CompilerPlugin model supports per-plugin classpath, but splitting requires Starlark changes.
  private fun buildLegacyPlugins(
    task: JvmCompilationTask,
    pluginIds: List<String>,
    rawOptions: List<String>,
    classpath: List<String>,
    includeRawOption: (String) -> Boolean = { true },
  ): List<CompilerPlugin> {
    val optionsByPluginId = linkedMapOf<String, MutableList<String>>()
    val filteredOptions = rawOptions.filter(includeRawOption)
    if (pluginIds.isEmpty()) {
      require(filteredOptions.isEmpty() && classpath.isEmpty()) {
        "Invalid compiler plugin configuration: plugin ids are required for BTAPI plugins."
      }
      return emptyList()
    }

    val orderedPluginIds =
      linkedSetOf<String>().apply {
        pluginIds.forEach { pluginId ->
          require(pluginId.isNotBlank()) {
            "Invalid compiler plugin configuration: plugin id is empty."
          }
          add(pluginId)
        }
      }

    filteredOptions.forEach { rawOption ->
      val separatorIndex = rawOption.indexOf(":")
      require(separatorIndex > 0) {
        "Invalid compiler plugin option '$rawOption'. Expected format <plugin-id>:<option>."
      }
      val pluginId = rawOption.substring(0, separatorIndex)
      val option = rawOption.substring(separatorIndex + 1)
      require(option.isNotEmpty()) {
        "Invalid compiler plugin option '$rawOption'. Empty plugin options are not supported."
      }
      require(pluginId in orderedPluginIds) {
        "Invalid compiler plugin option '$rawOption'. Plugin id '$pluginId' was not declared."
      }
      optionsByPluginId.getOrPut(pluginId) { mutableListOf() }.add(option)
    }

    require(classpath.isNotEmpty()) {
      "Invalid compiler plugin configuration: plugin classpath is empty."
    }

    return orderedPluginIds.map { pluginId ->
      require(pluginId.isNotBlank()) {
        "Invalid compiler plugin configuration: plugin id is empty."
      }
      toBtapiPlugin(
        task = task,
        pluginId = pluginId,
        classpath = classpath,
        rawOptions = optionsByPluginId[pluginId] ?: emptyList(),
      )
    }
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
   * - Stubs in directories.generatedStubClasses (canonicalized to temp/stubs by the builder)
   *
   * @param task The compilation task protobuf containing all compilation info
   * @param plugins Internal compiler plugins (must include kapt)
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
    val kaptPlugin = buildKaptCompilerPlugin(task, aptMode, verbose)
    val stubsPlugins = buildStubsPlugins(task)
    val compilerPlugins = listOf(kaptPlugin) + stubsPlugins

    val logger = createCompilerLogger(out, verbose = verbose)

    return executeCompilation(
      task = task,
      outputDir = Path.of(task.directories.generatedClasses),
      compilerPlugins = compilerPlugins,
      logger = logger,
    )
  }

  /**
   * Builds the KAPT compiler plugin using the typed CompilerPlugin API.
   */
  fun buildKaptCompilerPlugin(
    task: JvmCompilationTask,
    aptMode: String,
    verbose: Boolean,
  ): CompilerPlugin {
    // Create temp subdirectories for stubs and incremental data
    val stubsDir = task.directories.stubs
    val incrementalDataDir = task.directories.incrementalData

    val options = mutableListOf<CompilerPluginOption>()

    // Core KAPT directories
    options.add(CompilerPluginOption("sources", task.directories.generatedJavaSources))
    options.add(CompilerPluginOption("classes", task.directories.generatedClasses))
    options.add(CompilerPluginOption("stubs", stubsDir))
    options.add(CompilerPluginOption("incrementalData", incrementalDataDir))

    // Javac arguments (encoded as Base64)
    val javacArgs =
      mapOf(
        "-target" to task.info.toolchainInfo.jvm.jvmTarget,
        "-source" to task.info.toolchainInfo.jvm.jvmTarget,
      )
    options.add(CompilerPluginOption("javacArguments", encodeMapForKapt(javacArgs)))

    // Other options
    options.add(CompilerPluginOption("correctErrorTypes", "false"))
    options.add(CompilerPluginOption("verbose", verbose.toString()))
    options.add(CompilerPluginOption("aptMode", aptMode))

    // Annotation processor classpath - one option per entry
    task.inputs.processorpathsList.forEach { processorPath ->
      options.add(CompilerPluginOption("apclasspath", processorPath))
    }

    // Processors list - one option per processor
    task.inputs.processorsList.forEach { processor ->
      options.add(CompilerPluginOption("processors", processor))
    }

    // Read kapt apoptions from legacy plugin options.
    val kaptPrefix = "${KAPT_PLUGIN_ID}:apoption="
    val apOptions =
      (task.inputs.compilerPluginOptionsList + task.inputs.stubsPluginOptionsList)
        .asSequence()
        .filter { it.startsWith(kaptPrefix) }
        .map { it.substring(kaptPrefix.length).split(":", limit = 2) }
        .associate { it[0] to it[1] }

    if (apOptions.isNotEmpty()) {
      options.add(CompilerPluginOption("apoptions", encodeMapForKapt(apOptions)))
    }

    return CompilerPlugin(
      pluginId = KAPT_PLUGIN_ID,
      classpath = listOf(kaptJar),
      rawArguments = options,
      orderingRequirements = emptySet(),
    )
  }

  /**
   * Builds CompilerPlugin objects for non-KAPT stubs plugins that should run during KAPT phase.
   */
  fun buildStubsPlugins(task: JvmCompilationTask): List<CompilerPlugin> =
    buildLegacyPlugins(
      task = task,
      pluginIds = task.inputs.stubsPluginsList,
      rawOptions = task.inputs.stubsPluginOptionsList,
      classpath = task.inputs.stubsPluginClasspathList,
      includeRawOption = { !it.startsWith("${KAPT_PLUGIN_ID}:") },
    )

  /**
   * Encodes a map to Base64 in the format expected by KAPT.
   * Uses Java serialization (ObjectOutputStream) compatible with KAPT's decodeMap.
   */
  fun encodeMapForKapt(options: Map<String, String>): String {
    val os = ByteArrayOutputStream()
    ObjectOutputStream(os).use { oos ->
      oos.writeInt(options.size)
      for ((key, value) in options.entries) {
        oos.writeUTF(key)
        oos.writeUTF(value)
      }
      oos.flush()
    }
    return Base64.getEncoder().encodeToString(os.toByteArray())
  }
}

private val JvmCompilationTask.Directories.stubs: String
  get() =
    Files
      .createDirectories(
        Paths.get(generatedStubClasses),
      ).toString()

private val JvmCompilationTask.Directories.incrementalData: String
  get() =
    Files
      .createDirectories(
        Paths.get(temp).resolve("incrementalData"),
      ).toString()
