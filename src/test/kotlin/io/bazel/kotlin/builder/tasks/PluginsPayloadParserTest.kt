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
import io.bazel.kotlin.model.JvmCompilationTask
import org.junit.Assert.fail
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.JUnit4

@RunWith(JUnit4::class)
class PluginsPayloadParserTest {
  @Test
  fun `parses the plugins payload text format`() {
    // The line plugin_payload_test.bzl expects from the producer for the same plugin, so that the
    // producer's output and the parser stay locked to one contract.
    val plugins =
      PluginsPayloadParser.parse(
        """plugins { classpath: "a.jar" classpath: "b.jar" id: "plugin.test" options { key: "k1" value: "v1" } options { key: "k2" value: "v2" } phases: PLUGIN_PHASE_COMPILE phases: PLUGIN_PHASE_STUBS }""",
      )

    assertThat(plugins).hasSize(1)
    val plugin = plugins.single()
    assertThat(plugin.id).isEqualTo("plugin.test")
    assertThat(plugin.classpathList).containsExactly("a.jar", "b.jar").inOrder()
    assertThat(plugin.optionsList.map { "${it.key}=${it.value}" })
      .containsExactly("k1=v1", "k2=v2")
      .inOrder()
    assertThat(plugin.phasesList)
      .containsExactly(
        JvmCompilationTask.Inputs.PluginPhase.PLUGIN_PHASE_COMPILE,
        JvmCompilationTask.Inputs.PluginPhase.PLUGIN_PHASE_STUBS,
      )
      .inOrder()
  }

  @Test
  fun `unescapes string literals`() {
    // The producer escapes backslashes, quotes and newlines in strings the way JSON does; text format reads them.
    val plugin =
      PluginsPayloadParser
        .parse("""plugins { id: "q\"uo\\te" options { key: "k" value: "a=b\n" } options { key: "e" value: "" } }""")
        .single()

    assertThat(plugin.id).isEqualTo("q\"uo\\te")
    assertThat(plugin.optionsList.map { "${it.key}=${it.value}" }).containsExactly("k=a=b\n", "e=").inOrder()
  }

  @Test
  fun `parses an empty payload to no plugins`() {
    assertThat(PluginsPayloadParser.parse("")).isEmpty()
  }

  @Test
  fun `rejects unknown fields`() {
    assertRejected("""plugins { id: "p" unknown: "x" }""")
  }

  @Test
  fun `rejects unknown phase names`() {
    assertRejected("""plugins { id: "p" phases: PLUGIN_PHASE_BOGUS }""")
  }

  @Test
  fun `rejects malformed text`() {
    assertRejected("plugins {")
  }

  private fun assertRejected(text: String) {
    try {
      PluginsPayloadParser.parse(text)
      fail("Expected parse to fail")
    } catch (e: IllegalArgumentException) {
      assertThat(e).hasMessageThat().contains("invalid plugins payload")
    }
  }
}
