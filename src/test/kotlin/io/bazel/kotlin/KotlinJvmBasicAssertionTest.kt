/*
 * Copyright 2018 The Bazel Authors. All rights reserved.
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
import kotlin.test.assertEquals

class KotlinJvmBasicAssertionTest : KotlinAssertionTestCase("src/test/data/jvm/basic") {
  @Test
  fun testResourceMerging() {
    jarTestCase(
      "test_embed_resources.jar",
      description = "The rules should support including resource directories"
    ) {
      assertContainsEntries(
        "testresources/AClass.class",
        "testresources/BClass.class",
        "src/test/data/jvm/basic/testresources/resources/one/alsoAFile.txt",
        "src/test/data/jvm/basic/testresources/resources/one/two/aFile.txt"
      )
    }
    jarTestCase(
      "test_merge_resourcesjar.jar",
      description = "the rules should support merging jars"
    ) {
      assertContainsEntries(
        "testresources/AClass.class",
        "testresources/BClass.class",
        "pkg/file.txt"
      )
    }
    jarTestCase(
      "test_embed_resources_strip_prefix.jar",
      description = "the rules should support the resource_strip_prefix attribute"
    ) {
      assertContainsEntries(
        "testresources/",
        "testresources/AClass.class",
        "testresources/BClass.class",
        "one/",
        "one/alsoAFile.txt",
        "one/two/",
        "one/two/aFile.txt",
      )
    }
    jarTestCase(
      "conventional_strip_resources.jar",
      description = "the rules should support conventional prefix stripping"
    ) {
      assertContainsEntries("java_main.txt", "java_test.txt", "main.txt", "test.txt")
    }
  }

  @Test
  fun testSrcJarGeneration() {
    jarTestCase(
      "test_module_name_lib-sources.jar",
      description = "The rules should generate a source jar"
    ) {
      assertContainsEntries(
        "test/data/jvm/basic/helloworld/Main.kt"
      )
    }
  }

  @Test
  fun testPropogateDeps() {
    assertExecutableRunfileSucceeds(
      "propagation_rt_via_export_consumer",
      description = "Runtime deps should be inherited transitively from `exported` deps"
    )
    assertExecutableRunfileSucceeds(
      "propagation_rt_via_runtime_deps_consumer",
      description = "Runtime deps should be inherited transitively from `runtime_deps`"
    )
  }

  @Test
  fun testModuleNaming() {
    jarTestCase(
      "test_module_name_bin.jar",
      description = "A binary rule should support default module naming"
    ) {
      assertContainsEntries("META-INF/src_test_data_jvm_basic-test_module_name_bin.kotlin_module")
    }
    jarTestCase(
      "test_module_name_lib.jar",
      description = "A library rule should support default module naming"
    ) {
      assertContainsEntries("META-INF/src_test_data_jvm_basic-test_module_name_lib.kotlin_module")
    }
    jarTestCase(
      "test_module_name_attr_lib.jar",
      description = "The kotlin rules should support the module_name attribute"
    ) {
      assertContainsEntries("META-INF/hello-module.kotlin_module")
    }
  }

  @Test
  fun testBuilderWrittenJarStampsTheFoldedTargetLabel() {
    // test_embed_resources has resources, so singlejar folds its jar; test_module_name_lib is Kotlin only, so the
    // KotlinBuilder writes its jar and no fold runs. Both jars spell Target-Label the same way.
    var folded = ""
    jarTestCase("test_embed_resources.jar", description = "A folded jar should be stamped") {
      folded = checkNotNull(manifest.mainAttributes.getValue("Target-Label"))
    }
    check(folded.endsWith("//src/test/data/jvm/basic:test_embed_resources")) { "unexpected folded label $folded" }
    jarTestCase(
      "test_module_name_lib.jar",
      description = "A jar the KotlinBuilder writes should carry the Target-Label spelling of a folded jar",
    ) {
      assertEquals(
        folded.replace(":test_embed_resources", ":test_module_name_lib"),
        manifest.mainAttributes.getValue("Target-Label"),
      )
    }
  }

  @Test
  fun testBuilderWrittenJarHasTheFoldedEntryTimestamps() {
    // The DOS date and time of each entry kind, as singlejar --normalize writes them in a folded jar.
    var folded = mapOf<String, Any>()
    jarTestCase("test_embed_resources.jar", description = "A folded jar should have normalized timestamps") {
      folded = mapOf(
        "class" to getJarEntry("testresources/AClass.class").timeLocal,
        "manifest" to getJarEntry("META-INF/MANIFEST.MF").timeLocal,
      )
    }
    jarTestCase(
      "test_module_name_lib.jar",
      description = "A jar the KotlinBuilder writes should have the entry timestamps of a folded jar",
    ) {
      assertEquals(folded["class"], getJarEntry("helloworld/Main.class").timeLocal)
      assertEquals(folded["manifest"], getJarEntry("META-INF/MANIFEST.MF").timeLocal)
      assertEquals(java.time.LocalDateTime.of(2010, 1, 1, 0, 0, 2), getJarEntry("helloworld/Main.class").timeLocal)
    }
  }

  @Test
  fun testManifestLines() {
    jarTestCase(
      "test_manifest_lines_lib.jar",
      description = "The manifest_lines attribute should reach the manifest of the output jar next to the rule attributes"
    ) {
      assertManifestStamped()
      val attributes = manifest.mainAttributes
      check(attributes.getValue("Main-Class") == "helloworld.Main") { "unexpected Main-Class: ${attributes.getValue("Main-Class")}" }
      check(attributes.getValue("Premain-Class") == "helloworld.Main") { "unexpected Premain-Class: ${attributes.getValue("Premain-Class")}" }
    }
  }
}
