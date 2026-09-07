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

import com.google.auto.service.AutoService

/**
 * Test interface for kaptish resource generation.
 */
interface KaptishService {
    fun serve(): String
}

/**
 * Test class for kaptish annotation processing with resource generation.
 * AutoService should generate META-INF/services file.
 */
@AutoService(KaptishService::class)
class TestKaptishService : KaptishService {
    override fun serve(): String = "kaptish"
}
