/*
 * Copyright 2020 The Bazel Authors. All rights reserved.
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

// Provides extensions assembling the legacy (K2JVMCompiler-style) command line for the
// JvmCompilationTask protocol buffer. The compiler-agnostic task helpers (source expansion,
// output jar packaging) live in TaskArtifacts.kt.
package io.bazel.kotlin.builder.tasks.jvm

import com.google.devtools.build.lib.view.proto.Deps
import io.bazel.kotlin.builder.tasks.jvm.JDepsGenerator.emptyJdeps
import io.bazel.kotlin.builder.tasks.jvm.JDepsGenerator.writeJdeps
import io.bazel.kotlin.builder.toolchain.CompilationTaskContext
import io.bazel.kotlin.builder.toolchain.KotlinToolchain
import io.bazel.kotlin.model.JvmCompilationTask
import java.io.BufferedInputStream
import java.io.File
import java.nio.file.Files.isDirectory
import java.nio.file.Files.walk
import java.nio.file.Path
import java.nio.file.Paths
import java.util.stream.Collectors.toList
import java.util.stream.Stream

private const val API_VERSION_ARG = "-api-version"
private const val LANGUAGE_VERSION_ARG = "-language-version"

fun JvmCompilationTask.codeGenArgs(): CompilationArgs =
  CompilationArgs()
    .absolutePaths(info.friendPathsList) {
      "-Xfriend-paths=${it.joinToString(X_FRIENDS_PATH_SEPARATOR)}"
    }.values(info.passthroughFlagsList)

fun JvmCompilationTask.baseArgs(): CompilationArgs {
  val classpath =
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
    } as List<String>

  return CompilationArgs()
    .flag("-cp")
    .paths(
      classpath + directories.generatedClasses,
    ) {
      it
        .map(Path::toString)
        .joinToString(File.pathSeparator)
    }.flag(API_VERSION_ARG, info.toolchainInfo.common.apiVersion)
    .flag(
      LANGUAGE_VERSION_ARG,
      info.toolchainInfo.common.languageVersion,
    ).flag("-jvm-target", info.toolchainInfo.jvm.jvmTarget)
    .flag("-module-name", info.moduleName)
}

internal fun JvmCompilationTask.runPlugins(
  context: CompilationTaskContext,
  plugins: InternalCompilerPlugins,
  compiler: KotlinToolchain.KotlincInvoker,
): JvmCompilationTask {
  if (
    (
      inputs.processorsList.isEmpty() &&
        inputs.stubsPluginClasspathList.isEmpty()
    ) ||
    inputs.kotlinSourcesList.isEmpty()
  ) {
    return this
  } else {
    // KSP is now handled externally in Starlark, only KAPT runs through the builder
    if (!outputs.generatedClassJar.isNullOrEmpty()) {
      return runKaptPlugin(context, plugins, compiler)
    } else {
      return this
    }
  }
}

private fun JvmCompilationTask.runKaptPlugin(
  context: CompilationTaskContext,
  plugins: InternalCompilerPlugins,
  compiler: KotlinToolchain.KotlincInvoker,
): JvmCompilationTask {
  return context.execute("kapt (${inputs.processorsList.joinToString(", ")})") {
    val sources = (inputs.kotlinSourcesList + inputs.javaSourcesList).toTypedArray()
    baseArgs()
      .plus(
        plugins(
          options = inputs.stubsPluginOptionsList.filterNot { o -> o.startsWith(plugins.kapt.id) },
          classpath = inputs.stubsPluginClasspathList,
        ),
      ).plus(
        kaptArgs(context, plugins, "stubsAndApt"),
      ).list()
      .let { args ->
        context.executeCompilerTask(
          { out ->
            compiler.compile(args.toTypedArray(), sources, directories.generatedClasses, out)
          },
          printOnSuccess = context.whenTracing { true } == true,
        )
      }.let { outputLines ->
        // if tracing is enabled the output should be formatted in a special way, if we aren't
        // tracing then any compiler output would make it's way to the console as is.
        context.whenTracing {
          printLines("kapt output", outputLines)
        }
        return@let expandWithGeneratedSources()
      }
  }
}

/**
 * Compiles Kotlin sources to classes. Does not compile Java sources.
 */
fun JvmCompilationTask.compileKotlin(
  context: CompilationTaskContext,
  compiler: KotlinToolchain.KotlincInvoker,
  args: CompilationArgs = baseArgs(),
  printOnFail: Boolean = true,
): List<String> {
  if (inputs.kotlinSourcesList.isEmpty()) {
    writeJdeps(outputs.jdeps, emptyJdeps(info.label))
    return emptyList()
  } else {
    val sources = (inputs.javaSourcesList + inputs.kotlinSourcesList).toTypedArray()
    return (
      args +
        plugins(
          options = inputs.compilerPluginOptionsList,
          classpath = inputs.compilerPluginClasspathList,
        )
    ).list()
      .let {
        context.whenTracing {
          context.printLines("compileKotlin arguments:\n", it)
        }
        return@let context
          .executeCompilerTask(
            { out ->
              compiler.compile(it.toTypedArray(), sources, directories.classes, out)
            },
            printOnFail = printOnFail,
          ).also {
            context.whenTracing {
              printLines(
                "kotlinc Files Created:",
                Stream
                  .of(
                    directories.classes,
                    directories.generatedClasses,
                    directories.generatedSources,
                    directories.generatedJavaSources,
                    directories.temp,
                  ).map { Paths.get(it) }
                  .flatMap { walk(it) }
                  .filter { !isDirectory(it) }
                  .map { it.toString() }
                  .collect(toList()),
              )
            }
          }
      }
  }
}
