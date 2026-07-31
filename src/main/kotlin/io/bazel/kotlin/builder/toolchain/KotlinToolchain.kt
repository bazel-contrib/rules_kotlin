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
import java.lang.invoke.MethodHandle
import java.lang.invoke.MethodHandles
import java.net.URLClassLoader

class KotlinToolchain private constructor(
  private val baseJars: List<File>,
  val kapt3Plugin: CompilerPlugin,
  val jvmAbiGen: CompilerPlugin,
  val skipCodeGen: CompilerPlugin,
  val jdepsGen: CompilerPlugin,
  /**
   * The worker-provided jars every Build Tools API compiler runtime shares regardless of the
   * runtime jar set the toolchain supplies: the rules_kotlin compiler wrapper (the
   * KotlinBtapiCompiler contract implementations), the Build Tools API interfaces, and the Kotlin
   * standard library and reflection runtime their bytecode links against. Loaded once into a host
   * classloader from which every runtime classloader sees only the API classes and the JDK
   * (SharedApiClassesClassLoader) -- the runtime's own jars, including its standard library, stay
   * fully isolated per runtime.
   */
  private val btapiJars: List<File>,
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

    private val KOTLIN_DAEMON_CLIENT by lazy {
      BazelRunFiles
        .resolveVerifiedFromProperty(
          "@com_github_jetbrains_kotlin...kotlin-daemon-client",
        ).toPath()
    }

    private val COMPILER_STDLIB by lazy {
      BazelRunFiles
        .resolveVerifiedFromProperty(
          "@com_github_jetbrains_kotlin...kotlin-stdlib",
        ).toPath()
    }

    private val COMPILER_REFLECT by lazy {
      BazelRunFiles
        .resolveVerifiedFromProperty(
          "@rules_kotlin..kotlin.compiler.kotlin-reflect",
        ).toPath()
    }

    private val KOTLINX_SERIALIZATION_CORE_JVM by lazy {
      BazelRunFiles
        .resolveVerifiedFromProperty(
          "@com_github_jetbrains_kotlinx...serialization-core-jvm",
        ).toPath()
    }

    private val KOTLINX_SERIALIZATION_JSON by lazy {
      BazelRunFiles
        .resolveVerifiedFromProperty(
          "@com_github_jetbrains_kotlinx...serialization-json",
        ).toPath()
    }

    private val KOTLINX_SERIALIZATION_JSON_JVM by lazy {
      BazelRunFiles
        .resolveVerifiedFromProperty(
          "@com_github_jetbrains_kotlinx...serialization-json-jvm",
        ).toPath()
    }

    private val BUILD_TOOLS_IMPL by lazy {
      BazelRunFiles
        .resolveVerifiedFromProperty(
          "@com_github_jetbrains_kotlin...build-tools-impl",
        ).toPath()
    }

    private val BUILD_TOOLS_API by lazy {
      BazelRunFiles
        .resolveVerifiedFromProperty(
          "@com_github_jetbrains_kotlin...build-tools-api",
        ).toPath()
    }

    @JvmStatic
    fun createToolchain(): KotlinToolchain =
      createToolchain(
        KOTLINC.verified().absoluteFile,
        COMPILER_STDLIB.verified().absoluteFile,
        COMPILER_REFLECT.verified().absoluteFile,
        KOTLIN_DAEMON_CLIENT.verified().absoluteFile,
        BUILD_TOOLS_IMPL.verified().absoluteFile,
        BUILD_TOOLS_API.verified().absoluteFile,
        COMPILER.verified().absoluteFile,
        JVM_ABI_PLUGIN.verified().absoluteFile,
        SKIP_CODE_GEN_PLUGIN.verified().absoluteFile,
        JDEPS_GEN_PLUGIN.verified().absoluteFile,
        KAPT_PLUGIN.verified().absoluteFile,
        KOTLINX_SERIALIZATION_CORE_JVM.toFile(),
        KOTLINX_SERIALIZATION_JSON.toFile(),
        KOTLINX_SERIALIZATION_JSON_JVM.toFile(),
      )

    @JvmStatic
    fun createToolchain(
      kotlinc: File,
      compilerStdlib: File,
      compilerReflect: File,
      kotlinDaemonClient: File,
      buildTools: File,
      buildToolsApi: File,
      compiler: File,
      jvmAbiGenFile: File,
      skipCodeGenFile: File,
      jdepsGenFile: File,
      kaptFile: File,
      kotlinxSerializationCoreJvm: File,
      kotlinxSerializationJson: File,
      kotlinxSerializationJsonJvm: File,
    ): KotlinToolchain =
      KotlinToolchain(
        listOf(
          kotlinc,
          kotlinDaemonClient,
          compiler,
          buildTools,
          buildToolsApi,
          jvmAbiGenFile,
          skipCodeGenFile,
          jdepsGenFile,
          kotlinxSerializationCoreJvm,
          kotlinxSerializationJson,
          kotlinxSerializationJsonJvm,
        ),
        btapiJars =
          listOf(
            compiler,
            compilerStdlib,
            compilerReflect,
            buildToolsApi,
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

  /**
   * The classloader defining the Build Tools API host world ([btapiJars]); created on
   * the first Build Tools API task. Runtime classloaders see only its API classes and the JDK.
   */
  val btapiClassLoader by lazy {
    URLClassLoader(
      btapiJars.map { it.toURI().toURL() }.toTypedArray(),
      ClassLoader.getPlatformClassLoader(),
    )
  }

  data class CompilerPlugin(
    val jarPath: String,
    val id: String,
  )

  open class KotlincInvoker(
    toolchain: KotlinToolchain,
    clazz: String = "io.bazel.kotlin.compiler.BazelK2JVMCompiler",
  ) {
    private val compiler: Any
    private val execHandle: MethodHandle
    private val getCodeHandle: MethodHandle

    init {
      val compilerClass = toolchain.classLoader.loadClass(clazz)
      val compilerInterface =
        toolchain.classLoader.loadClass("io.bazel.kotlin.compiler.KotlinCompiler")
      val exitCodeClass =
        toolchain.classLoader.loadClass("org.jetbrains.kotlin.cli.common.ExitCode")

      compiler = compilerInterface.cast(compilerClass.getConstructor().newInstance())

      // The interface is the source of truth for the exec method signature.
      val execMethod = compilerInterface.declaredMethods.single { it.name == "exec" }
      val lookup = MethodHandles.lookup()
      execHandle = lookup.unreflect(execMethod)
      getCodeHandle = lookup.unreflect(exitCodeClass.getMethod("getCode"))
    }

    // Kotlin error codes:
    // 1 is a standard compilation error
    // 2 is an internal error
    // 3 is the script execution error
    fun compile(
      args: Array<String>,
      sources: Array<String>,
      destination: String,
      out: PrintStream,
    ): Int {
      val exitCode = execHandle.invoke(compiler, out, args, sources, destination)
      return getCodeHandle.invoke(exitCode) as Int
    }
  }
}
