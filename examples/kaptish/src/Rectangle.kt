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
 * An immutable rectangle value class generated via AutoValue.
 *
 * With kaptish, AutoValue generates AutoValue_Rectangle without KAPT stubs:
 * 1. kotlinc compiles Rectangle.kt → Rectangle.class
 * 2. KotlinClassInjectorPlugin injects Rectangle into javac's AP phase
 * 3. AutoValueProcessor generates AutoValue_Rectangle.java
 */
@AutoValue
abstract class Rectangle {
  abstract fun width(): Double
  abstract fun height(): Double

  fun area(): Double = width() * height()
  fun perimeter(): Double = 2.0 * (width() + height())
}
