// Copyright 2014 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@file:Suppress("MemberVisibilityCanBePrivate")

package io.bazel.kotlin.builder.utils.jars

import java.io.FileNotFoundException
import java.io.IOException
import java.nio.file.Files
import java.nio.file.Path
import java.util.Calendar
import java.util.GregorianCalendar
import java.util.HashSet
import java.util.jar.Attributes
import java.util.jar.JarEntry
import java.util.jar.JarFile
import java.util.jar.JarOutputStream
import java.util.zip.CRC32

/**
 * A simple helper class for creating Jar files. All Jar entries are sorted alphabetically. Allows
 * normalization of Jar entries by setting the timestamp of non-.class files to the DOS epoch.
 * Timestamps of .class files are set to the DOS epoch + 2 seconds (The zip timestamp granularity)
 * Adjusting the timestamp for .class files is necessary since otherwise javac will recompile java
 * files if both the java file and its .class file are present.
 */
open class JarHelper internal constructor(
  // The path to the Jar we want to create
  protected val jarPath: Path,
  // The properties to describe how to create the Jar
  protected val normalize: Boolean = true,
  protected val verbose: Boolean = false,
  compression: Boolean = true,
) {
  private var storageMethod: Int = JarEntry.DEFLATED

  // The state needed to create the Jar
  private val names: MutableSet<String> = HashSet()

  init {
    setCompression(compression)
  }

  /**
   * Enables or disables compression for the Jar file entries.
   *
   * @param compression if true enables compressions for the Jar file entries.
   */
  private fun setCompression(compression: Boolean) {
    storageMethod = if (compression) JarEntry.DEFLATED else JarEntry.STORED
  }

  /**
   * Returns the normalized timestamp for a jar entry based on its name. This is necessary since
   * javac will, when loading a class X, prefer a source file to a class file, if both files have
   * the same timestamp. Therefore, we need to adjust the timestamp for class files to slightly
   * after the normalized time.
   *
   * @param name The name of the file for which we should return the normalized timestamp.
   * @return the time for a new Jar file entry in milliseconds since the epoch.
   */
  private fun normalizedTimestamp(name: String): Long =
    if (name.endsWith(".class")) {
      DEFAULT_TIMESTAMP + MINIMUM_TIMESTAMP_INCREMENT
    } else {
      DEFAULT_TIMESTAMP
    }

  /**
   * Returns the time for a new Jar file entry in milliseconds since the epoch. Uses JarCreator.DEFAULT_TIMESTAMP]
   * for normalized entries, [System.currentTimeMillis] otherwise.
   *
   * @param filename The name of the file for which we are entering the time
   * @return the time for a new Jar file entry in milliseconds since the epoch.
   */
  private fun newEntryTimeMillis(filename: String): Long =
    if (normalize) normalizedTimestamp(filename) else System.currentTimeMillis()

  /**
   * Writes an entry with specific contents to the jar. Directory entries must include the trailing
   * '/'.
   */
  @Throws(IOException::class)
  private fun writeEntry(
    out: JarOutputStream,
    name: String,
    content: ByteArray,
  ) {
    if (names.add(name)) {
      // Create a new entry
      val entry = JarEntry(name)
      entry.time = newEntryTimeMillis(name)
      val size = content.size
      entry.size = size.toLong()
      if (size == 0) {
        entry.method = JarEntry.STORED
        entry.crc = 0
        out.putNextEntry(entry)
      } else {
        entry.method = storageMethod
        if (storageMethod == JarEntry.STORED) {
          val crc = CRC32()
          crc.update(content)
          entry.crc = crc.value
        }
        out.putNextEntry(entry)
        out.write(content)
      }
      out.closeEntry()
    }
  }

  /**
   * Writes a standard Java manifest entry into the JarOutputStream. This includes the directory
   * entry for the "META-INF" directory
   *
   * @param content the Manifest content to write to the manifest entry.
   * @throws IOException
   */
  @Throws(IOException::class)
  protected fun writeManifestEntry(
    out: JarOutputStream,
    content: ByteArray,
  ) {
    val oldStorageMethod = storageMethod
    // Do not compress small manifest files, the compressed one is frequently
    // larger than the original. The threshold of 256 bytes is somewhat arbitrary.
    if (content.size < 256) {
      storageMethod = JarEntry.STORED
    }
    try {
      writeEntry(out, MANIFEST_DIR, byteArrayOf())
      writeEntry(out, MANIFEST_NAME, content)
    } finally {
      storageMethod = oldStorageMethod
    }
  }

  /**
   * Copies file or directory entries from the file system into the jar. Directory entries will be
   * detected and their names automatically '/' suffixed.
   */
  @Throws(IOException::class)
  protected fun JarOutputStream.copyEntry(
    name: String,
    path: Path,
  ) {
    var normalizedName = name
    if (!names.contains(normalizedName)) {
      if (!Files.exists(path)) {
        throw FileNotFoundException("${path.toAbsolutePath()} (No such file or directory)")
      }
      val isDirectory = Files.isDirectory(path)
      if (isDirectory && !normalizedName.endsWith("/")) {
        normalizedName = "$normalizedName/" // always normalize directory names before checking set
      }
      if (names.add(normalizedName)) {
        if (verbose) {
          System.err.println("adding $path")
        }
        // Create a new entry
        val size = if (isDirectory) 0 else Files.size(path)
        val outEntry = JarEntry(normalizedName)
        val newtime =
          if (normalize) {
            normalizedTimestamp(normalizedName)
          } else {
            Files
              .getLastModifiedTime(path)
              .toMillis()
          }
        outEntry.time = newtime
        outEntry.size = size
        if (size == 0L) {
          outEntry.method = JarEntry.STORED
          outEntry.crc = 0
          putNextEntry(outEntry)
        } else {
          outEntry.method = storageMethod
          if (storageMethod == JarEntry.STORED) {
            // ZipFile requires us to calculate the CRC-32 for any STORED entry.
            // It would be nicer to do this via DigestInputStream, but
            // the architecture of ZipOutputStream requires us to know the CRC-32
            // before we write the data to the stream.
            val bytes = Files.readAllBytes(path)
            val crc = CRC32()
            crc.update(bytes)
            outEntry.crc = crc.value
            putNextEntry(outEntry)
            write(bytes)
          } else {
            putNextEntry(outEntry)
            Files.copy(path, this)
          }
        }
        closeEntry()
      }
    }
  }

  companion object {
    const val MANIFEST_DIR = "META-INF/"
    const val MANIFEST_NAME = JarFile.MANIFEST_NAME

    // Normalized timestamp for zip entries
    // We do not include the system's default timezone and locale and additionally avoid the unix epoch
    // to ensure Java's zip implementation does not add the System's timezone into the extra field of the zip entry
    val DEFAULT_TIMESTAMP = GregorianCalendar(1980, Calendar.FEBRUARY, 1, 0, 0, 0).getTimeInMillis()

    // These attributes are used by JavaBuilder, Turbine, and ijar.
    // They must all be kept in sync.
    val TARGET_LABEL = Attributes.Name("Target-Label")
    val INJECTING_RULE_KIND = Attributes.Name("Injecting-Rule-Kind")

    // ZIP timestamps have a resolution of 2 seconds.
    // see http://www.info-zip.org/FAQ.html#limits
    const val MINIMUM_TIMESTAMP_INCREMENT = 2000L
  }
}
