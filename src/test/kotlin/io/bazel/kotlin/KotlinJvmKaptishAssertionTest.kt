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

/**
 * Tests for kaptish annotation processing mode.
 *
 * Kaptish is an experimental optimization that skips KAPT stub generation.
 * When enabled via `experimental_kaptish_enabled = True` in the toolchain:
 * - Kotlin compiles first to .class files
 * - The kaptish annotation processor injects Kotlin class names into javac's AP phase
 * - Annotation processors run on the compiled Kotlin classes (no stubs needed)
 * - The `kaptish_disabled` tag can be used to opt-out per target (falls back to KAPT)
 *
 * To run these tests with kaptish enabled:
 *   bazel test //src/test/kotlin/io/bazel/kotlin:KotlinJvmKaptishAssertionTest \
 *     --extra_toolchains=//src/test/data/jvm/kaptish:kaptish_toolchain
 */
class KotlinJvmKaptishAssertionTest : KotlinAssertionTestCase("src/test/data/jvm/kaptish") {

    @Test
    fun testKaptishKotlinCompilesSuccessfully() {
        // Kaptish mode should compile Kotlin classes AND run annotation processors
        jarTestCase("kaptish_kotlin.jar", description = "kaptish mode compiles Kotlin and runs AP") {
            assertContainsEntries(
                "tests/smoke/kaptish/kotlin/TestKaptishValue.class",
                "tests/smoke/kaptish/kotlin/TestKaptishValue\$Builder.class",
                // AutoValue generated classes - proves AP ran on Kotlin classes via kaptish
                "tests/smoke/kaptish/kotlin/AutoValue_TestKaptishValue.class",
                "tests/smoke/kaptish/kotlin/AutoValue_TestKaptishValue\$Builder.class"
            )
        }
    }

    @Test
    fun testKaptishKotlinResourcesCompilesSuccessfully() {
        // Kaptish mode should compile Kotlin classes successfully
        jarTestCase(
            "kaptish_kotlin_resources.jar",
            description = "kaptish mode compiles Kotlin with service annotations"
        ) {
            assertContainsEntries("tests/smoke/kaptish/kotlin/TestKaptishService.class")
        }
    }

    @Test
    fun testKaptishDisabledFallsBackToKapt() {
        // When kaptish_disabled tag is present, KAPT should run and generate classes
        jarTestCase(
            "kaptish_disabled.jar",
            description = "kaptish_disabled tag falls back to KAPT and generates AP code"
        ) {
            assertContainsEntries(
                "tests/smoke/kaptish/kotlin/TestKaptishValue.class",
                "tests/smoke/kaptish/kotlin/AutoValue_TestKaptishValue.class",
                "tests/smoke/kaptish/kotlin/AutoValue_TestKaptishValue\$Builder.class"
            )
        }
    }
}
