/*
 * Copyright 2026 The Bazel Authors. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package io.bazel.kotlin

import org.junit.Test
import java.util.jar.JarFile

/**
 * The compiler-dialect re-shading rules relocate exactly the packages the target dialect shades.
 *
 * The embeddable compiler shades `com.intellij`, `com.google.common`, and `kotlinx.collections`
 * (the immutable collections library). It does not shade `kotlinx.serialization`: a compiler plugin
 * that refers to the serialization runtime must keep those references, otherwise the plugin cannot
 * resolve the runtime and generates nothing.
 */
class ReshadeRulesAssertionTest : KotlinAssertionTestCase("src/test/data/jvm/reshade") {
  @Test
  fun testEmbeddableRulesRelocateOnlyTheShadedPackages() {
    jarTestCase(
      "dialect_fixture_embeddable_reshaded.jar",
      description = "re-shading to the embeddable dialect keeps kotlinx.serialization in place",
    ) {
      assertContainsEntries(
        "kotlinx/serialization/SerializationStub.class",
        "org/jetbrains/kotlin/kotlinx/collections/immutable/ImmutableStub.class",
        "org/jetbrains/kotlin/com/intellij/IntellijStub.class",
        "org/jetbrains/kotlin/google/common/GuavaStub.class",
        "plugin/PluginStub.class",
      )
      assertDoesNotContainEntries(
        "org/jetbrains/kotlin/kotlinx/serialization/SerializationStub.class",
        "kotlinx/collections/immutable/ImmutableStub.class",
        "com/intellij/IntellijStub.class",
        "com/google/common/GuavaStub.class",
      )
      val references = classFileText("plugin/PluginStub.class")
      check("Lkotlinx/serialization/SerializationStub;" in references) {
        "the reference to the serialization runtime must stay unchanged"
      }
      check("org/jetbrains/kotlin/kotlinx/serialization" !in references) {
        "the reference to the serialization runtime must not be relocated"
      }
      check("Lorg/jetbrains/kotlin/kotlinx/collections/immutable/ImmutableStub;" in references) {
        "the reference to the immutable collections library must be relocated"
      }
    }
  }

  @Test
  fun testDistributionRulesRestoreTheShadedPackages() {
    jarTestCase(
      "dialect_fixture_dist_reshaded.jar",
      description = "re-shading to the CLI-distribution dialect keeps kotlinx.serialization in place",
    ) {
      assertContainsEntries(
        "kotlinx/serialization/SerializationStub.class",
        "kotlinx/collections/immutable/ShadedImmutableStub.class",
        "com/intellij/ShadedIntellijStub.class",
        "org/jetbrains/kotlin/google/common/GuavaStub.class",
        "kotlinx/collections/immutable/ImmutableStub.class",
        "com/intellij/IntellijStub.class",
      )
      assertDoesNotContainEntries(
        "org/jetbrains/kotlin/kotlinx/collections/immutable/ShadedImmutableStub.class",
        "org/jetbrains/kotlin/com/intellij/ShadedIntellijStub.class",
        "com/google/common/GuavaStub.class",
      )
      val references = classFileText("plugin/PluginStub.class")
      check("Lkotlinx/serialization/SerializationStub;" in references) {
        "the reference to the serialization runtime must stay unchanged"
      }
    }
  }

  /** The class file bytes as ISO-8859-1 text, so that constant-pool names are searchable. */
  private fun JarFile.classFileText(entry: String): String =
    getInputStream(getJarEntry(entry)).use { String(it.readBytes(), Charsets.ISO_8859_1) }
}
