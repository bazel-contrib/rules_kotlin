package io.bazel.kotlin.builder.tasks.jvm

import com.google.common.truth.Truth.assertThat
import io.bazel.kotlin.builder.toolchain.ToolchainSpec
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.JUnit4
import java.nio.file.Path

@RunWith(JUnit4::class)
class ToolchainSpecTest {
  @Test
  fun `equality is based on all fields`() {
    val spec1 = spec(btapiClasspath = listOf(Path.of("/a.jar"), Path.of("/b.jar")))
    val spec2 = spec(btapiClasspath = listOf(Path.of("/a.jar"), Path.of("/b.jar")))
    val spec3 = spec(btapiClasspath = listOf(Path.of("/a.jar"), Path.of("/c.jar")))

    assertThat(spec1).isEqualTo(spec2)
    assertThat(spec1.hashCode()).isEqualTo(spec2.hashCode())
    assertThat(spec1).isNotEqualTo(spec3)
  }

  @Test
  fun `classpath order matters for equality`() {
    val spec1 = spec(btapiClasspath = listOf(Path.of("/a.jar"), Path.of("/b.jar")))
    val spec2 = spec(btapiClasspath = listOf(Path.of("/b.jar"), Path.of("/a.jar")))

    assertThat(spec1).isNotEqualTo(spec2)
  }

  @Test
  fun `different plugin jars produce different specs`() {
    val spec1 = spec(jdepsJar = Path.of("/jdeps-v1.jar"))
    val spec2 = spec(jdepsJar = Path.of("/jdeps-v2.jar"))

    assertThat(spec1).isNotEqualTo(spec2)
  }

  private fun spec(
    btapiClasspath: List<Path> = emptyList(),
    jdepsJar: Path = Path.of("/jdeps.jar"),
    abiGenJar: Path = Path.of("/abi-gen.jar"),
    skipCodeGenJar: Path = Path.of("/skip-code-gen.jar"),
    kaptJar: Path = Path.of("/kapt.jar"),
  ) = ToolchainSpec(btapiClasspath, jdepsJar, abiGenJar, skipCodeGenJar, kaptJar)
}
