package io.bazel.kotlin.builder.tasks.jvm

import io.bazel.kotlin.builder.KotlinJvmTestBuilder
import org.junit.Test
import java.io.File
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class KotlinJvmTaskExecutorTest {

  private val ctx = KotlinJvmTestBuilder()

  @Test
  fun testSimpleGeneratedNonJvmSourcesIgnored() {
    ctx.resetForNext()
    ctx.writeGeneratedSourceFile(
      "AGenClass.kt",
      arrayOf("package something.gen;", "class AGenClass{}")
    )
    ctx.writeGeneratedSourceFile(
      "AnotherGenClass.java",
      arrayOf("package something.gen;", "class AnotherGenClass{}")
    )
    ctx.writeGeneratedSourceFile(
      "ignore-me.txt",
      arrayOf("contents do not matter")
    )
    ctx.writeSourceFile(
      "ignore-me-regular-src.kt",
      arrayOf("contents do not matter")
    )
    ctx.writeSourceFile(
      "ignore-me-another-regular-src.java",
      arrayOf("contents do not matter")
    )
    val compileTask = ctx.buildTask()

    assertTrue(compileTask.inputs.javaSourcesList.isEmpty())
    assertTrue(compileTask.inputs.kotlinSourcesList.isEmpty())

    val expandedCompileTask = compileTask.expandWithGeneratedSources()

    assertTrue(compileTask.inputs.javaSourcesList.isEmpty())
    assertTrue(compileTask.inputs.kotlinSourcesList.isEmpty())

    assertTrue(expandedCompileTask.inputs.javaSourcesList.isNotEmpty())
    // Use platform-specific path separator for cross-platform compatibility
    val javaSuffix = "generated_sources${File.separator}AnotherGenClass.java"
    assertNotNull(expandedCompileTask.inputs.javaSourcesList.find { path ->
      path.endsWith(javaSuffix)
    })
    assertEquals(expandedCompileTask.inputs.javaSourcesList.size, 1)
    val ktSuffix = "generated_sources${File.separator}AGenClass.kt"
    assertNotNull(expandedCompileTask.inputs.kotlinSourcesList.find { path ->
      path.endsWith(ktSuffix)
    })
    assertEquals(expandedCompileTask.inputs.kotlinSourcesList.size, 1)
  }
}
