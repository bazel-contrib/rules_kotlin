/*
 * Copyright 2026 The Bazel Authors. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 */

package io.bazel.kotlin.generate

import io.bazel.kotlin.builder.utils.ArgMaps
import io.bazel.kotlin.builder.utils.Flag
import io.bazel.kotlin.generate.WriteKotlincCapabilities.BzlDoc
import java.nio.file.FileSystems
import java.nio.file.Files
import java.security.MessageDigest

class GenerateReleaseMetadata {
  companion object {
    @JvmStatic
    fun main(args: Array<String>) {
      GenerateReleaseMetadata().generate(args)
    }

    fun parseNamedValue(arg: String): Pair<String, String> {
      val idx = arg.indexOf('=')
      require(idx > 0) { "expected name=value but got '$arg'" }
      return arg.substring(0, idx) to arg.substring(idx + 1)
    }

    fun sha256Hex(bytes: ByteArray): String =
      MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }

  }

  fun generate(args: Array<String>) {
    val fs = FileSystems.getDefault()
    val argMap = ArgMaps.from(args.toList())

    val version =
      StatusFile(Files.readString(fs.getPath(argMap.mandatorySingle(MetadataArg.VERSION_FILE))))
        .version(argMap.mandatorySingle(MetadataArg.VERSION_KEY))

    val urls = UrlTemplates(namedValues(argMap.optional(MetadataArg.URL)))

    val entries =
      namedValues(argMap.optional(MetadataArg.JAR)).mapValues { (name, path) ->
        JarEntry(
          url = urls.resolve(name, version),
          sha256 = sha256Hex(Files.readAllBytes(fs.getPath(path))),
        )
      }

    Files.writeString(
      fs.getPath(argMap.mandatorySingle(MetadataArg.OUT_BZL)),
      ReleaseManifest(version, entries).render(),
    )

    val notesTemplate =
      Files.readString(fs.getPath(argMap.mandatorySingle(MetadataArg.NOTES_TEMPLATE)))

    Files.writeString(
      fs.getPath(argMap.mandatorySingle(MetadataArg.OUT_NOTES)),
      ReleaseNotes(notesTemplate, version).render(),
    )
  }

  private fun namedValues(raw: List<String>?): Map<String, String> =
    raw.orEmpty().associate { parseNamedValue(it) }


  data class JarEntry(
    val url: String,
    val sha256: String,
  )

  class StatusFile(
    private val text: String,
  ) {
    fun version(key: String): String =
      requireNotNull(
        text.lineSequence()
        .map(String::trim)
        .filter(String::isNotEmpty)
        .mapNotNull { line -> line.split(' ', limit = 2).takeIf { it.size == 2 } }
        .firstOrNull { it[0] == key }
        ?.let { it[1].trim() }
      ) {"`$text` does not have required $key"}
  }

  class UrlTemplates(
    private val templates: Map<String, String>,
  ) {
    fun resolve(
      name: String,
      version: String,
    ): String =
      (templates[name] ?: templates[WILDCARD] ?: "")
        .replace("{version}", version)
        .replace("{name}", name)

    companion object {
      const val WILDCARD = "*"
    }
  }

  class ReleaseManifest(
    private val version: String,
    private val jars: Map<String, JarEntry>,
  ) {
    fun render(): String =
      BzlDoc(
        doc = "Generated release manifest: jar name -> struct(url, sha256), plus VERSION.",
        generatedBy = "bazel build //:release_metadata",
      ) {
        with(WriteKotlincCapabilities) {
          assignment(
            "JARS",
            dict(
              *jars.keys.sorted().map { name ->
                val entry = jars.getValue(name)
                name to struct(
                  "url" to entry.url.bzlQuote(),
                  "sha256" to entry.sha256.bzlQuote(),
                )
              }.toTypedArray(),
            ),
          )
          assignment("VERSION", value(version.bzlQuote()))
        }
      }.toString()
  }

  class ReleaseNotes(
    private val template: String,
    private val version: String,
  ) {
    fun render(): String = template.replace(VERSION_PLACEHOLDER, version)

    companion object {
      const val VERSION_PLACEHOLDER = "{version}"
    }
  }

  enum class MetadataArg(
    override val flag: String,
  ) : Flag {
    VERSION_FILE("--version_file"),
    VERSION_KEY("--version_key"),
    OUT_BZL("--out_bzl"),
    OUT_NOTES("--out_notes"),
    NOTES_TEMPLATE("--notes_template"),
    JAR("--jar"),
    URL("--url"),
  }
}
