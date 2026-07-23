/*
 * Copyright 2024 The Bazel Authors. All rights reserved.
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
import io.bazel.kotlin.builder.tasks.jvm.Ksp2Task.Companion.Ksp2Flags
import io.bazel.kotlin.builder.tasks.jvm.Ksp2Task.Companion.clearKspClassLoaderCacheForTesting
import io.bazel.kotlin.builder.tasks.jvm.Ksp2Task.Companion.fingerprintOf
import io.bazel.kotlin.builder.tasks.jvm.Ksp2Task.Companion.getKspClassLoader
import io.bazel.kotlin.builder.tasks.jvm.Ksp2Task.Companion.parseKspOptions
import io.bazel.kotlin.builder.utils.ArgMap
import org.junit.After
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.junit.runners.JUnit4

/**
 * Unit tests for KSP2 task argument handling.
 */
@RunWith(JUnit4::class)
class Ksp2TaskTest {
  @get:Rule
  val tmp = TemporaryFolder()

  @After
  fun tearDown() {
    clearKspClassLoaderCacheForTesting()
  }

  @Test
  fun testKsp2ModuleName() {
    val args =
      ArgMap(
        mapOf(
          Ksp2Flags.MODULE_NAME.flag to listOf("test_module"),
        ),
      )
    assertThat(args.mandatorySingle(Ksp2Flags.MODULE_NAME)).isEqualTo("test_module")
  }

  @Test
  fun testKsp2Sources() {
    val sources = listOf("src/Foo.kt", "src/Bar.java")
    val args =
      ArgMap(
        mapOf(
          Ksp2Flags.SOURCES.flag to sources,
        ),
      )
    assertThat(args.optional(Ksp2Flags.SOURCES)).containsExactlyElementsIn(sources)
  }

  @Test
  fun testKsp2SourceJars() {
    val srcjars = listOf("lib1-sources.jar", "lib2-sources.jar")
    val args =
      ArgMap(
        mapOf(
          Ksp2Flags.SOURCE_JARS.flag to srcjars,
        ),
      )
    assertThat(args.optional(Ksp2Flags.SOURCE_JARS))
      .containsExactlyElementsIn(srcjars)
  }

  @Test
  fun testKsp2Libraries() {
    val libs = listOf("dep1.jar", "dep2.jar", "dep3.jar")
    val args =
      ArgMap(
        mapOf(
          Ksp2Flags.LIBRARIES.flag to libs,
        ),
      )
    assertThat(args.optional(Ksp2Flags.LIBRARIES)).containsExactlyElementsIn(libs)
  }

  @Test
  fun testKsp2ProcessorClasspath() {
    val processorJars = listOf("processor1.jar", "ksp-api.jar")
    val args =
      ArgMap(
        mapOf(
          Ksp2Flags.PROCESSOR_CLASSPATH.flag to processorJars,
        ),
      )
    assertThat(args.optional(Ksp2Flags.PROCESSOR_CLASSPATH))
      .containsExactlyElementsIn(processorJars)
  }

  @Test
  fun testKsp2GeneratedOutputPaths() {
    val args =
      ArgMap(
        mapOf(
          Ksp2Flags.GENERATED_SOURCES_OUTPUT.flag to listOf("gen-sources.jar"),
          Ksp2Flags.GENERATED_CLASSES_OUTPUT.flag to listOf("gen-classes.jar"),
        ),
      )
    assertThat(args.mandatorySingle(Ksp2Flags.GENERATED_SOURCES_OUTPUT))
      .isEqualTo("gen-sources.jar")
    assertThat(args.mandatorySingle(Ksp2Flags.GENERATED_CLASSES_OUTPUT))
      .isEqualTo("gen-classes.jar")
  }

  @Test
  fun testKsp2CompilerSettings() {
    val args =
      ArgMap(
        mapOf(
          Ksp2Flags.LANGUAGE_VERSION.flag to listOf("1.9"),
          Ksp2Flags.API_VERSION.flag to listOf("1.9"),
          Ksp2Flags.JVM_TARGET.flag to listOf("17"),
          Ksp2Flags.JDK_HOME.flag to listOf("/path/to/jdk"),
        ),
      )
    assertThat(args.optionalSingle(Ksp2Flags.LANGUAGE_VERSION)).isEqualTo("1.9")
    assertThat(args.optionalSingle(Ksp2Flags.API_VERSION)).isEqualTo("1.9")
    assertThat(args.optionalSingle(Ksp2Flags.JVM_TARGET)).isEqualTo("17")
    assertThat(args.optionalSingle(Ksp2Flags.JDK_HOME)).isEqualTo("/path/to/jdk")
  }

  @Test
  fun testKsp2FlagsHaveCorrectNames() {
    assertThat(Ksp2Flags.MODULE_NAME.flag).isEqualTo("--module_name")
    assertThat(Ksp2Flags.SOURCES.flag).isEqualTo("--sources")
    assertThat(Ksp2Flags.SOURCE_JARS.flag).isEqualTo("--source_jars")
    assertThat(Ksp2Flags.LIBRARIES.flag).isEqualTo("--libraries")
    assertThat(Ksp2Flags.PROCESSOR_CLASSPATH.flag)
      .isEqualTo("--processor_classpath")
    assertThat(Ksp2Flags.GENERATED_SOURCES_OUTPUT.flag)
      .isEqualTo("--generated_sources_output")
    assertThat(Ksp2Flags.GENERATED_CLASSES_OUTPUT.flag)
      .isEqualTo("--generated_classes_output")
    assertThat(Ksp2Flags.LANGUAGE_VERSION.flag).isEqualTo("--language_version")
    assertThat(Ksp2Flags.API_VERSION.flag).isEqualTo("--api_version")
    assertThat(Ksp2Flags.JVM_TARGET.flag).isEqualTo("--jvm_target")
    assertThat(Ksp2Flags.JDK_HOME.flag).isEqualTo("--jdk_home")
    assertThat(Ksp2Flags.KSP_OPTIONS.flag).isEqualTo("--ksp_options")
  }

  @Test
  fun testEmptyOptionalSources() {
    val args = ArgMap(mapOf())
    assertThat(args.optional(Ksp2Flags.SOURCES)).isNull()
    assertThat(args.optional(Ksp2Flags.SOURCE_JARS)).isNull()
  }

  @Test
  fun testKspOptions() {
    val options = listOf("key1=value1", "key2=value2")
    val args =
      ArgMap(
        mapOf(
          Ksp2Flags.KSP_OPTIONS.flag to options,
        ),
      )
    assertThat(args.optional(Ksp2Flags.KSP_OPTIONS))
      .containsExactlyElementsIn(options)
  }

  @Test
  fun testKspOptionsEmpty() {
    val args = ArgMap(mapOf())
    assertThat(args.optional(Ksp2Flags.KSP_OPTIONS)).isNull()
  }

  @Test
  fun testParseKspOptions() {
    assertThat(parseKspOptions(listOf("key=value", "another=val"))).isEqualTo(mapOf("key" to "value", "another" to "val"))
  }

  @Test
  fun testParseKspOptionsValueContainsEquals() {
    assertThat(parseKspOptions(listOf("key=val=ue"))).isEqualTo(mapOf("key" to "val=ue"))
  }

  @Test
  fun testParseKspOptionsNoEquals() {
    assertThat(parseKspOptions(listOf("keyonly"))).isEqualTo(mapOf("keyonly" to ""))
  }

  @Test
  fun testParseKspOptionsEmptyList() {
    assertThat(parseKspOptions(emptyList())).isEmpty()
  }

  @Test
  fun testKspClassLoaderCacheReusesLoaderForSameProcessorClasspath() {
    val jar1 = tmp.newFile("processor.jar").apply { writeBytes(byteArrayOf(1)) }
    val jar2 = tmp.newFile("ksp-api.jar").apply { writeBytes(byteArrayOf(2)) }
    val processorClasspath = listOf(jar1.absolutePath, jar2.absolutePath)

    val firstClassLoader = getKspClassLoader(processorClasspath)
    val secondClassLoader = getKspClassLoader(processorClasspath)

    assertThat(secondClassLoader).isSameInstanceAs(firstClassLoader)
  }

  @Test
  fun testKspClassLoaderCacheKeyIsProcessorClasspathOrderInsensitive() {
    val jar1 = tmp.newFile("processor.jar").apply { writeBytes(byteArrayOf(1)) }
    val jar2 = tmp.newFile("ksp-api.jar").apply { writeBytes(byteArrayOf(2)) }

    val firstClassLoader = getKspClassLoader(listOf(jar1.absolutePath, jar2.absolutePath))
    val secondClassLoader = getKspClassLoader(listOf(jar2.absolutePath, jar1.absolutePath))

    assertThat(secondClassLoader).isSameInstanceAs(firstClassLoader)
  }

  @Test
  fun testKspClassLoaderCacheSeparatesDifferentProcessorClasspaths() {
    val jar1 = tmp.newFile("processor.jar").apply { writeBytes(byteArrayOf(1)) }
    val jar2 = tmp.newFile("ksp-api.jar").apply { writeBytes(byteArrayOf(2)) }
    val jar3 = tmp.newFile("other-processor.jar").apply { writeBytes(byteArrayOf(3)) }

    val firstClassLoader = getKspClassLoader(listOf(jar1.absolutePath, jar2.absolutePath))
    val secondClassLoader = getKspClassLoader(listOf(jar3.absolutePath, jar2.absolutePath))

    assertThat(secondClassLoader).isNotSameInstanceAs(firstClassLoader)
  }

  @Test
  fun testKspClassLoaderCacheInvalidatesOnContentChange() {
    val jar = tmp.newFile("processor.jar").apply { writeBytes(byteArrayOf(1, 2, 3)) }
    val classpath = listOf(jar.absolutePath)

    val firstClassLoader = getKspClassLoader(classpath)
    jar.writeBytes(byteArrayOf(4, 5, 6, 7))
    val secondClassLoader = getKspClassLoader(classpath)

    assertThat(secondClassLoader).isNotSameInstanceAs(firstClassLoader)
  }

  @Test
  fun testFingerprintIsDeterministic() {
    val jar = tmp.newFile("a.jar").apply { writeBytes(byteArrayOf(1, 2, 3)) }
    val classpath = listOf(jar.absolutePath)
    assertThat(fingerprintOf(classpath)).isEqualTo(fingerprintOf(classpath))
  }

  @Test
  fun testFingerprintChangesWhenContentChanges() {
    val jar = tmp.newFile("a.jar").apply { writeBytes(byteArrayOf(1, 2, 3)) }
    val classpath = listOf(jar.absolutePath)
    val before = fingerprintOf(classpath)

    jar.writeBytes(byteArrayOf(4, 5, 6, 7))
    val after = fingerprintOf(classpath)

    assertThat(after).isNotEqualTo(before)
  }

  @Test
  fun testFingerprintDiffersForDifferentPaths() {
    val jar1 = tmp.newFile("a.jar").apply { writeBytes(byteArrayOf(1, 2, 3)) }
    val jar2 = tmp.newFile("b.jar").apply { writeBytes(byteArrayOf(1, 2, 3)) }
    assertThat(fingerprintOf(listOf(jar1.absolutePath)))
      .isNotEqualTo(fingerprintOf(listOf(jar2.absolutePath)))
  }

  @Test
  fun testFingerprintIsHexEncoded() {
    val jar = tmp.newFile("a.jar").apply { writeBytes(byteArrayOf(1)) }
    val fp = fingerprintOf(listOf(jar.absolutePath))
    assertThat(fp).hasLength(64)
    assertThat(fp).matches("[0-9a-f]{64}")
  }
}
