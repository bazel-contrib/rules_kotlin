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
package io.bazel.kotlin.builder.tasks.jvm.btapi

import com.google.devtools.build.lib.view.proto.Deps
import io.bazel.kotlin.builder.tasks.BtapiRuntime
import io.bazel.kotlin.builder.tasks.JvmTaskExecutor
import io.bazel.kotlin.builder.tasks.jvm.JDepsGenerator.emptyJdeps
import io.bazel.kotlin.builder.tasks.jvm.JDepsGenerator.writeJdeps
import io.bazel.kotlin.builder.tasks.jvm.createAbiJar
import io.bazel.kotlin.builder.tasks.jvm.createCoverageInstrumentedJar
import io.bazel.kotlin.builder.tasks.jvm.createGeneratedClassJar
import io.bazel.kotlin.builder.tasks.jvm.createGeneratedJavaSrcJar
import io.bazel.kotlin.builder.tasks.jvm.createGeneratedKspKotlinSrcJar
import io.bazel.kotlin.builder.tasks.jvm.createGeneratedStubJar
import io.bazel.kotlin.builder.tasks.jvm.createOutputJar
import io.bazel.kotlin.builder.tasks.jvm.createdGeneratedKspClassesJar
import io.bazel.kotlin.builder.tasks.jvm.encodeMap
import io.bazel.kotlin.builder.tasks.jvm.expandWithGeneratedSources
import io.bazel.kotlin.builder.tasks.jvm.incrementalData
import io.bazel.kotlin.builder.tasks.jvm.preProcessingSteps
import io.bazel.kotlin.builder.tasks.jvm.stubs
import io.bazel.kotlin.builder.tasks.toRuntime
import io.bazel.kotlin.builder.toolchain.CompilationStatusException
import io.bazel.kotlin.builder.toolchain.CompilationTaskContext
import io.bazel.kotlin.compiler.CompilationUnit
import io.bazel.kotlin.compiler.CompilerConfiguration
import io.bazel.kotlin.compiler.CompilerPluginSpec
import io.bazel.kotlin.compiler.KotlinBtapiCompiler
import io.bazel.kotlin.model.JvmCompilationTask
import io.bazel.kotlin.model.JvmCompilationTask.Inputs.PluginPhase
import java.io.BufferedInputStream
import java.io.File
import java.io.PrintStream
import java.nio.file.Paths
import java.util.concurrent.ConcurrentHashMap

// The internal compiler plugin ids; the plugin jars come from the toolchain-supplied
// Build Tools API runtime (BtapiRuntime).
private const val JVM_ABI_GEN_PLUGIN_ID = "org.jetbrains.kotlin.jvm.abi"
private const val SKIP_CODE_GEN_PLUGIN_ID = "io.bazel.kotlin.plugin.SkipCodeGen"
private const val KAPT_PLUGIN_ID = "org.jetbrains.kotlin.kapt3"
private const val JDEPS_GEN_PLUGIN_ID = "io.bazel.kotlin.plugin.jdeps.JDepsGen"

/**
 * Executes JVM compilation tasks through the typed Build Tools API path.
 */
class BtapiTaskExecutor(
  private val btapiClassLoader: ClassLoader,
) : JvmTaskExecutor {
  /** api_impl_classpath -> compiler invoker map */
  private val invokers = ConcurrentHashMap<List<String>, KotlinBtapiCompiler>()

  private data class PluginDescriptor(
    override val id: String,
    override val classpath: List<String>,
    /** Each option is a `key=value` string; option keys cannot contain `=`. */
    override val options: List<String>,
  ) : CompilerPluginSpec

  private class TaskCompilationUnit(
    override val sources: List<String>,
    override val classpath: List<String>,
    override val friendPaths: List<String>,
    override val destination: String,
  ) : CompilationUnit

  private class TaskCompilerConfiguration(
    override val moduleName: String,
    override val jvmTarget: String,
    override val apiVersion: String,
    override val languageVersion: String,
    override val passthroughArguments: List<String>,
    override val verbose: Boolean,
  ) : CompilerConfiguration

  override fun execute(
    context: CompilationTaskContext,
    task: JvmCompilationTask,
  ) {
    require(task.info.toolchainInfo.hasBtapi()) {
      "the Build Tools API compilation requires the toolchain-supplied runtime " +
        "(the --btapi_* and --internal_* worker flags)"
    }
    val btapiRuntime =
      task.info.toolchainInfo.btapi
        .toRuntime()
    val compiler = invokers.computeIfAbsent(btapiRuntime.apiImplClasspath, ::loadCompilerInvoker)
    val preprocessedTask =
      task
        .preProcessingSteps(context)
        .runKaptIfNeeded(context, compiler, btapiRuntime)

    context.execute("compile classes") {
      preprocessedTask.apply {
        val outputLines =
          try {
            context.execute("kotlinc") {
              if (compileKotlin) {
                runKotlinCompiler(context, compiler, btapiRuntime)
              } else {
                if (outputs.jdeps.isNotEmpty()) {
                  writeJdeps(outputs.jdeps, emptyJdeps(info.label))
                }
                emptyList()
              }
            } to null
          } catch (e: CompilationStatusException) {
            e.lines to e
          }

        outputLines.first.apply(context::printCompilerOutput)
        outputLines.second?.let { throw it }

        if (outputs.jar.isNotEmpty()) {
          if (instrumentCoverage) {
            context.execute("create instrumented jar", ::createCoverageInstrumentedJar)
          } else {
            context.execute("create jar", ::createOutputJar)
          }
        }
        if (outputs.abijar.isNotEmpty()) {
          context.execute("create abi jar", ::createAbiJar)
        }
        if (outputs.generatedJavaSrcJar.isNotEmpty()) {
          context.execute("creating KAPT generated Java source jar", ::createGeneratedJavaSrcJar)
        }
        if (outputs.generatedJavaStubJar.isNotEmpty()) {
          context.execute("creating KAPT generated Kotlin stubs jar", ::createGeneratedStubJar)
        }
        if (outputs.generatedClassJar.isNotEmpty()) {
          context.execute("creating KAPT generated stub class jar", ::createGeneratedClassJar)
        }
        if (outputs.generatedKspSrcJar.isNotEmpty()) {
          context.execute("creating KSP generated src jar", ::createGeneratedKspKotlinSrcJar)
        }
        if (outputs.generatedKspClassesJar.isNotEmpty()) {
          context.execute("creating KSP generated classes jar", ::createdGeneratedKspClassesJar)
        }
      }
    }
  }

  private fun loadCompilerInvoker(classpath: List<String>): KotlinBtapiCompiler {
    classpath.forEach { jar ->
      require(File(jar).isFile) { "missing Build Tools API runtime jar: $jar" }
    }
    return BtapiInvoker(btapiClassLoader, classpath.toTypedArray())
  }

  /**
   * The KAPT stubs-and-apt pre-pass, followed by re-expanding the task with the generated sources.
   */
  private fun JvmCompilationTask.runKaptIfNeeded(
    context: CompilationTaskContext,
    compiler: KotlinBtapiCompiler,
    runtime: BtapiRuntime,
  ): JvmCompilationTask {
    if (
      (inputs.processorsList.isEmpty() && inputs.stubsPluginClasspathList.isEmpty()) ||
      inputs.kotlinSourcesList.isEmpty()
    ) {
      return this
    }
    // KSP is handled externally in Starlark, only KAPT runs through the builder
    if (outputs.generatedClassJar.isNullOrEmpty()) {
      return this
    }
    return context.execute("kapt (${inputs.processorsList.joinToString(", ")})") {
      val descriptors =
        listOf(kaptPluginDescriptor(context, runtime)) +
          userPluginDescriptors(PluginPhase.PLUGIN_PHASE_STUBS, runtime)
      context
        .executeCompilerTask(
          { out ->
            // Like the legacy pre-pass, this compiles with the toolchain's base arguments only:
            // the user's pass-through flags and the friend paths belong to the main compile.
            invokeCompiler(
              context,
              compiler,
              arguments = emptyList(),
              friendPaths = emptyList(),
              sources = inputs.kotlinSourcesList + inputs.javaSourcesList,
              descriptors = descriptors,
              destination = directories.generatedClasses,
              out = out,
            )
          },
          printOnSuccess = context.whenTracing { true } == true,
        ).let { outputLines ->
          context.whenTracing {
            printLines("kapt output", outputLines)
          }
          expandWithGeneratedSources()
        }
    }
  }

  private fun JvmCompilationTask.runKotlinCompiler(
    context: CompilationTaskContext,
    compiler: KotlinBtapiCompiler,
    runtime: BtapiRuntime,
  ): List<String> {
    val descriptors = mutableListOf<PluginDescriptor>()

    if (outputs.jdeps.isNotEmpty()) {
      descriptors.add(
        PluginDescriptor(
          id = JDEPS_GEN_PLUGIN_ID,
          classpath = runtime.jdepsGenClasspath,
          options =
            listOf(
              "output=${outputs.jdeps}",
              "target_label=${info.label}",
            ) +
              inputs.directDependenciesList.map { "direct_dependencies=$it" } +
              inputs.classpathList.map { "full_classpath=$it" } +
              listOf("strict_kotlin_deps=${info.strictKotlinDeps}"),
        ),
      )
    }
    if (outputs.abijar.isNotEmpty()) {
      val abiOptions = mutableListOf("outputDir=${directories.abiClasses}")
      if (info.treatInternalAsPrivateInAbiJar) {
        abiOptions.add("treatInternalAsPrivate=true")
      }
      if (info.removePrivateClassesInAbiJar) {
        abiOptions.add("removePrivateClasses=true")
      }
      if (info.removeDebugInfo) {
        abiOptions.add("removeDebugInfo=true")
      }
      if (info.preserveDeclarationOrder) {
        abiOptions.add("preserveDeclarationOrder=true")
      }
      if (info.removeDataClassCopyIfConstructorIsPrivate) {
        abiOptions.add("removeDataClassCopyIfConstructorIsPrivate=true")
      }
      descriptors.add(
        PluginDescriptor(
          id = JVM_ABI_GEN_PLUGIN_ID,
          classpath = runtime.jvmAbiGenClasspath,
          options = abiOptions,
        ),
      )
      if (outputs.jar.isEmpty()) {
        descriptors.add(
          PluginDescriptor(
            id = SKIP_CODE_GEN_PLUGIN_ID,
            classpath = runtime.skipCodeGenClasspath,
            options = emptyList(),
          ),
        )
      }
    }
    descriptors.addAll(userPluginDescriptors(PluginPhase.PLUGIN_PHASE_COMPILE, runtime))

    context.whenTracing {
      context.printLines(
        "Kotlin Compiler plugins:\n",
        descriptors.map { "${it.id} ${it.options}" },
      )
    }
    return context.executeCompilerTask(
      { out ->
        invokeCompiler(
          context,
          compiler,
          arguments = info.passthroughFlagsList,
          friendPaths = info.friendPathsList,
          sources = inputs.javaSourcesList + inputs.kotlinSourcesList,
          descriptors = descriptors,
          destination = directories.classes,
          out = out,
        )
      },
      printOnFail = false,
    )
  }

  /**
   * The user's structured plugins for one phase, excluding kapt (which the pre-pass configures itself).
   */
  private fun JvmCompilationTask.userPluginDescriptors(
    phase: PluginPhase,
    runtime: BtapiRuntime,
  ): List<PluginDescriptor> =
    inputs.pluginsList
      .filter { phase in it.phasesList && it.id != KAPT_PLUGIN_ID }
      .map { plugin ->
        val tokens =
          mapOf(
            "{generatedClasses}" to directories.generatedClasses,
            "{stubs}" to directories.stubs,
            "{temp}" to directories.temp,
            "{generatedSources}" to directories.generatedSources,
            "{classpath}" to plugin.classpathList.joinToString(File.pathSeparator),
          )
        PluginDescriptor(
          id = plugin.id,
          classpath = plugin.classpathList,
          options =
            plugin.optionsList.map { option ->
              val value =
                tokens.entries.fold(option.value) { formatting, (token, tokenValue) ->
                  formatting.replace(token, tokenValue)
                }
              if (value.isEmpty()) option.key else "${option.key}=$value"
            },
        )
      }

  /**
   * The kapt plugin configured as a typed descriptor: the stubs-and-apt pre-pass directories,
   * the javac arguments (both spelling variants, see the legacy kaptArgs contract), the
   * processors and their classpath, and the user's kapt apOptions decoded from the structured
   * plugin options.
   */
  private fun JvmCompilationTask.kaptPluginDescriptor(
    context: CompilationTaskContext,
    runtime: BtapiRuntime,
  ): PluginDescriptor {
    val jvmTarget = info.toolchainInfo.jvm.jvmTarget
    val javacArgs =
      mapOf(
        "-target" to jvmTarget,
        "--target" to jvmTarget,
        "-source" to jvmTarget,
        "--source" to jvmTarget,
      )
    val options = mutableListOf<String>()
    options.add("sources=${directories.generatedJavaSources}")
    options.add("classes=${directories.generatedClasses}")
    options.add("stubs=${directories.stubs}")
    options.add("incrementalData=${directories.incrementalData}")
    options.add("javacArguments=${encodeMap(javacArgs)}")
    options.add("correctErrorTypes=false")
    options.add("verbose=${context.whenTracing { "true" } ?: "false"}")
    options.add("aptMode=stubsAndApt")
    inputs.processorpathsList.forEach { options.add("apclasspath=$it") }
    inputs.processorsList.forEach { options.add("processors=$it") }

    val apOptions =
      inputs.pluginsList
        .asSequence()
        .filter { it.id == KAPT_PLUGIN_ID }
        .flatMap { it.optionsList.asSequence() }
        .filter { it.key == "apoption" }
        .map { option ->
          option.value.split(":", limit = 2).let { it[0] to it.getOrElse(1) { "" } }
        }.toMap()
    if (apOptions.isNotEmpty()) {
      options.add("apoptions=${encodeMap(apOptions)}")
    }

    return PluginDescriptor(
      id = KAPT_PLUGIN_ID,
      classpath = runtime.kaptClasspath,
      options = options,
    )
  }

  private fun JvmCompilationTask.invokeCompiler(
    context: CompilationTaskContext,
    compiler: KotlinBtapiCompiler,
    arguments: List<String>,
    friendPaths: List<String>,
    sources: List<String>,
    descriptors: List<PluginDescriptor>,
    destination: String,
    out: PrintStream,
  ): Int =
    compiler.exec(
      errStream = out,
      compilationUnit =
        TaskCompilationUnit(
          sources = sources,
          classpath = computeClasspath() + directories.generatedClasses,
          friendPaths = friendPaths,
          destination = destination,
        ),
      configuration =
        TaskCompilerConfiguration(
          moduleName = info.moduleName,
          jvmTarget = info.toolchainInfo.jvm.jvmTarget,
          apiVersion = info.toolchainInfo.common.apiVersion,
          languageVersion = info.toolchainInfo.common.languageVersion,
          passthroughArguments = arguments,
          verbose = context.whenTracing { true } == true,
        ),
      plugins = descriptors,
    )

  /**
   * The compile classpath, honoring the jdeps-based reduced classpath mode. Mirrors the legacy
   * baseArgs classpath computation so both paths compile against the same entries.
   */
  private fun JvmCompilationTask.computeClasspath(): List<String> =
    when (info.reducedClasspathMode) {
      "KOTLINBUILDER_REDUCED" -> {
        val transitiveDepsForCompile = mutableSetOf<String>()
        inputs.depsArtifactsList.forEach { jdepsPath ->
          BufferedInputStream(Paths.get(jdepsPath).toFile().inputStream()).use {
            val deps = Deps.Dependencies.parseFrom(it)
            deps.dependencyList.forEach { dep ->
              if (dep.kind == Deps.Dependency.Kind.EXPLICIT) {
                transitiveDepsForCompile.add(dep.path)
              }
            }
          }
        }
        inputs.directDependenciesList + transitiveDepsForCompile
      }

      else -> {
        inputs.classpathList
      }
    }
}
