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
package tests.smoke.kaptish.kotlin

import com.google.auto.value.AutoValue

/**
 * Test class for kaptish annotation processing.
 * AutoValue should generate AutoValue_TestKaptishValue class.
 *
 * Note: In kaptish mode, Kotlin code cannot directly reference generated classes
 * because Kotlin compiles first before AP runs. The generated class is accessed
 * via reflection or from Java code.
 */
@AutoValue
abstract class TestKaptishValue {
    abstract fun name(): String
    abstract fun value(): Int

    @AutoValue.Builder
    abstract class Builder {
        abstract fun setName(name: String): Builder
        abstract fun setValue(value: Int): Builder
        abstract fun build(): TestKaptishValue
    }
}
