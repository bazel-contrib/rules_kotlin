// Copyright 2026 The Bazel Authors. All rights reserved.
// SPDX-License-Identifier: Apache-2.0
package io.bazel.kotlin.coverage

import java.nio.file.Files
import java.nio.file.Paths
import javax.xml.stream.XMLInputFactory
import javax.xml.stream.XMLStreamConstants.END_ELEMENT
import javax.xml.stream.XMLStreamConstants.START_ELEMENT

/**
 * Converts a Kover XML report to an LCOV fragment for Bazel's coverage merger.
 *
 * Usage: `KoverLcov <kover.xml> <coverage manifest> <output.dat>`
 *
 * Source files are matched to the exec paths in Bazel's coverage manifest by `package/File.kt`
 * suffix, the same rule Bazel's JaCoCo LCOV formatter uses. Sources whose directory doesn't end in
 * their package path are dropped; supporting them would need the builder to emit an explicit
 * source-to-package map.
 */
object KoverLcov {
  @JvmStatic
  fun main(args: Array<String>) {
    val (report, manifestFile, outputFile) = args
    val manifest = Files.readAllLines(Paths.get(manifestFile))
    val factory =
      XMLInputFactory.newFactory().apply {
        setProperty(XMLInputFactory.SUPPORT_DTD, false)
        setProperty(XMLInputFactory.IS_SUPPORTING_EXTERNAL_ENTITIES, false)
      }
    Files.newInputStream(Paths.get(report)).use { input ->
      Files.newBufferedWriter(Paths.get(outputFile)).use { output ->
        val xml = factory.createXMLStreamReader(input)
        var pkg = ""
        var source: String? = null
        while (xml.hasNext()) {
          val event = xml.next()
          if (event == END_ELEMENT && xml.localName == "sourcefile" && source != null) {
            output.write("end_of_record\n")
            source = null
          }
          if (event != START_ELEMENT) continue
          when (xml.localName) {
            "package" -> {
              pkg = xml.getAttributeValue(null, "name")
            }

            "sourcefile" -> {
              val name = xml.getAttributeValue(null, "name")
              val path = if (pkg.isEmpty()) name else "$pkg/$name"
              source = manifest.firstOrNull { it == path || it.endsWith("/$path") }
              if (source != null) output.write("SF:$source\n")
            }

            "line" -> {
              val covered = xml.getAttributeValue(null, "ci").toInt()
              val missed = xml.getAttributeValue(null, "mi").toInt()
              if (source != null && (covered > 0 || missed > 0)) {
                val hit = if (covered > 0) 1 else 0
                output.write("DA:${xml.getAttributeValue(null, "nr")},$hit\n")
              }
            }
          }
        }
        xml.close()
      }
    }
  }
}
