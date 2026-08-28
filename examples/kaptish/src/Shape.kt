// Copyright 2026 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
package example.kaptish

import com.google.auto.value.AutoValue

/**
 * An immutable shape value class, generated via AutoValue.
 *
 * With kaptish, AutoValue generates AutoValue_Shape without KAPT stub generation:
 * 1. kotlinc compiles Shape.kt → Shape.class
 * 2. KotlinClassInjectorPlugin injects Shape into javac's annotation processing phase
 * 3. AutoValueProcessor generates AutoValue_Shape.java from the compiled class
 * 4. javac compiles AutoValue_Shape.java
 *
 * Note: Because Kotlin compiles before annotation processing runs, the generated
 * AutoValue_Shape class is not visible to Kotlin code at compile time. Reference
 * generated classes from Java, or access them via the abstract factory pattern.
 */
@AutoValue
abstract class Shape {
  abstract fun name(): String
  abstract fun sides(): Int
}
