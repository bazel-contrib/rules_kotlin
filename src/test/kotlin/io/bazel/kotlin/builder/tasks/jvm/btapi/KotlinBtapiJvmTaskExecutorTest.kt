package io.bazel.kotlin.builder.tasks.jvm.btapi

import com.google.common.truth.Truth.assertThat
import io.bazel.kotlin.builder.Deps
import io.bazel.kotlin.builder.DirectoryType
import io.bazel.kotlin.builder.KotlinJvmTestBuilder
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.JUnit4
import java.util.function.Consumer
import java.util.zip.ZipFile

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

  @Test
  fun `compile multiple sources with cross-references`() {
    ctx.runBtapiCompileTask(
      Consumer { builder ->
        builder.addSource(
          "Base.kt",
          "package multi",
          "open class Base(val name: String)",
        )
        builder.addSource(
          "Derived.kt",
          "package multi",
          "class Derived : Base(\"derived\") { fun describe() = name }",
        )
        builder.outputJar()
        builder.outputJdeps()
        builder.compileKotlin()
      },
    )

    ctx.assertFilesExist(DirectoryType.CLASSES, "multi/Base.class", "multi/Derived.class")
  }

  @Test
  fun `compile with dependency on previous compilation`() {
    val dep =
      ctx.runBtapiCompileTask(
        Consumer { builder ->
          builder.addSource(
            "Lib.kt",
            "package lib",
            "class Lib { fun value() = 42 }",
          )
          builder.outputJar()
          builder.outputJdeps()
          builder.compileKotlin()
        },
      )

    ctx.runBtapiCompileTask(
      Consumer { builder ->
        builder.addDirectDependencies(dep)
        builder.addSource(
          "Consumer.kt",
          "package app",
          "import lib.Lib",
          "class Consumer { fun use() = Lib().value() }",
        )
        builder.outputJar()
        builder.outputJdeps()
        builder.compileKotlin()
      },
    )

    ctx.assertFilesExist(DirectoryType.CLASSES, "app/Consumer.class")
  }

  @Test
  fun `generates ABI jar`() {
    ctx.runBtapiCompileTask(
      Consumer { builder ->
        builder.addSource(
          "Public.kt",
          "package abi",
          "class Public { fun api() = \"visible\" }",
        )
        builder.addSource(
          "Another.kt",
          "package abi",
          "class Another { fun other() = 1 }",
        )
        builder.outputJar()
        builder.outputAbiJar()
        builder.outputJdeps()
        builder.compileKotlin()
      },
    )

    ctx.assertFilesExist(DirectoryType.ABI_CLASSES, "abi/Public.class", "abi/Another.class")
  }

  @Test
  fun `ABI jar used as dependency`() {
    val dep =
      ctx.runBtapiCompileTask(
        Consumer { builder ->
          builder.addSource(
            "Api.kt",
            "package api",
            "class Api { fun call() = \"ok\" }",
          )
          builder.outputJar()
          builder.outputAbiJar()
          builder.outputJdeps()
          builder.compileKotlin()
        },
      )

    ctx.runBtapiCompileTask(
      Consumer { builder ->
        builder.addDirectDependencies(dep)
        builder.addSource(
          "Client.kt",
          "package client",
          "import api.Api",
          "class Client { fun run() = Api().call() }",
        )
        builder.outputJar()
        builder.outputJdeps()
        builder.compileKotlin()
      },
    )

    ctx.assertFilesExist(DirectoryType.CLASSES, "client/Client.class")
  }

  @Test
  fun `public-only ABI jar excludes internal classes`() {
    val dep =
      ctx.runBtapiCompileTask(
        Consumer { builder ->
          builder.addSource(
            "Public.kt",
            "package abi",
            "class Public",
          )
          builder.addSource(
            "Internal.kt",
            "package abi",
            "internal class Internal",
          )
          builder.outputJar()
          builder.outputAbiJar()
          builder.publicOnlyAbiJar()
          builder.outputJdeps()
          builder.compileKotlin()
        },
      )

    val abiJarPath =
      dep.compileJars()
        .firstOrNull { it.endsWith("abi.jar") }

    assertThat(abiJarPath).isNotNull()
    ZipFile(abiJarPath).use { zip ->
      assertThat(zip.getEntry("abi/Public.class")).isNotNull()
      assertThat(zip.getEntry("abi/Internal.class")).isNull()
    }
  }

  @Test
  fun `KAPT annotation processing generates sources`() {
    val autoValueAnnotations = Deps.Dep.fromLabel("auto_value_annotations")
    val autoValue = Deps.Dep.fromLabel("auto_value")
    val annotationProcessor =
      Deps.AnnotationProcessor.builder()
        .processClass("com.google.auto.value.processor.AutoValueProcessor")
        .processorPath(
          Deps.Dep.classpathOf(
            autoValueAnnotations,
            autoValue,
            KotlinJvmTestBuilder.KOTLIN_ANNOTATIONS,
          ).collect(java.util.stream.Collectors.toSet()),
        )
        .build()

    ctx.runBtapiCompileTask(
      Consumer { builder ->
        builder.addAnnotationProcessors(annotationProcessor)
        builder.addDirectDependencies(
          autoValueAnnotations,
          KotlinJvmTestBuilder.KOTLIN_ANNOTATIONS,
          KotlinJvmTestBuilder.KOTLIN_STDLIB,
        )
        builder.addSource(
          "TestKtValue.kt",
          "package autovalue",
          "",
          "import com.google.auto.value.AutoValue",
          "",
          "@AutoValue",
          "abstract class TestKtValue {",
          "    abstract fun name(): String",
          "    fun builder(): Builder = AutoValue_TestKtValue.Builder()",
          "",
          "    @AutoValue.Builder",
          "    abstract class Builder {",
          "        abstract fun setName(name: String): Builder",
          "        abstract fun build(): TestKtValue",
          "    }",
          "}",
        )
        builder.generatedSourceJar()
        builder.ktStubsJar()
        builder.incrementalData()
      },
    )

    ctx.assertFilesExist(DirectoryType.JAVA_SOURCE_GEN, "autovalue/AutoValue_TestKtValue.java")
  }

  @Test
  fun `mixed Kotlin and Java sources compile`() {
    ctx.runBtapiCompileTask(
      Consumer { builder ->
        builder.addSource(
          "KClass.kt",
          "package mixed",
          "class KClass { fun greet() = \"kotlin\" }",
        )
        builder.addSource(
          "JClass.java",
          "package mixed;",
          "public class JClass { public String greet() { return \"java\"; } }",
        )
        builder.outputJar()
        builder.outputJdeps()
        builder.compileKotlin()
      },
    )

    ctx.assertFilesExist(DirectoryType.CLASSES, "mixed/KClass.class")
  }
}
