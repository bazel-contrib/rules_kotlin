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

import io.bazel.kotlin.builder.toolchain.ToolchainSpec
import org.jetbrains.kotlin.buildtools.api.ExperimentalBuildToolsApi
import org.jetbrains.kotlin.buildtools.api.KotlinToolchains
import org.jetbrains.kotlin.buildtools.api.SharedApiClassesClassLoader
import java.net.URLClassLoader
import java.nio.file.Files
import java.util.concurrent.ConcurrentHashMap

/**
 * Caches BtapiCompiler instances keyed by toolchain specification.
 *
 * A worker process may serve requests from multiple Kotlin toolchains, so compilers
 * must be selected and cached per request rather than fixed at worker startup.
 */
@OptIn(ExperimentalBuildToolsApi::class)
class BtapiCompilerCache : AutoCloseable {
  private val compilers = ConcurrentHashMap<ToolchainSpec, CachedBtapiCompiler>()
  private val compilerCreationLock = Any()

  operator fun get(spec: ToolchainSpec): BtapiCompiler {
    compilers[spec]?.let { return it.compiler }
    synchronized(compilerCreationLock) {
      compilers[spec]?.let { return it.compiler }
      val compiler = createCompiler(spec)
      compilers[spec] = compiler
      return compiler.compiler
    }
  }

  override fun close() {
    compilers.values.forEach { it.close() }
    compilers.clear()
  }

  private fun createCompiler(spec: ToolchainSpec): CachedBtapiCompiler {
    spec.btapiClasspath.forEach { file ->
      require(Files.isRegularFile(file)) {
        "BTAPI runtime artifact does not exist or is not a file: $file"
      }
    }

    val urls = spec.btapiClasspath.map { it.toUri().toURL() }.toTypedArray()
    val classLoader = URLClassLoader(urls, SharedApiClassesClassLoader())
    return CachedBtapiCompiler(
      compiler =
        BtapiCompiler(
          KotlinToolchains.loadImplementation(classLoader),
          jdepsJar = spec.jdepsJar,
          abiGenJar = spec.abiGenJar,
          skipCodeGenJar = spec.skipCodeGenJar,
          kaptJar = spec.kaptJar,
        ),
      classLoader = classLoader,
    )
  }
}

private class CachedBtapiCompiler(
  val compiler: BtapiCompiler,
  private val classLoader: AutoCloseable,
) : AutoCloseable {
  override fun close() {
    compiler.close()
    classLoader.close()
  }
}
