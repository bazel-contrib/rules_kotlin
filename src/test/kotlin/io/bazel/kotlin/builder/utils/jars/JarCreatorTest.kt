package io.bazel.kotlin.builder.utils.jars

import com.google.common.truth.Truth.assertThat
import io.bazel.testing.Temporary
import org.junit.Test
import java.time.LocalDateTime
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

  @Test fun normalizedTimestampsMatchSinglejar() {
    val root = Temporary.directoryFor<JarCreatorTest> {
      file("pkg/A.class", "class")
      file("pkg/res.txt", "resource")
    }

    val got = Temporary.directoryFor<JarCreatorTest>().resolve("out.jar").apply {
      JarCreator(this).use { it.addDirectory(root) }
    }

    // singlejar --normalize writes the DOS date 2010-01-01 with time 00:00:00, and 00:00:02 for a .class
    // entry, and no extended timestamp extra field.
    val epoch = LocalDateTime.of(2010, 1, 1, 0, 0, 0)
    ZipFile(got.toFile()).use { jar ->
      for (name in listOf("META-INF/", "META-INF/MANIFEST.MF", "pkg/", "pkg/res.txt")) {
        assertThat(jar.getEntry(name).timeLocal).isEqualTo(epoch)
      }
      assertThat(jar.getEntry("pkg/A.class").timeLocal).isEqualTo(epoch.plusSeconds(2))
      for (entry in jar.entries()) {
        assertThat(extraFieldIds(entry.extra)).doesNotContain(EXTENDED_TIMESTAMP_ID)
      }
    }
  }

  private companion object {
    const val EXTENDED_TIMESTAMP_ID = 0x5455

    /** The header ids of the extra fields of a zip entry: each field is id, size (both little endian), data. */
    fun extraFieldIds(extra: ByteArray?): List<Int> {
      val ids = mutableListOf<Int>()
      var offset = 0
      while (extra != null && offset + 4 <= extra.size) {
        ids += (extra[offset].toInt() and 0xff) or ((extra[offset + 1].toInt() and 0xff) shl 8)
        offset += 4 + ((extra[offset + 2].toInt() and 0xff) or ((extra[offset + 3].toInt() and 0xff) shl 8))
      }
      return ids
    }
  }
}
