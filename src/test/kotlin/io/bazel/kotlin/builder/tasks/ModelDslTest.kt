package io.bazel.kotlin.builder.tasks

import com.google.common.truth.Truth.assertThat
import io.bazel.kotlin.model.BtapiRuntime
import io.bazel.kotlin.model.Common
import io.bazel.kotlin.model.CompilationTaskInfo
import io.bazel.kotlin.model.Directories
import io.bazel.kotlin.model.Inputs
import io.bazel.kotlin.model.Jvm
import io.bazel.kotlin.model.JvmCompilationTask
import io.bazel.kotlin.model.KotlinToolchainInfo
import io.bazel.kotlin.model.Outputs
import io.bazel.kotlin.model.Plugin
import io.bazel.kotlin.model.PluginOption
import io.bazel.kotlin.model.PluginPhase
import org.junit.Test

class ModelDslTest {
  @Test
  fun defaultsMatchConstructors() {
    assertThat(JvmCompilationTask {}).isEqualTo(JvmCompilationTask())
    assertThat(CompilationTaskInfo {}).isEqualTo(CompilationTaskInfo())
    assertThat(KotlinToolchainInfo {}).isEqualTo(KotlinToolchainInfo())
    assertThat(Common {}).isEqualTo(Common())
    assertThat(Jvm {}).isEqualTo(Jvm())
    assertThat(BtapiRuntime {}).isEqualTo(BtapiRuntime())
    assertThat(Directories {}).isEqualTo(Directories())
    assertThat(Outputs {}).isEqualTo(Outputs())
    assertThat(Inputs {}).isEqualTo(Inputs())
    assertThat(Plugin {}).isEqualTo(Plugin())
    assertThat(PluginOption {}).isEqualTo(PluginOption())
  }

  @Test
  fun nestedBlocksPreserveExistingConfiguration() {
    val original = CompilationTaskInfo {
      label = "//example:library"
      friendPathsList += "friend.jar"
      toolchainInfo {
        common { languageVersion = "2.2" }
        btapi { apiImplClasspathList += "compiler.jar" }
      }
    }
    val task = JvmCompilationTask {
      info = original
      info {
        toolchainInfo {
          common { apiVersion = "2.1" }
          jvm { jvmTarget = "17" }
          btapi { classpathFingerprint = "fingerprint" }
        }
      }
      outputs { jar = "library.jar" }
      directories { classes = "classes" }
      inputs {
        kotlinSourcesList += "Library.kt"
        pluginsList += Plugin {
          id = "example"
          optionsList += PluginOption {
            key = "enabled"
            value = "true"
          }
          phasesList += PluginPhase.PLUGIN_PHASE_COMPILE
        }
      }
      compileKotlin = true
    }

    assertThat(task.info.label).isEqualTo(original.label)
    assertThat(task.info.friendPathsList).containsExactly("friend.jar")
    assertThat(task.info.toolchainInfo.common).isEqualTo(Common("2.2", "2.1"))
    assertThat(task.info.toolchainInfo.jvm.jvmTarget).isEqualTo("17")
    assertThat(task.info.toolchainInfo.btapi?.apiImplClasspathList).containsExactly("compiler.jar")
    assertThat(task.info.toolchainInfo.btapi?.classpathFingerprint).isEqualTo("fingerprint")
    assertThat(original.toolchainInfo.common.apiVersion).isEmpty()
    assertThat(original.toolchainInfo.btapi?.classpathFingerprint).isEmpty()
    assertThat(task.outputs.jar).isEqualTo("library.jar")
    assertThat(task.directories.classes).isEqualTo("classes")
    assertThat(task.inputs.kotlinSourcesList).containsExactly("Library.kt")
    assertThat(task.inputs.pluginsList.single().optionsList)
      .containsExactly(PluginOption("enabled", "true"))
    assertThat(task.compileKotlin).isTrue()
  }

  @Test
  fun collectionSnapshotsSurviveBuilderReuseAndSelfReplacement() {
    val paths = mutableListOf("first.jar")
    val original = Inputs(classpathList = paths)
    val builder = Inputs.Builder(original)
    builder.classpathList(builder.classpathList)
    val first = builder.build()
    paths.clear()
    builder.classpathList += "second.jar"

    assertThat(first.classpathList).containsExactly("first.jar")
    assertThat(builder.build().classpathList).containsExactly("first.jar", "second.jar").inOrder()
  }
}
