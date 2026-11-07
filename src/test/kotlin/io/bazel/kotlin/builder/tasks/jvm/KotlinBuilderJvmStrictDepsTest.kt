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
package io.bazel.kotlin.builder.tasks.jvm;

import com.google.common.truth.Truth.assertThat
import io.bazel.kotlin.builder.KotlinJvmTestBuilder
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.Parameterized
import java.util.function.Consumer

@RunWith(Parameterized::class)
class KotlinBuilderJvmStrictDepsTest(private val buildToolsApi: Boolean) {
  companion object {
    @JvmStatic
    @Parameterized.Parameters(name = "buildToolsApi={0}")
    fun data(): Collection<Array<Any>> = listOf(arrayOf(true), arrayOf(false))
  }

  val ctx = KotlinJvmTestBuilder()

  private fun runCompileTask(block: (c: KotlinJvmTestBuilder.TaskBuilder) -> Unit) =
    ctx.runCompileTask(
      Consumer { c: KotlinJvmTestBuilder.TaskBuilder ->
        if (buildToolsApi) {
          c.useBuildToolsApi()
        }
        block(c)
      },
    )

  /** Compiles a source that references a class of a transitive dependency only. */
  private fun compileTransitiveReference(strictDeps: String) {
    val transitiveDep = runCompileTask { c ->
      c.addSource("TransitiveClass.kt",
        """
          package something
          
          class TransitiveClass{}
        """)
      c.outputJar()
      c.outputJdeps()
      c.compileKotlin()
    }

    val dependentTarget = runCompileTask { c ->
      c.addSource("AClass.kt",
        """
          package something
          
          class AClass{}
        """)
      c.outputJar()
      c.compileKotlin()
      c.addDirectDependencies(transitiveDep)
      c.outputJdeps()
    }

    runCompileTask { c ->
      c.addSource("HasTransitiveReference.kt",
        """
          package something

          val transitiveReference = TransitiveClass()
        """)
      c.outputJar()
      c.compileKotlin()
      c.addDirectDependencies(dependentTarget)
      c.addTransitiveDependencies(transitiveDep)
      c.outputJdeps()
      c.kotlinStrictDeps(strictDeps)
    }
  }

  @Test
  fun `strict dependency violation error`() {
    ctx.runFailingCompileTaskAndValidateOutput(
      { compileTransitiveReference("error") }
    ) { lines: List<String?> ->
      assertThat(lines.any { it?.contains("Please add the following dependencies") == true })
        .isTrue()
    }
  }

  @Test
  fun `strict dependency violation warning`() {
    compileTransitiveReference("warn")

    assertThat(ctx.outLines().any { it.contains("Please add the following dependencies") })
      .isTrue()
  }

}
