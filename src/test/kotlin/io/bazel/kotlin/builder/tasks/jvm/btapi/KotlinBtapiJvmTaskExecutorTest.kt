package io.bazel.kotlin.builder.tasks.jvm.btapi

import com.google.common.truth.Truth.assertThat
import io.bazel.kotlin.builder.DirectoryType
import io.bazel.kotlin.builder.KotlinJvmTestBuilder
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.JUnit4
import java.util.function.Consumer

@RunWith(JUnit4::class)
class KotlinBtapiJvmTaskExecutorTest {
  private val ctx = KotlinJvmTestBuilder()

  @Test
  fun `compile succeeds with valid Kotlin source`() {
    ctx.runBtapiCompileTask(
      Consumer { builder ->
        builder.addSource(
          "AClass.kt",
          "package test",
          "class AClass { fun greet() = \"hello\" }",
        )
        builder.outputJar()
        builder.outputJdeps()
        builder.compileKotlin()
      },
    )

    ctx.assertFilesExist(DirectoryType.CLASSES, "test/AClass.class")
  }

  @Test
  fun `compile reports errors for invalid Kotlin source`() {
    ctx.runFailingCompileTaskAndValidateOutput(
      {
        ctx.runBtapiCompileTask(
          Consumer { builder ->
            builder.addSource(
              "Broken.kt",
              "package test",
              "class Broken {",
            )
            builder.outputJar()
            builder.outputJdeps()
            builder.compileKotlin()
          },
        )
      },
    ) { lines ->
      assertThat(lines.any { it.contains("Broken.kt") }).isTrue()
    }
  }
}
