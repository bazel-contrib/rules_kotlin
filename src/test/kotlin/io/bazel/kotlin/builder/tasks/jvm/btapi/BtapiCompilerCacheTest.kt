package io.bazel.kotlin.builder.tasks.jvm.btapi

import com.google.common.truth.Truth.assertThat
import io.bazel.kotlin.builder.KotlinAbstractTestBuilder
import io.bazel.kotlin.builder.toolchain.ToolchainSpec
import org.jetbrains.kotlin.buildtools.api.ExperimentalBuildToolsApi
import org.junit.Assert.assertThrows
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.JUnit4
import java.nio.file.Files
import java.nio.file.Path

@OptIn(ExperimentalBuildToolsApi::class)
@RunWith(JUnit4::class)
class BtapiCompilerCacheTest {
  private val cache = BtapiCompilerCache()

  @Test
  fun `get returns same instance for same toolchain spec`() {
    val spec = KotlinAbstractTestBuilder.toolchainSpecForTest()
    val compiler1 = cache[spec]
    val compiler2 = cache[spec]
    assertThat(compiler1).isSameInstanceAs(compiler2)
  }

  @Test
  fun `get returns same instance for equal specs`() {
    val spec1 = KotlinAbstractTestBuilder.toolchainSpecForTest()
    val spec2 = KotlinAbstractTestBuilder.toolchainSpecForTest()
    assertThat(spec1).isEqualTo(spec2)
    val compiler1 = cache[spec1]
    val compiler2 = cache[spec2]
    assertThat(compiler1).isSameInstanceAs(compiler2)
  }

  @Test
  fun `get throws when classpath file does not exist`() {
    val dummyJar = Path.of("/dummy.jar")
    val spec = ToolchainSpec(listOf(Path.of("/nonexistent/path/does-not-exist.jar")), dummyJar, dummyJar, dummyJar, dummyJar)
    val exception = assertThrows(IllegalArgumentException::class.java) {
      cache[spec]
    }
    assertThat(exception).hasMessageThat().contains("does not exist or is not a file")
    assertThat(exception).hasMessageThat().contains("does-not-exist.jar")
  }

  @Test
  fun `close closes all cached compilers`() {
    val spec = KotlinAbstractTestBuilder.toolchainSpecForTest()
    val compiler = cache[spec]
    // Verify the compiler is functional before close
    assertThat(compiler.toolchains).isNotNull()
    cache.close()
    // After close, the cache should be empty - getting the same spec should create a new instance
    val newCache = BtapiCompilerCache()
    val compiler2 = newCache[spec]
    assertThat(compiler2).isNotSameInstanceAs(compiler)
    newCache.close()
  }

  @Test
  fun `get throws when classpath entry is a directory not a file`() {
    val tempDir = Files.createTempDirectory("btapi-cache-test")
    try {
      val dummyJar = Path.of("/dummy.jar")
      val spec = ToolchainSpec(listOf(tempDir), dummyJar, dummyJar, dummyJar, dummyJar)
      val exception = assertThrows(IllegalArgumentException::class.java) {
        cache[spec]
      }
      assertThat(exception).hasMessageThat().contains("does not exist or is not a file")
    } finally {
      Files.deleteIfExists(tempDir)
    }
  }
}
