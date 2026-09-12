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

package io.bazel.kotlin.builder.tasks

import com.google.common.truth.Truth.assertThat
import io.bazel.kotlin.builder.tasks.jvm.btapi.BtapiTaskExecutor
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class BtapiRuntimeCacheTest {
  @get:Rule
  val tmp = TemporaryFolder()

  // The invoker loads the compiler runtime lazily; only its identity matters in these tests.
  private val executor = BtapiTaskExecutor(javaClass.classLoader)

  @Test
  fun testReusesUnchangedRuntimeAndInvalidatesChangedContents() {
    val jar = tmp.newFile("compiler.jar").apply { writeBytes(byteArrayOf(1, 2, 3)) }
    val classpath = listOf(jar.absolutePath)
    val first = executor.getCompilerInvoker(classpath)
    assertThat(executor.getCompilerInvoker(classpath)).isSameInstanceAs(first)

    val timestamp = jar.lastModified()
    jar.writeBytes(byteArrayOf(4, 5, 6))
    check(jar.setLastModified(timestamp))
    val replacement = executor.getCompilerInvoker(classpath)
    assertThat(replacement).isNotSameInstanceAs(first)
    assertThat(executor.getCompilerInvoker(classpath)).isSameInstanceAs(replacement)
  }

  @Test
  fun testClasspathOrderSelectsDifferentRuntime() {
    val first = tmp.newFile("first.jar").apply { writeBytes(byteArrayOf(1)) }
    val second = tmp.newFile("second.jar").apply { writeBytes(byteArrayOf(2)) }
    val classpath = listOf(first.absolutePath, second.absolutePath)
    assertThat(executor.getCompilerInvoker(classpath.reversed()))
      .isNotSameInstanceAs(executor.getCompilerInvoker(classpath))
  }
}
