package io.bazel.kotlin.integration

import com.google.protobuf.Struct
import com.google.protobuf.util.JsonFormat
import io.bazel.kotlin.test.BazelIntegrationTestBase
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.net.URI
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.Paths
import kotlin.io.path.createDirectories
import kotlin.io.path.isRegularFile
import kotlin.io.path.useLines
import kotlin.io.path.writeText

class ToolchainLoadingTest : BazelIntegrationTestBase() {
  private fun assertDownloads(
    log: Path,
    expected: Boolean,
  ) {
    val downloads = mutableListOf<Pair<String, Boolean>>()
    var complete = false
    log.useLines { lines ->
      lines.forEach { line ->
        val event = Struct.newBuilder().also { JsonFormat.parser().merge(line, it) }.build()
        complete = complete || event.fieldsMap["lastMessage"]?.boolValue == true
        // Child IDs announce events; only inspect actual fetch payloads.
        if (event.containsFields("fetch")) {
          val id = event.getFieldsOrThrow("id").structValue
          val fetch = id.getFieldsOrThrow("fetch").structValue
          val url = fetch.getFieldsOrThrow("url").stringValue
          val filename = URI.create(url).path.substringAfterLast('/')
          if (filename.startsWith("kotlin-compiler-")) {
            val result = event.getFieldsOrThrow("fetch").structValue
            downloads.add(url to (result.fieldsMap["success"]?.boolValue == true))
          }
        }
      }
    }
    assertTrue("Missing final BEP event in $log", complete)
    if (expected) {
      assertTrue(
        "No successful compiler download recorded in $log",
        downloads.any { (_, success) -> success },
      )
    } else {
      assertTrue("Unexpected compiler download in $log: $downloads", downloads.isEmpty())
    }
    println("${log.fileName}: expected download=$expected; $downloads")
  }

  @Test
  fun loading() {
    assertTrue(
      "Bazel launcher is not the declared runfile: $bazel",
      Files.isSameFile(bazel, runfile(env("BAZEL_BINARY_RUNFILE"))),
    )
    val release = unpackRelease(env("RULES_KOTLIN_RELEASE"))
    val consumer = root.resolve("consumer").createDirectories()
    val output = root.resolve("output")
    val logs = Paths.get(env("TEST_UNDECLARED_OUTPUTS_DIR"), "nested_bazel").createDirectories()

    consumer.resolve("MODULE.bazel").writeText(
      """
      module(name = "unrelated_cpp")
      bazel_dep(name = "rules_cc", version = "0.2.17")
      bazel_dep(name = "rules_kotlin", version = "2.2.0")
      """.trimIndent(),
    )
    consumer.resolve("BUILD.bazel").writeText(
      """
      load("@rules_cc//cc:cc_library.bzl", "cc_library")
      cc_library(name = "empty")
      """.trimIndent(),
    )

    fun build(
      target: String,
      phase: String,
    ): Path {
      val log = logs.resolve("$phase.json")
      bazel
        .run(
          consumer,
          "--batch",
          "--ignore_all_rc_files",
          "--host_jvm_args=-Djava.net.preferIPv6Addresses=system",
          "--output_user_root=${root.resolve("bazel")}",
          "--output_base=$output",
          "build",
          "--jobs=2",
          "--noshow_progress",
          "--color=no",
          // Fetch events omit cache hits, so disable repository caching.
          "--repo_contents_cache=",
          "--repository_cache=",
          "--override_module=rules_kotlin=$release",
          "--build_event_json_file=$log",
          target,
        ).getOrThrow()
      return log
    }

    fun metadataPresent(): Boolean =
      Files.list(output.resolve("external")).use { repos ->
        repos.anyMatch {
          it.resolve("capabilities.bzl").isRegularFile() &&
            it.resolve("artifacts.bzl").isRegularFile()
        }
      }

    assertDownloads(build("//:empty", "cpp"), expected = false)
    assertFalse("Unrelated C++ build materialized Kotlin capabilities", metadataPresent())
    assertDownloads(
      build("@rules_kotlin//kotlin/internal:default_kotlinc_options", "options"),
      expected = false,
    )
    assertTrue("Kotlin options did not materialize capabilities", metadataPresent())
    Files.list(output.resolve("external")).use { repos ->
      assertFalse(
        "Kotlin options materialized the compiler",
        repos.anyMatch { it.resolve("lib/kotlin-compiler.jar").isRegularFile() },
      )
    }
    // Positive control: a real download must be observed by the log checker.
    assertDownloads(
      build("@rules_kotlin//kotlin/compiler:kotlin-compiler", "compiler"),
      expected = true,
    )
  }
}
