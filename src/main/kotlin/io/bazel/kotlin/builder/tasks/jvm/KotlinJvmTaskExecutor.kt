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
package io.bazel.kotlin.builder.tasks.jvm

import io.bazel.kotlin.builder.toolchain.CompilationStatusException
import io.bazel.kotlin.builder.toolchain.CompilationTaskContext
import io.bazel.kotlin.builder.toolchain.KotlinToolchain
import io.bazel.kotlin.model.JvmCompilationTask

/**
 * Due to an inconsistency in the handling of -Xfriends-path, jvm uses a comma (property list
 * separator)
 */
const val X_FRIENDS_PATH_SEPARATOR = ","

class KotlinJvmTaskExecutor(
  private val compilerBuilder: KotlinToolchain.KotlincInvokerBuilder,
  private val plugins: InternalCompilerPlugins,
) {
  private fun combine(
    one: Throwable?,
    two: Throwable?,
  ): Throwable? {
    return when {
      one != null && two != null -> {
        one.addSuppressed(two)
        return one
      }
      one != null -> one
      else -> two
    }
  }

  fun execute(
    context: CompilationTaskContext,
    task: JvmCompilationTask,
  ) {
    val compiler = compilerBuilder.build()

    val preprocessedTask =
      task
        .preProcessingSteps(context)
        .runPlugins(context, plugins, compiler)

    context.execute("compile classes") {
      preprocessedTask.apply {
        listOf(
          runCatching {
            context.execute("kotlinc") {
              if (compileKotlin) {
                compileKotlin(
                  context,
                  compiler,
                  args =
                    baseArgs()
                      .given(outputs.jdeps)
                      .notEmpty {
                        plugin(plugins.jdeps) {
                          flag("output", outputs.jdeps)
                          flag("target_label", info.label)
                          inputs.directDependenciesList.forEach {
                            flag("direct_dependencies", it)
                          }
                          inputs.classpathList.forEach {
                            flag("full_classpath", it)
                          }
                          flag("strict_kotlin_deps", info.strictKotlinDeps)
                        }
                      }.given(outputs.jar)
                      .notEmpty {
                        append(codeGenArgs())
                      }.given(outputs.abijar)
                      .notEmpty {
                        plugin(plugins.jvmAbiGen) {
                          flag("outputDir", directories.abiClasses)
                          if (info.treatInternalAsPrivateInAbiJar) {
                            flag("treatInternalAsPrivate", "true")
                          }
                          if (info.removePrivateClassesInAbiJar) {
                            flag("removePrivateClasses", "true")
                          }
                          if (info.removeDebugInfo) {
                            flag("removeDebugInfo", "true")
                          }
                        }
                        given(outputs.jar).empty {
                          plugin(plugins.skipCodeGen)
                        }
                      },
                  printOnFail = false,
                )
              } else {
                emptyList()
              }
            }
          },
        ).map {
          (it.getOrNull() ?: emptyList()) to it.exceptionOrNull()
        }.map {
          when (it.second) {
            // TODO(issue/296): remove when the CompilationStatusException is unified.
            is CompilationStatusException ->
              (it.second as CompilationStatusException).lines + it.first to it.second
            else -> it
          }
        }.fold(Pair<List<String>, Throwable?>(emptyList(), null)) { acc, result ->
          acc.first + result.first to combine(acc.second, result.second)
        }.apply {
          first.apply(context::printCompilerOutput)
          second?.let {
            throw it
          }
        }

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
}
