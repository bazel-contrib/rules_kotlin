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
package io.bazel.kotlin

import com.google.common.hash.Hashing
import java.io.File
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.Paths
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import java.util.concurrent.TimeUnit
import java.util.jar.JarEntry
import java.util.jar.JarFile
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue
import kotlin.test.fail

class TestCaseFailedException(name: String? = null, description: String? = null, cause: Throwable) :
  AssertionError(
    """"${name?.let { "jar: $it " } ?: ""} "$description" failed, error: ${cause.message}""",
    cause
  )

abstract class KotlinAssertionTestCase(root: String) : BasicAssertionTestCase() {
  private lateinit var currentFile: File

  private val testRunfileRoot: Path = Paths.get(root).also {
    it.toFile().also { file ->
      assert(file.exists()) { "runfile directory $root does not exist" }
      assert(file.isDirectory) { "runfile directory $root is not a directory" }
    }
  }

  private inline fun runTestCase(name: String, description: String? = null, op: () -> Unit) =
    try {
      op()
    } catch (t: Throwable) {
      when (t) {
        is AssertionError -> throw TestCaseFailedException(name, description, t)
        is Exception -> throw TestCaseFailedException(name, description, t)
        else -> throw t
      }
    }

  protected fun jarTestCase(
    name: String,
    description: String? = null,
    op: JarFile.() -> Unit
  ) {
    currentFile = testRunfileRoot.resolve(name).toFile()
    check(currentFile.exists()) {
      "testFile $name did not exist in test case root $testRunfileRoot"
    }
    runTestCase(name, description) { JarFile(currentFile).op() }
  }

  protected fun JarFile.assertContainsEntries(vararg want: String) {
    val got = this.entries().asSequence().map { it.name }.toSet()
    val missing = want.toSet() - got
    check(missing.isEmpty()) {
      "Entries Missing: $missing \nFrom: $got"
    }
  }

  protected fun JarFile.assertContainsExactEntries(vararg want: String) {
    val got = this.entries().asSequence().map { it.name }.toSet()
    val missing = want.toSet() - got
    val extra = got - want.toSet()
    check(missing.isEmpty() && extra.isEmpty()) {
      "Entries Missing: $missing \nFrom: $got \nEntries Extra: $extra \nFrom: $got"
    }
  }

  /** Class-file major version (JVMS 4.1) of a `.class` entry. */
  protected fun JarFile.classFileMajorVersion(entry: String): Int {
    val classEntry = checkNotNull(getJarEntry(entry)) { "no entry $entry in jar $name" }
    java.io.DataInputStream(getInputStream(classEntry)).use { input ->
      input.readInt() // 0xCAFEBABE magic
      input.readUnsignedShort() // minor version
      return input.readUnsignedShort() // major version
    }
  }

  /**
   * Validated the entry is compressed and has the DOS epoch for it's timestamp.
   */
  protected fun JarFile.assertEntryCompressedAndNormalizedTimestampYear(entry: String) {
    checkNotNull(this.getJarEntry(entry)).also {
      check(!it.isDirectory)
      assertTrue("$entry is not compressed") { JarEntry.DEFLATED == it.method }
      val modifiedTimestamp = LocalDateTime.ofInstant(
        Instant.ofEpochMilli(it.lastModifiedTime.toMillis()), ZoneId.systemDefault()
      )
      assertTrue("normalized modification time stamps should have year 1980") {
        modifiedTimestamp.year == 1980
      }
    }
  }

  /**
   * Assert the manifest in the jar is stamped.
   */
  protected fun JarFile.assertManifestStamped() {
    assertNotNull(
      manifest.mainAttributes.getValue("Target-Label"), "missing manifest entry Target-Label"
    )
    assertNotNull(
      manifest.mainAttributes.getValue("Injecting-Rule-Kind"),
      "missing manifest entry Injecting-Rule-Kind"
    )
  }

  protected fun validateFileSha256(expected: String) {
    val result = Hashing.sha256().hashBytes(Files.readAllBytes(currentFile.toPath())).toString()
    assertEquals(expected, result, "file $currentFile did not hash as expected")
  }

  protected fun JarFile.assertDoesNotContainEntries(vararg entries: String) {
    entries.forEach {
      if (this.getJarEntry(it) != null) {
        fail("jar ${this.name} contained entry $it")
      }
    }
  }

  override fun String.resolveDirectory(): File =
    if (startsWith("/"))
      trimStart('/').split("/").let { File(it.take(it.size - 1).joinToString(File.separator)) }
    else
      testRunfileRoot.toFile()
}

abstract class BasicAssertionTestCase {
  protected fun assertExecutableRunfileSucceeds(executable: String, description: String? = null) {
    ProcessBuilder().command("bash", "-c", Paths.get(executable).fileName.toString())
      .also { it.directory(executable.resolveDirectory()) }
      .start().let {
        it.waitFor(5, TimeUnit.SECONDS)
        assert(it.exitValue() == 0) {
          throw TestCaseFailedException(
            description = description,
            cause = RuntimeException("non-zero return code: ${it.exitValue()}")
          )
        }
      }
  }

  protected open fun String.resolveDirectory(): File =
    trimStart('/').split("/").let { File(it.take(it.size - 1).joinToString(File.separator)) }
}
