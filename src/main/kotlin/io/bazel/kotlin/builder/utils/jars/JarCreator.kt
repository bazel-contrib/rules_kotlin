/*
 * Copyright 2018 The Bazel Authors. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package io.bazel.kotlin.builder.utils.jars

import java.io.BufferedOutputStream
import java.io.ByteArrayOutputStream
import java.io.Closeable
import java.io.IOException
import java.io.UncheckedIOException
import java.nio.file.FileVisitResult
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.SimpleFileVisitor
import java.nio.file.attribute.BasicFileAttributes
import java.util.TreeMap
import java.util.jar.Attributes
import java.util.jar.JarOutputStream
import java.util.jar.Manifest

/**
 * A class for creating Jar files. Allows normalization of Jar entries by setting their timestamp to
 * the DOS epoch. All Jar entries are sorted alphabetically.
 */
class JarCreator(
  path: Path,
  normalize: Boolean = true,
  verbose: Boolean = false,
) : JarHelper(path, normalize, verbose),
  Closeable {
  // Map from Jar entry names to files. Use TreeMap so we can establish a canonical order for the
  // entries regardless in what order they get added.
  private val jarEntries = TreeMap<String, Path>()
  private var targetLabel: String? = null
  private var injectingRuleKind: String? = null

  /**
   * Adds the contents of a directory to the Jar file. All files below this directory will be added
   * to the Jar file using the name relative to the directory as the name for the Jar entry.
   *
   * @param directory the directory to add to the jar
   */
  fun addDirectory(directory: Path) {
    if (!Files.exists(directory)) {
      throw IllegalArgumentException("directory does not exist: $directory")
    }
    try {
      Files.walkFileTree(
        directory,
        object : SimpleFileVisitor<Path>() {
          @Throws(IOException::class)
          override fun preVisitDirectory(
            path: Path,
            attrs: BasicFileAttributes,
          ): FileVisitResult {
            if (path != directory) {
              // For consistency with legacy behaviour, include entries for directories except for
              // the root.
              addEntry(path, isDirectory = true)
            }
            return FileVisitResult.CONTINUE
          }

          @Throws(IOException::class)
          override fun visitFile(
            path: Path,
            attrs: BasicFileAttributes,
          ): FileVisitResult {
            addEntry(path, isDirectory = false)
            return FileVisitResult.CONTINUE
          }

          fun addEntry(
            path: Path,
            isDirectory: Boolean,
          ) {
            val sb = StringBuilder()
            var first = true
            for (entry in directory.relativize(path)) {
              if (!first) {
                // use `/` as the directory separator for jar paths, even on Windows
                sb.append('/')
              }
              sb.append(entry.fileName)
              first = false
            }
            if (isDirectory) {
              sb.append('/')
            }
            jarEntries[sb.toString()] = path
          }
        },
      )
    } catch (e: IOException) {
      throw UncheckedIOException(e)
    }
  }

  fun setJarOwner(
    targetLabel: String,
    injectingRuleKind: String,
  ) {
    this.targetLabel = targetLabel
    this.injectingRuleKind = injectingRuleKind
  }

  @Throws(IOException::class)
  private fun manifestContent(): ByteArray {
    val manifest = Manifest()
    val attributes = manifest.mainAttributes
    attributes[Attributes.Name.MANIFEST_VERSION] = "1.0"
    val createdBy = Attributes.Name("Created-By")
    attributes[createdBy] = "io.bazel.rules.kotlin"
    if (targetLabel != null) {
      attributes[TARGET_LABEL] = targetLabel
    }
    if (injectingRuleKind != null) {
      attributes[INJECTING_RULE_KIND] = injectingRuleKind
    }
    val out = ByteArrayOutputStream()
    manifest.write(out)
    return out.toByteArray()
  }

  override fun close() {
    execute()
  }

  /**
   * Executes the creation of the Jar file.
   *
   * @throws IOException if the Jar cannot be written or any of the entries cannot be read.
   */
  @Throws(IOException::class)
  fun execute() {
    Files.newOutputStream(jarPath).use { os ->
      BufferedOutputStream(os).use { bos ->
        JarOutputStream(bos).use { out ->
          // Create the manifest entry in the Jar file
          writeManifestEntry(out, manifestContent())
          for ((key, value) in jarEntries) {
            out.copyEntry(key, value)
          }
        }
      }
    }
  }
}
