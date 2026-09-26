package io.bazel.kotlin.builder.utils.jars

import com.google.common.truth.Truth.assertThat
import io.bazel.testing.Temporary
import org.junit.Test
import java.util.zip.ZipEntry
import java.util.zip.ZipFile

class JarCreatorTest {
  @Test fun createDirectories() {
    val root = Temporary.directoryFor<JarCreatorTest> {
      file("ibbity/bibbity/zibbity.zee", "Hellity, crackity, bumble-bee.")
    }

    val got = Temporary.directoryFor<JarCreatorTest>().resolve("out.jar").apply {
      JarCreator(this).use { it.addDirectory(root) }
    }

    assertThat(
      ZipFile(got.toFile()).entries().asSequence().map { it.name }.toSet()
    ).containsExactly(
      "META-INF/", "META-INF/MANIFEST.MF", "ibbity/", "ibbity/bibbity/",
      "ibbity/bibbity/zibbity.zee"
    )
    ZipFile(got.toFile()).use { jar ->
      assertThat(jar.getEntry("META-INF/MANIFEST.MF").method).isEqualTo(ZipEntry.STORED)
      val entry = jar.getEntry("ibbity/bibbity/zibbity.zee")
      assertThat(entry.method).isEqualTo(ZipEntry.DEFLATED)
      assertThat(jar.getInputStream(entry).bufferedReader().use { it.readText() })
        .isEqualTo("Hellity, crackity, bumble-bee.")
    }
  }
}
