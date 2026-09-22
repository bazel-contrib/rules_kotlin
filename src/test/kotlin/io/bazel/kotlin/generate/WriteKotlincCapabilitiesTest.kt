package io.bazel.kotlin.generate

import com.google.common.truth.Truth.assertThat
import io.bazel.kotlin.generate.WriteKotlincCapabilities
import org.junit.Test
import java.nio.file.Files

class WriteKotlincCapabilitiesTest {
  @Test
  fun smokeTest() {
    var tmp = Files.createTempDirectory("WriteKotlincCapabilitiesTest")
    WriteKotlincCapabilities.main("--out", tmp.toString())
    val got = tmp.resolve(WriteKotlincCapabilities.capabilitiesName)
    assertThat(Files.exists(got)).isTrue()
    // assert stable flag
    assertThat(Files.readString(got)).contains("-Werror")

    println(Files.readString(got))

  }
}
