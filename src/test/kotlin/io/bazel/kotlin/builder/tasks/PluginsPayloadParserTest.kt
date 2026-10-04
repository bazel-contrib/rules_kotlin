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
import io.bazel.kotlin.model.PluginPhase
import org.junit.Assert.fail
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.JUnit4

@RunWith(JUnit4::class)
class PluginsPayloadParserTest {
  @Test
  fun `parses plugins payload json`() {
    val plugins =
      PluginsPayloadParser.parse(
        """
        {
          "plugins": [
            {
              "id": "plugin.test",
              "classpath": ["a.jar", "b.jar"],
              "options": [
                {"key": "k1", "value": "v1"},
                {"key": "k2", "value": "v2"}
              ],
              "phases": ["PLUGIN_PHASE_COMPILE", "PLUGIN_PHASE_STUBS"]
            }
          ]
        }
        """.trimIndent(),
      )

    assertThat(plugins).hasSize(1)
    val plugin = plugins.single()
    assertThat(plugin.id).isEqualTo("plugin.test")
    assertThat(plugin.classpathList).containsExactly("a.jar", "b.jar").inOrder()
    assertThat(plugin.optionsList.map { "${it.key}=${it.value}" })
      .containsExactly("k1=v1", "k2=v2")
      .inOrder()
    assertThat(plugin.phasesList)
      .containsExactly(PluginPhase.PLUGIN_PHASE_COMPILE, PluginPhase.PLUGIN_PHASE_STUBS)
      .inOrder()
  }

  @Test
  fun `ignores unknown json fields`() {
    val plugins =
      PluginsPayloadParser.parse(
        """
        {
          "unknown_top_level": "ignored",
          "plugins": [
            {
              "id": "plugin.unknown",
              "classpath": [],
              "options": [],
              "phases": ["PLUGIN_PHASE_COMPILE"],
              "unknown_nested": "ignored"
            }
          ]
        }
        """.trimIndent(),
      )

    assertThat(plugins).hasSize(1)
    assertThat(plugins.single().id).isEqualTo("plugin.unknown")
  }

  @Test
  fun `silently drops unknown phase enum names`() {
    // JsonFormat's ignoringUnknownFields() also ignores unknown enum VALUES: an unrecognized
    // phase name is dropped rather than rejected. Pinned so a protobuf behavior change (or a
    // stricter parser) surfaces here instead of as a silent contract shift.
    val plugins =
      PluginsPayloadParser.parse(
        """
        {"plugins": [{"id": "p", "classpath": [], "options": [], "phases": ["PLUGIN_PHASE_BOGUS"]}]}
        """.trimIndent(),
      )

    assertThat(plugins.single().phasesList).isEmpty()
  }

  @Test
  fun `parses an empty payload object to no plugins`() {
    assertThat(PluginsPayloadParser.parse("{}")).isEmpty()
  }

  @Test
  fun `rejects invalid json`() {
    try {
      PluginsPayloadParser.parse("{invalid")
      fail("Expected parse to fail")
    } catch (e: IllegalArgumentException) {
      assertThat(e).hasMessageThat().contains("invalid plugins payload JSON")
    }
  }
}
