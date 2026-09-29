package io.bazel.kotlin.test

import org.junit.Test
import java.nio.charset.StandardCharsets.UTF_8
import java.nio.file.Path
import java.util.function.Predicate
import kotlin.io.path.exists

private fun nullBazelRcPath() =
  if (System.getProperty("os.name").lowercase().contains("windows")) "NUL" else "/dev/null"

class BazelIntegrationTestRunner : BazelIntegrationTestBase() {
  @Test
  fun exampleBuildsAndTests() {
    val isWindows = System.getProperty("os.name").lowercase().contains("windows")
    val workspace = Path.of(env("BIT_WORKSPACE_DIR"))
    val unpack = unpackRelease(
      requireNotNull(System.getProperty("@rules_kotlin...rules_kotlin_release")),
    )

    val version = bazel.run(workspace, "--version").parseVersion()

    val workspaceEnabled = System.getenv("WORKSPACE_ENABLED") != null

    val workspaceFlags = FlagSets(
      listOf(
        if (workspaceEnabled) {
          listOf(
            Flag("--override_repository=rules_kotlin=$unpack"),
            Flag("--enable_bzlmod=false"),
            Flag("--enable_workspace=true") { it.isBzlmodEnabledByDefault },
          )
        } else {
          listOf(
            Flag("--enable_bzlmod=true"),
            Flag("--override_module=rules_kotlin=$unpack"),
            Flag("--enable_workspace=false") { it.isBzlmodEnabledByDefault },
          )
        },
      ),
    )

    val deprecationFlags = FlagSets(
      listOf(
        listOf(
          Flag("--incompatible_disallow_empty_glob=false"),
        ),
      ),
    )

    val experimentFlags = FlagSets(
      listOf(
        listOf(
          Flag("--@rules_kotlin//kotlin/settings:experimental_build_tools_api=false"),
        ),
        listOf(
          Flag("--@rules_kotlin//kotlin/settings:experimental_build_tools_api=true"),
        ),
      ),
    )

    val startupFlagSets = version.resolveBazelRc(workspace)
    val commandFlagSets = workspaceFlags * deprecationFlags * experimentFlags

    startupFlagSets.asStringsFor(version).forEach { systemFlags ->
      commandFlagSets.asStringsFor(version).forEach { commandFlags ->
        bazel.run(
          workspace,
          *systemFlags,
          "shutdown",
          *commandFlags,
        ).onFailThrow()
        bazel.run(
          workspace,
          *systemFlags,
          "info",
          *commandFlags,
        ).onFailThrow()
        bazel.run(
          workspace,
          *systemFlags,
          "build",
          *commandFlags,
          "//...",
        ).onFailThrow()
        bazel.run(
          workspace,
          *systemFlags,
          "query",
          *commandFlags,
          "@rules_kotlin//...",
        ).onFailThrow()
        bazel.run(
          workspace,
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
        }
          .also { testTargets ->
            if (testTargets.isNotEmpty()) {
              val coverageTargets = testTargets.toTypedArray()
              bazel.run(
                workspace,
                *systemFlags,
                "test",
                *commandFlags,
                "--test_output=all",
                "//...",
              ).onFailThrow()
              if (isWindows) {
                println("Skipping coverage on Windows integration runs.")
              } else {
                bazel.run(
                  workspace,
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

  class Flag(val value: String, val condition: Predicate<Version>) {
    constructor(value: String) : this(value, { true })
  }

  class FlagSets(val sets: List<List<Flag>>) {

    operator fun times(other: FlagSets): FlagSets = FlagSets(
      sets.flatMap { set ->
        other.sets.map { otherSet -> otherSet + set }
      },
    )

    fun asStringsFor(v: Version): List<Array<String>> =
      sets.map { set ->
        set.filter { it.condition.test(v) }.map { flag -> flag.value }.toTypedArray()
      }
  }

  sealed class Version : Comparable<Version> {
    companion object {
      fun of(major:Int, minor:Int=0, patch:Int = 0) = Known(major, minor, patch)
    }

    val isBzlmodEnabledByDefault: Boolean
      get() = this >= of(7, 0, 0)


    override fun compareTo(other: Version): Int = 1

    abstract fun resolveBazelRc(workspace: Path): FlagSets


    class Head : Version() {
      override fun compareTo(other: Version): Int = (other as? Head)?.let { 0 } ?: 1

      override fun resolveBazelRc(workspace: Path) = FlagSets(
        listOf(
          sequenceOf(".bazelrc.head", ".bazelrc")
            .map(workspace::resolve)
            .filter(Path::exists)
            .map { Flag("--bazelrc=$it") }
            .toList()
            .takeIf { it.isNotEmpty() }
            ?: listOf(Flag("--bazelrc=${nullBazelRcPath()}")),
        ),
      )
    }

    class Known(private val major: Int, private val minor: Int, private val patch: Int) :
      Version() {
      override fun compareTo(other: Version): Int {
        return (other as? Known)?.let {
          return when {
            other.major > major -> -1
            other.major < major -> 1
            other.minor > minor -> -1
            other.minor < minor -> 1
            other.patch > patch -> -1
            other.patch < patch -> 1
            else -> 0
          }
        } ?: -1
      }

      override fun resolveBazelRc(workspace: Path) = FlagSets(
        listOf(
          sequence {
            val parts = mutableListOf(major, minor, patch)
            (parts.size downTo 0).forEach { index ->
              val versionSuffix = parts.subList(0, index).joinToString("-")
              yield(if (versionSuffix.isEmpty()) "" else ".$versionSuffix")
            }
          }
            .map { suffix -> workspace.resolve(".bazelrc${suffix}") }
            .filter(Path::exists)
            .map { p -> Flag("--bazelrc=$p") }
            .toList()
            .takeIf { it.isNotEmpty() }
            ?: listOf(Flag("--bazelrc=${nullBazelRcPath()}")),
        ),
      )
    }
  }

  private val versionRegex = Regex("(?<major>\\d+)\\.(?<minor>\\d+)\\.(?<patch>\\d+)([^.]*)")

  private fun Result<ProcessResult>.parseVersion(): Version {
    ok { result ->
      result.stdOut.toString(UTF_8).split("\n")
        // first not empty should have the version
        .find(String::isNotEmpty)?.let { line ->
          if ("no_version" in line) {
            return Version.Head()
          }
          versionRegex.find(line.trim())?.let { result ->
            return Version.Known(
              major = result.groups["major"]?.value?.toInt() ?: 0,
              minor = result.groups["minor"]?.value?.toInt() ?: 0,
              patch = result.groups["patch"]?.value?.toInt() ?: 0,
            )
          }
        }
      throw IllegalStateException("Bazel version not available")
    }
  }

  private fun Result<ProcessResult>.onFailThrow() = onFailure {
    throw it
  }

  private inline fun <R> Result<ProcessResult>.ok(action: (ProcessResult) -> R) = fold(
    onSuccess = action,
    onFailure = { err -> throw err },
  )

}
