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
package io.bazel.kotlin.builder.tasks.jvm.btapi

import com.google.common.truth.Truth.assertThat
import org.jetbrains.kotlin.buildtools.api.arguments.CompilerPlugin
import org.jetbrains.kotlin.buildtools.api.arguments.CompilerPluginOption
import org.jetbrains.kotlin.buildtools.api.arguments.CompilerPluginPartialOrder
import org.jetbrains.kotlin.buildtools.api.arguments.CompilerPluginPartialOrderRelation
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.JUnit4
import java.nio.file.Path
import kotlin.io.path.absolutePathString

@RunWith(JUnit4::class)
class BtapiPluginArgumentsTest {
  @Test
  fun `converts plugin classpath and options to raw argument strings`() {
    val firstJar = Path.of("plugin-one.jar").toAbsolutePath()
    val secondJar = Path.of("plugin-two.jar").toAbsolutePath()

    val args =
      BtapiPluginArguments.toArgumentStrings(
        listOf(
          CompilerPlugin(
            pluginId = "plugin.one",
            classpath = listOf(firstJar),
            rawArguments =
              listOf(
                CompilerPluginOption("opt1", "v1"),
                CompilerPluginOption("opt2", "v2"),
              ),
            orderingRequirements = emptySet(),
          ),
          CompilerPlugin(
            pluginId = "plugin.two",
            classpath = listOf(secondJar),
            rawArguments = listOf(CompilerPluginOption("flag", "true")),
            orderingRequirements = emptySet(),
          ),
        ),
      )

    assertThat(args).containsExactly(
      "-Xplugin=${firstJar.absolutePathString()},${secondJar.absolutePathString()}",
      "-P",
      "plugin:plugin.one:opt1=v1,plugin:plugin.one:opt2=v2,plugin:plugin.two:flag=true",
    ).inOrder()
  }

  @Test
  fun `preserves option flags without values`() {
    val pluginJar = Path.of("plugin.jar").toAbsolutePath()

    val args =
      BtapiPluginArguments.toArgumentStrings(
        listOf(
          CompilerPlugin(
            pluginId = "plugin.flag",
            classpath = listOf(pluginJar),
            rawArguments = listOf(CompilerPluginOption("enabled", "")),
            orderingRequirements = emptySet(),
          ),
        ),
      )

    assertThat(args).containsExactly(
      "-Xplugin=${pluginJar.absolutePathString()}",
      "-P",
      "plugin:plugin.flag:enabled",
    ).inOrder()
  }

  @Test
  fun `converts plugin order constraints`() {
    val firstJar = Path.of("plugin-one.jar").toAbsolutePath()
    val secondJar = Path.of("plugin-two.jar").toAbsolutePath()

    val args =
      BtapiPluginArguments.toArgumentStrings(
        listOf(
          CompilerPlugin(
            pluginId = "plugin.one",
            classpath = listOf(firstJar),
            rawArguments = emptyList(),
            orderingRequirements =
              setOf(
                CompilerPluginPartialOrder(
                  CompilerPluginPartialOrderRelation.BEFORE,
                  "plugin.two",
                ),
              ),
          ),
          CompilerPlugin(
            pluginId = "plugin.two",
            classpath = listOf(secondJar),
            rawArguments = emptyList(),
            orderingRequirements = emptySet(),
          ),
        ),
      )

    assertThat(args).containsExactly(
      "-Xplugin=${firstJar.absolutePathString()},${secondJar.absolutePathString()}",
      "-Xcompiler-plugin-order=plugin.one>plugin.two",
    ).inOrder()
  }

  @Test
  fun `filters btapi raw marker plugin`() {
    val args =
      BtapiPluginArguments.toArgumentStrings(
        listOf(
          CompilerPlugin(
            pluginId = "___RAW_PLUGINS_APPLIED___",
            classpath = emptyList(),
            rawArguments = emptyList(),
            orderingRequirements = emptySet(),
          ),
        ),
      )

    assertThat(args).isEmpty()
  }

  @Test
  fun `rejects plugin with empty id`() {
    val exception =
      org.junit.Assert.assertThrows(IllegalStateException::class.java) {
        BtapiPluginArguments.toArgumentStrings(
          listOf(
            CompilerPlugin(
              pluginId = " ",
              classpath = listOf(Path.of("plugin.jar").toAbsolutePath()),
              rawArguments = emptyList(),
              orderingRequirements = emptySet(),
            ),
          ),
        )
      }

    assertThat(exception).hasMessageThat().contains("plugin id is empty")
  }

  @Test
  fun `rejects plugin with empty classpath`() {
    val exception =
      org.junit.Assert.assertThrows(IllegalStateException::class.java) {
        BtapiPluginArguments.toArgumentStrings(
          listOf(
            CompilerPlugin(
              pluginId = "plugin.id",
              classpath = emptyList(),
              rawArguments = emptyList(),
              orderingRequirements = emptySet(),
            ),
          ),
        )
      }

    assertThat(exception).hasMessageThat().contains("has empty classpath")
  }

  @Test
  fun `AFTER ordering produces correct constraint string`() {
    val firstJar = Path.of("plugin-alpha.jar").toAbsolutePath()
    val secondJar = Path.of("plugin-beta.jar").toAbsolutePath()

    val args =
      BtapiPluginArguments.toArgumentStrings(
        listOf(
          CompilerPlugin(
            pluginId = "plugin.alpha",
            classpath = listOf(firstJar),
            rawArguments = emptyList(),
            orderingRequirements =
              setOf(
                CompilerPluginPartialOrder(
                  CompilerPluginPartialOrderRelation.AFTER,
                  "plugin.beta",
                ),
              ),
          ),
          CompilerPlugin(
            pluginId = "plugin.beta",
            classpath = listOf(secondJar),
            rawArguments = emptyList(),
            orderingRequirements = emptySet(),
          ),
        ),
      )

    // AFTER means "plugin.beta > plugin.alpha" (beta runs before alpha)
    assertThat(args).containsExactly(
      "-Xplugin=${firstJar.absolutePathString()},${secondJar.absolutePathString()}",
      "-Xcompiler-plugin-order=plugin.beta>plugin.alpha",
    ).inOrder()
  }

  @Test
  fun `multiple ordering constraints are deduplicated`() {
    val firstJar = Path.of("plugin-a.jar").toAbsolutePath()
    val secondJar = Path.of("plugin-b.jar").toAbsolutePath()

    // Both plugins declare that plugin.a should come before plugin.b.
    // plugin.a says BEFORE plugin.b, and plugin.b says AFTER plugin.a.
    // Both produce the same constraint string "plugin.a>plugin.b" and should be deduplicated.
    val args =
      BtapiPluginArguments.toArgumentStrings(
        listOf(
          CompilerPlugin(
            pluginId = "plugin.a",
            classpath = listOf(firstJar),
            rawArguments = emptyList(),
            orderingRequirements =
              setOf(
                CompilerPluginPartialOrder(
                  CompilerPluginPartialOrderRelation.BEFORE,
                  "plugin.b",
                ),
              ),
          ),
          CompilerPlugin(
            pluginId = "plugin.b",
            classpath = listOf(secondJar),
            rawArguments = emptyList(),
            orderingRequirements =
              setOf(
                CompilerPluginPartialOrder(
                  CompilerPluginPartialOrderRelation.AFTER,
                  "plugin.a",
                ),
              ),
          ),
        ),
      )

    // Both constraints resolve to "plugin.a>plugin.b", so dedup produces just one
    assertThat(args).containsExactly(
      "-Xplugin=${firstJar.absolutePathString()},${secondJar.absolutePathString()}",
      "-Xcompiler-plugin-order=plugin.a>plugin.b",
    ).inOrder()
  }

  @Test
  fun `plugins with no options produce no -P argument`() {
    val firstJar = Path.of("plugin-x.jar").toAbsolutePath()
    val secondJar = Path.of("plugin-y.jar").toAbsolutePath()

    val args =
      BtapiPluginArguments.toArgumentStrings(
        listOf(
          CompilerPlugin(
            pluginId = "plugin.x",
            classpath = listOf(firstJar),
            rawArguments = emptyList(),
            orderingRequirements = emptySet(),
          ),
          CompilerPlugin(
            pluginId = "plugin.y",
            classpath = listOf(secondJar),
            rawArguments = emptyList(),
            orderingRequirements = emptySet(),
          ),
        ),
      )

    // Should only have -Xplugin, no -P
    assertThat(args).containsExactly(
      "-Xplugin=${firstJar.absolutePathString()},${secondJar.absolutePathString()}",
    )
    assertThat(args).doesNotContain("-P")
  }

  @Test
  fun `plugin with multiple classpath jars lists all`() {
    val jar1 = Path.of("lib-a.jar").toAbsolutePath()
    val jar2 = Path.of("lib-b.jar").toAbsolutePath()
    val jar3 = Path.of("lib-c.jar").toAbsolutePath()

    val args =
      BtapiPluginArguments.toArgumentStrings(
        listOf(
          CompilerPlugin(
            pluginId = "multi.jar.plugin",
            classpath = listOf(jar1, jar2, jar3),
            rawArguments = listOf(CompilerPluginOption("key", "val")),
            orderingRequirements = emptySet(),
          ),
        ),
      )

    assertThat(args[0]).isEqualTo(
      "-Xplugin=${jar1.absolutePathString()},${jar2.absolutePathString()},${jar3.absolutePathString()}",
    )
  }
}
