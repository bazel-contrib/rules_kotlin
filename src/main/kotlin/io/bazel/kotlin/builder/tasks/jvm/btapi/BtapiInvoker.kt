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

import io.bazel.kotlin.compiler.CompilationUnit
import io.bazel.kotlin.compiler.CompilerConfiguration
import io.bazel.kotlin.compiler.CompilerPluginSpec
import io.bazel.kotlin.compiler.KotlinBtapiCompiler
import java.io.PrintStream
import java.lang.invoke.MethodHandle
import java.lang.invoke.MethodHandles
import java.lang.reflect.Proxy
import kotlin.reflect.jvm.javaMethod

/**
 * Invokes the typed Build Tools API compilation entry point inside the isolated compiler
 * classloader.
 */
class BtapiInvoker(
  private val btapiClassLoader: ClassLoader,
  btImplClasspath: Array<String>,
) : KotlinBtapiCompiler {
  private val compilerImpl: Any
  private val execHandle: MethodHandle
  private val compilationUnitDispatcher = Dispatcher(CompilationUnit::class.java)
  private val configurationDispatcher = Dispatcher(CompilerConfiguration::class.java)
  private val pluginDispatcher = Dispatcher(CompilerPluginSpec::class.java)

  init {
    val compilerClass = btapiClassLoader.loadClass("io.bazel.kotlin.compiler.BuildToolsAPICompiler")
    val compilerInterface = KotlinBtapiCompiler::class.java.counterpart()

    compilerImpl =
      compilerInterface.cast(
        compilerClass
          .getConstructor(Array<String>::class.java)
          .newInstance(btImplClasspath as Any),
      )

    val execMethod = checkNotNull(KotlinBtapiCompiler::exec.javaMethod)
    execHandle =
      MethodHandles.lookup().unreflect(
        compilerInterface.getMethod(
          execMethod.name,
          *execMethod.parameterTypes.map { it.counterpart() }.toTypedArray(),
        ),
      )
  }

  override fun exec(
    errStream: PrintStream,
    compilationUnit: CompilationUnit,
    configuration: CompilerConfiguration,
    plugins: List<CompilerPluginSpec>,
  ): Int =
    execHandle.invoke(
      compilerImpl,
      errStream,
      compilationUnitDispatcher.applyTo(compilationUnit),
      configurationDispatcher.applyTo(configuration),
      plugins.map(pluginDispatcher::applyTo),
    ) as Int

  /**
   * The class's counterpart defined by the BTA implementation classloader
   */
  private fun Class<*>.counterpart(): Class<*> =
    if (classLoader === KotlinBtapiCompiler::class.java.classLoader) {
      btapiClassLoader.loadClass(name)
    } else {
      this
    }

  /**
   * Dispatches calls from BTA-implementation side to worker-side data structures
   */
  private inner class Dispatcher(
    contractInterface: Class<*>,
  ) {
    private val counterpartInterfaces = arrayOf(contractInterface.counterpart())
    private val handles: Map<String, MethodHandle> =
      buildMap {
        val lookup = MethodHandles.lookup()
        // Besides the contract's own methods, for completeness route also standard Object methods (equals/hashCode/toString)
        for (method in contractInterface.methods + Any::class.java.methods) {
          put(method.name, lookup.unreflect(method))
        }
      }

    fun applyTo(instance: Any): Any =
      Proxy.newProxyInstance(btapiClassLoader, counterpartInterfaces) { _, method, args ->
        handles.getValue(method.name).invokeWithArguments(instance, *(args ?: emptyArray()))
      }
  }
}
