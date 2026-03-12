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
package io.bazel.kotlin.builder.toolchain

import io.bazel.kotlin.builder.utils.BazelRunFiles
import io.bazel.kotlin.builder.utils.verified
import java.io.File
import java.io.PrintStream
import java.lang.reflect.Method
import java.net.URLClassLoader

class KotlinToolchain private constructor(
  private val baseJars: List<File>,
  val kapt3Plugin: CompilerPlugin,
  val jvmAbiGen: CompilerPlugin,
  val skipCodeGen: CompilerPlugin,
  val jdepsGen: CompilerPlugin,
) {
  companion object {
    private val JVM_ABI_PLUGIN by lazy {
      BazelRunFiles
        .resolveVerifiedFromProperty(
          "@com_github_jetbrains_kotlin...jvm-abi-gen",
        ).toPath()
    }

    private val KAPT_PLUGIN by lazy {
      BazelRunFiles
        .resolveVerifiedFromProperty(
          "@com_github_jetbrains_kotlin...kapt",
        ).toPath()
    }

    private val COMPILER by lazy {
      BazelRunFiles
        .resolveVerifiedFromProperty(
          "@rules_kotlin...compiler",
        ).toPath()
    }

    private val SKIP_CODE_GEN_PLUGIN by lazy {
      BazelRunFiles
        .resolveVerifiedFromProperty(
          "@rules_kotlin...skip-code-gen",
        ).toPath()
    }

    private val JDEPS_GEN_PLUGIN by lazy {
      BazelRunFiles
        .resolveVerifiedFromProperty(
          "@rules_kotlin...jdeps-gen",
        ).toPath()
    }

    private val KOTLINC by lazy {
      BazelRunFiles
        .resolveVerifiedFromProperty(
          "@com_github_jetbrains_kotlin...kotlin-compiler",
        ).toPath()
    }

    private val KOTLIN_STDLIB by lazy {
      BazelRunFiles
        .resolveVerifiedFromProperty(
          "@rules_kotlin...kotlin-stdlib",
        ).toPath()
    }

    private val KOTLIN_REFLECT by lazy {
      BazelRunFiles
        .resolveVerifiedFromProperty(
          "@rules_kotlin...kotlin-reflect",
        ).toPath()
    }

    private val KOTLINX_SERIALIZATION_CORE_JVM by lazy {
      BazelRunFiles
        .resolveVerifiedFromProperty(
          "@com_github_jetbrains_kotlinx...serialization-core-jvm",
        ).toPath()
    }

    private val KOTLINX_SERIALIZATION_JSON_JVM by lazy {
      BazelRunFiles
        .resolveVerifiedFromProperty(
          "@com_github_jetbrains_kotlinx...serialization-json-jvm",
        ).toPath()
    }

    private val BUILD_TOOLS_API by lazy {
      BazelRunFiles
        .resolveVerifiedFromProperty(
          "@com_github_jetbrains_kotlin...build-tools-impl",
        ).toPath()
    }

    internal val NO_ARGS = arrayOf<Any>()

    @JvmStatic
    fun createToolchain(): KotlinToolchain =
      createToolchain(
        kotlinc = KOTLINC.verified().absoluteFile,
        buildTools = BUILD_TOOLS_API.verified().absoluteFile,
        compiler = COMPILER.verified().absoluteFile,
        jvmAbiGenFile = JVM_ABI_PLUGIN.verified().absoluteFile,
        skipCodeGenFile = SKIP_CODE_GEN_PLUGIN.verified().absoluteFile,
        jdepsGenFile = JDEPS_GEN_PLUGIN.verified().absoluteFile,
        kaptFile = KAPT_PLUGIN.verified().absoluteFile,
        kotlinStdlib = KOTLIN_STDLIB.verified().absoluteFile,
        kotlinReflect = KOTLIN_REFLECT.verified().absoluteFile,
        kotlinxSerializationCoreJvm = KOTLINX_SERIALIZATION_CORE_JVM.verified().absoluteFile,
        kotlinxSerializationJsonJvm = KOTLINX_SERIALIZATION_JSON_JVM.verified().absoluteFile,
      )

    @JvmStatic
    fun createToolchain(
      kotlinc: File,
      buildTools: File,
      compiler: File,
      jvmAbiGenFile: File,
      skipCodeGenFile: File,
      jdepsGenFile: File,
      kaptFile: File,
      kotlinStdlib: File,
      kotlinReflect: File,
      kotlinxSerializationCoreJvm: File,
      kotlinxSerializationJsonJvm: File,
    ): KotlinToolchain =
      KotlinToolchain(
        listOf(
          kotlinc,
          compiler,
          buildTools,
          // plugins *must* be preloaded. Not doing so causes class conflicts
          // (and a NoClassDef err) in the compiler extension interfaces.
          // This may cause issues in accepting user defined compiler plugins.
          jvmAbiGenFile,
          skipCodeGenFile,
          jdepsGenFile,
          kotlinStdlib,
          kotlinReflect,
          kotlinxSerializationCoreJvm,
          kotlinxSerializationJsonJvm,
        ),
        jvmAbiGen =
          CompilerPlugin(
            jvmAbiGenFile.path,
            "org.jetbrains.kotlin.jvm.abi",
          ),
        skipCodeGen =
          CompilerPlugin(
            skipCodeGenFile.path,
            "io.bazel.kotlin.plugin.SkipCodeGen",
          ),
        jdepsGen =
          CompilerPlugin(
            jdepsGenFile.path,
            "io.bazel.kotlin.plugin.jdeps.JDepsGen",
          ),
        kapt3Plugin =
          CompilerPlugin(
            kaptFile.path,
            "org.jetbrains.kotlin.kapt3",
          ),
      )
  }

  val classLoader by lazy {
    URLClassLoader(
      baseJars.map { it.toURI().toURL() }.toTypedArray(),
      ClassLoader.getPlatformClassLoader(),
    )
  }

  data class CompilerPlugin(
    val jarPath: String,
    val id: String,
  )

  open class KotlincInvoker internal constructor(
    classLoader: ClassLoader,
    clazz: String,
  ) {
    private val compiler: Any
    private val execMethod: Method
    private val getCodeMethod: Method

    init {
      val compilerClass = classLoader.loadClass(clazz)
      val exitCodeClass =
        classLoader.loadClass("org.jetbrains.kotlin.cli.common.ExitCode")

      compiler = compilerClass.getConstructor().newInstance()
      execMethod =
        compilerClass.getMethod("exec", PrintStream::class.java, Array<String>::class.java)
      getCodeMethod = exitCodeClass.getMethod("getCode")
    }

    // Kotlin error codes:
    // 1 is a standard compilation error
    // 2 is an internal error
    // 3 is the script execution error
    fun compile(
      args: Array<String>,
      out: PrintStream,
    ): Int {
      val exitCodeInstance = execMethod.invoke(compiler, out, args)
      return getCodeMethod.invoke(exitCodeInstance, *NO_ARGS) as Int
    }
  }

  class KotlincInvokerBuilder(
    private val toolchain: KotlinToolchain,
  ) {
    fun build(useExperimentalBuildToolsAPI: Boolean): KotlincInvoker {
      val clazz =
        if (useExperimentalBuildToolsAPI) {
          "io.bazel.kotlin.compiler.BuildToolsAPICompiler"
        } else {
          "io.bazel.kotlin.compiler.BazelK2JVMCompiler"
        }
      return KotlincInvoker(
        classLoader = toolchain.classLoader,
        clazz = clazz,
      )
    }
  }
}
