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

class JavacJvmTargetAssertionTest : KotlinAssertionTestCase("src/test/data/jvm/jvm_target") {
  @Test
  fun javaHalfIsCompiledForTheKotlincJvmTarget() {
    jarTestCase(
      "mixed_jvm8.jar",
      description = "In a mixed Kotlin/Java target the Java sources must compile to the same " +
        "bytecode version as the kotlinc jvm_target",
    ) {
      // The Java half must follow the kotlinc jvm_target (1.8 -> major 52), not the pinned default.
      assertEquals(
        52,
        classFileMajorVersion("mixed/MixedJava.class"),
        "Java half was not compiled for jvm_target=1.8 (it followed java_language_version instead)",
      )
      // Both halves must target the same platform.
      assertEquals(
        classFileMajorVersion("mixed/Mixed.class"),
        classFileMajorVersion("mixed/MixedJava.class"),
        "Kotlin and Java halves produced different bytecode versions",
      )
    }
  }
}
