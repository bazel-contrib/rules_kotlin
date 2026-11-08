// Copyright 2026 The Bazel Authors. All rights reserved.
// SPDX-License-Identifier: Apache-2.0
package io.bazel.kotlin.coverage

import java.net.URLClassLoader
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.Paths
import javax.xml.stream.XMLInputFactory
import javax.xml.stream.XMLStreamConstants.END_ELEMENT
import javax.xml.stream.XMLStreamConstants.START_ELEMENT

/**
 * LCOV merger for Kotlin tests: converts the test's Kover report to LCOV, then runs Bazel's merger
 * in the same JVM, so Kover adds no process launches to a coverage run.
 *
 * Bazel runs the merger with `--coverage_dir` and `--source_file_manifest`. The test lists a
 * `.kover` file among its coverage metadata: the Kover CLI JAR's path, then the CLI's report
 * arguments.
 */
object KoverLcov {
  @JvmStatic
  fun main(args: Array<String>) {
    val flags = args.associate { it.substringBefore('=') to it.substringAfter('=') }
    val coverageDir = Paths.get(flags.getValue("--coverage_dir"))
    val manifest = Paths.get(flags.getValue("--source_file_manifest"))
    val ic = coverageDir.resolve("kover.ic")
    val koverArgs = Files.readAllLines(manifest).firstOrNull { it.endsWith(".kover") }
    if (koverArgs != null && Files.exists(ic)) {
      val (cli, reportArgs) =
        Files.readAllLines(Paths.get(koverArgs)).let {
          it.first() to
            it.drop(1)
        }
      val xml = Files.createTempFile("kover", ".xml")
      runKoverCli(cli, reportArgs + listOf(ic.toString(), "--xml", xml.toString()))
      convert(xml, manifest, coverageDir.resolve("kover.dat"))
      Files.delete(xml)
      Files.delete(ic)
    }
    Class
      .forName("com.google.devtools.coverageoutputgenerator.Main")
      .getMethod("main", Array<String>::class.java)
      .invoke(null, args)
  }

  // The CLI JAR bundles its own Kotlin stdlib, so it gets a classloader of its own.
  private fun runKoverCli(
    cli: String,
    args: List<String>,
  ) {
    val url = Paths.get(cli).toUri().toURL()
    URLClassLoader(arrayOf(url), ClassLoader.getPlatformClassLoader()).use { loader ->
      val status =
        loader
          .loadClass("kotlinx.kover.cli.MainKt")
          .getMethod("invokeCli", Array<String>::class.java)
          .invoke(null, args.toTypedArray()) as Int
      check(status == 0) { "Kover CLI failed with status $status" }
    }
  }

  /**
   * Converts a Kover XML report to an LCOV fragment.
   *
   * Source files are matched to the exec paths in Bazel's coverage manifest by `package/File.kt`
   * suffix, the same rule Bazel's JaCoCo LCOV formatter uses. Sources whose directory doesn't end
   * in their package path are dropped; supporting them would need the builder to emit an explicit
   * source-to-package map.
   */
  fun convert(
    report: Path,
    manifestFile: Path,
    outputFile: Path,
  ) {
    val manifest = Files.readAllLines(manifestFile)
    val factory =
      XMLInputFactory.newFactory().apply {
        setProperty(XMLInputFactory.SUPPORT_DTD, false)
        setProperty(XMLInputFactory.IS_SUPPORTING_EXTERNAL_ENTITIES, false)
      }
    Files.newInputStream(report).use { input ->
      Files.newBufferedWriter(outputFile).use { output ->
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
