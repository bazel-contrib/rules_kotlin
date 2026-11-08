// Copyright 2026 The Bazel Authors. All rights reserved.
// SPDX-License-Identifier: Apache-2.0
package io.bazel.kotlin.coverage

import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class KoverLcovTest {
  @get:Rule val tmp = TemporaryFolder()

  private fun write(
    name: String,
    text: String,
  ): File = tmp.newFile(name).apply { writeText(text) }

  @Test
  fun mapsSourcesToManifestExecPaths() {
    val manifest =
      write(
        "manifest",
        "src/demo/first/Same.kt\nbazel-out/cfg/bin/gen/demo/second/Same.kt\nTop.kt\nsrc/flat/Other.kt\n",
      )
    val xml =
      write(
        "coverage.xml",
        """
        <report>
          <package name="demo/first"><sourcefile name="Same.kt">
            <line nr="7" mi="0" ci="6"/><line nr="8" mi="0" ci="0"/>
          </sourcefile></package>
          <package name="demo/second"><sourcefile name="Same.kt">
            <line nr="9" mi="4" ci="0"/>
          </sourcefile></package>
          <package name=""><sourcefile name="Top.kt"><line nr="1" mi="0" ci="1"/></sourcefile></package>
          <!-- Not in the manifest (uninstrumented dependency or package/directory mismatch): dropped. -->
          <package name="org/junit"><sourcefile name="Assert.java"><line nr="1" mi="1" ci="0"/></sourcefile></package>
          <package name="com/flat"><sourcefile name="Other.kt"><line nr="1" mi="1" ci="0"/></sourcefile></package>
        </report>
        """.trimIndent(),
      )
    val output = File(tmp.root, "kover.dat")

    KoverLcov.main(arrayOf(xml.path, manifest.path, output.path))

    assertEquals(
      "SF:src/demo/first/Same.kt\nDA:7,1\nend_of_record\n" +
        "SF:bazel-out/cfg/bin/gen/demo/second/Same.kt\nDA:9,0\nend_of_record\n" +
        "SF:Top.kt\nDA:1,1\nend_of_record\n",
      output.readText(),
    )
  }
}
