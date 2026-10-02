/*
 * Copyright 2026 The Bazel Authors. All rights reserved.
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
import io.bazel.kotlin.builder.utils.BazelRunFiles
import io.bazel.kotlin.model.JvmCompilationTask.Inputs.PluginPhase
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.JUnit4

/**
 * payload.bzl maps the rules' phase names to the values of [PluginPhase] in a table, because Starlark cannot read
 * the proto definition. This test checks that the table and the enum are structurally equivalent.
 */
@RunWith(JUnit4::class)
class PluginsPayloadPhaseNamesTest {
  @Test
  fun `the values of the phase table are the constants of PluginPhase`() {
    val tableValues =
      BazelRunFiles
        .resolveVerifiedFromProperty("..src.test.kotlin.io.bazel.kotlin.builder.tasks.plugin_phase_names")
        .readLines()
        .filter { it.isNotEmpty() }

    val enumConstants = PluginPhase.getDescriptor().values.filter { it.number != 0 }.map { it.name }

    assertThat(tableValues).containsExactlyElementsIn(enumConstants)
  }
}
