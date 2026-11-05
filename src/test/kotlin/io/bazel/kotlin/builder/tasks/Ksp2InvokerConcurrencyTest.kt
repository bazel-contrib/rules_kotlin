/*
 * Copyright 2026 The Bazel Authors. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package io.bazel.kotlin.builder.tasks

import com.google.common.truth.Truth.assertThat
import com.google.devtools.ksp.processing.Resolver
import com.google.devtools.ksp.processing.SymbolProcessor
import com.google.devtools.ksp.processing.SymbolProcessorEnvironment
import com.google.devtools.ksp.processing.SymbolProcessorProvider
import com.google.devtools.ksp.symbol.KSAnnotated
import io.bazel.kotlin.ksp2.Ksp2Invoker
import java.io.File
import java.lang.management.ManagementFactory
import java.util.concurrent.CountDownLatch
import java.util.concurrent.FutureTask
import java.util.concurrent.TimeUnit.SECONDS
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class Ksp2InvokerConcurrencyTest {
  @get:Rule
  val tmp = TemporaryFolder()

  @Test(timeout = 60000)
  fun testInvocationsSharingKspRuntimeDoNotOverlap() {
    BlockingKspProcessorProvider.firstEntered = CountDownLatch(1)
    BlockingKspProcessorProvider.releaseFirst = CountDownLatch(1)
    BlockingKspProcessorProvider.secondEntered = CountDownLatch(1)
    val first = FutureTask { execute("first") }
    val second = FutureTask { execute("second") }
    val firstThread = Thread(first, "first-ksp").apply { isDaemon = true }
    val secondThread = Thread(second, "second-ksp").apply { isDaemon = true }
    val threads = ManagementFactory.getThreadMXBean()

    firstThread.start()
    try {
      assertThat(BlockingKspProcessorProvider.firstEntered.await(30, SECONDS)).isTrue()
      secondThread.start()
      val deadline = System.nanoTime() + SECONDS.toNanos(10)
      // Wait for contention or overlap, rather than assuming the second request starts promptly.
      while (
        secondThread.isAlive &&
        BlockingKspProcessorProvider.secondEntered.count > 0 &&
        threads.getThreadInfo(secondThread.id)?.lockInfo?.identityHashCode != System.identityHashCode(Ksp2Invoker::class.java) &&
        System.nanoTime() < deadline
      ) {
        Thread.sleep(10)
      }
      assertThat(BlockingKspProcessorProvider.secondEntered.count).isEqualTo(1)
      assertThat(threads.getThreadInfo(secondThread.id)?.lockOwnerId).isEqualTo(firstThread.id)
    } finally {
      BlockingKspProcessorProvider.releaseFirst.countDown()
      firstThread.join(10000)
      secondThread.join(10000)
    }
    assertThat(first.get(10, SECONDS)).isEqualTo(0)
    assertThat(second.get(10, SECONDS)).isEqualTo(0)
    assertThat(BlockingKspProcessorProvider.secondEntered.count).isEqualTo(0)
  }

  private fun execute(name: String): Int {
    val root = tmp.newFolder(name)
    val sources = File(root, "src").apply { mkdirs() }
    File(sources, "Subject.kt").writeText("class Subject")
    return Ksp2Invoker().execute(
      moduleName = name,
      sourceRoots = listOf(sources),
      javaSourceRoots = emptyList(),
      libraries = emptyList(),
      kotlinOutputDir = File(root, "kotlin"),
      javaOutputDir = File(root, "java"),
      classOutputDir = File(root, "classes"),
      resourceOutputDir = File(root, "resources"),
      cachesDir = File(root, "caches"),
      projectBaseDir = root,
      outputBaseDir = root,
      jvmTarget = "17",
      languageVersion = "2.3",
      apiVersion = "2.3",
      jdkHome = File(System.getProperty("java.home")),
      processorOptions = mapOf("request" to name),
      experimentalPsiResolution = false,
      logLevel = 0,
    )
  }
}

class BlockingKspProcessorProvider : SymbolProcessorProvider {
  companion object {
    lateinit var firstEntered: CountDownLatch
    lateinit var releaseFirst: CountDownLatch
    lateinit var secondEntered: CountDownLatch
  }

  override fun create(environment: SymbolProcessorEnvironment): SymbolProcessor =
    object : SymbolProcessor {
      override fun process(resolver: Resolver): List<KSAnnotated> {
        if (environment.options["request"] == "first") {
          firstEntered.countDown()
          check(releaseFirst.await(30, SECONDS)) { "First KSP request was not released" }
        } else {
          secondEntered.countDown()
        }
        return emptyList()
      }
    }
}
