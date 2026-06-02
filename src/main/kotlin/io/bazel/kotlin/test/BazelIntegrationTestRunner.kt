package io.bazel.kotlin.test

import io.bazel.kotlin.test.BazelIntegrationTestSupport.forEachCommandVariant
import io.bazel.kotlin.test.BazelIntegrationTestSupport.ok
import io.bazel.kotlin.test.BazelIntegrationTestSupport.onFailThrow
import io.bazel.kotlin.test.BazelIntegrationTestSupport.prepareWorkspace
import io.bazel.kotlin.test.BazelIntegrationTestSupport.run
import java.nio.charset.StandardCharsets.UTF_8

object BazelIntegrationTestRunner {
  @JvmStatic
  fun main(args: Array<String>) {
    val prepared = prepareWorkspace()

    forEachCommandVariant(prepared) { systemFlags, commandFlags ->
      prepared.bazel.run(prepared.workspace, *systemFlags, "build", *commandFlags, "//...").onFailThrow()
      prepared.bazel.run(prepared.workspace, *systemFlags, "query", *commandFlags, "@rules_kotlin//...").onFailThrow()
      prepared.bazel.run(
        prepared.workspace,
        *systemFlags,
        "query",
        *commandFlags,
        "kind(\".*_test\", \"//...\")",
      ).ok { process ->
        process.stdOut.toString(UTF_8)
          .lineSequence()
          .map(String::trim)
          .filter(String::isNotEmpty)
          .toList()
          .sorted()
      }.also { testTargets ->
        if (testTargets.isNotEmpty()) {
          val coverageTargets = testTargets.toTypedArray()
          prepared.bazel.run(
            prepared.workspace,
            *systemFlags,
            "test",
            *commandFlags,
            "--test_output=all",
            "//...",
          ).onFailThrow()
          if (prepared.isWindows) {
            println("Skipping coverage on Windows integration runs.")
          } else {
            prepared.bazel.run(
              prepared.workspace,
              *systemFlags,
              "coverage",
              *commandFlags,
              "--combined_report=lcov",
              *coverageTargets,
            ).onFailThrow()
          }
        }
      }
    }
  }
}
