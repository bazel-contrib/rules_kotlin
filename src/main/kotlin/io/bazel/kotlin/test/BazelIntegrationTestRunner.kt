package io.bazel.kotlin.test


import io.bazel.kotlin.builder.utils.BazelRunFiles
import org.apache.commons.compress.archivers.tar.TarArchiveInputStream
import java.io.BufferedInputStream
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.io.OutputStream
import java.nio.charset.StandardCharsets.UTF_8
import java.nio.file.FileSystems
import java.nio.file.Files
import java.nio.file.Path
import java.util.concurrent.Callable
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.function.Predicate
import java.util.zip.GZIPInputStream
import kotlin.io.path.createDirectories
import kotlin.io.path.exists
import kotlin.io.path.inputStream

object BazelIntegrationTestRunner {
  @JvmStatic
  fun main(args: Array<String>) {
    val isWindows = System.getProperty("os.name").lowercase().contains("windows")
    val fs = FileSystems.getDefault()
    val bazel = fs.getPath(System.getenv("BIT_BAZEL_BINARY"))
    val workspace = fs.getPath(System.getenv("BIT_WORKSPACE_DIR"))
    val unpack = fs.getPath(System.getenv("TEST_TMPDIR")).resolve("rules_kotlin")
    val release = BazelRunFiles.resolveVerifiedFromProperty(
      fs,
      "@rules_kotlin...rules_kotlin_release",
    )

    TarArchiveInputStream(
      GZIPInputStream(
        release.inputStream(),
      ),
    ).use { stream ->
      generateSequence(stream::getNextEntry).forEach { entry ->
        val destination = unpack.resolve(entry.name)
        when {
          entry.isDirectory -> destination.createDirectories()
          entry.isFile -> Files.write(
            destination.apply { parent.createDirectories() },
            stream.readBytes(),
          )

          else -> throw NotImplementedError(entry.toString())
        }
      }
    }

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
              // TODO: Fix Kover coverage on Windows.
              if (isWindows) {
                println("Skipping Kover coverage on Windows integration runs.")
              } else {
                bazel.run(
                  workspace,
                  *systemFlags,
                  "coverage",
                  *commandFlags,
                  *coverageTargets,
                ).onFailThrow()
              }
              if (isWindows) {
                println("Skipping lcov coverage on Windows integration runs.")
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
  private fun nullBazelRcPath() =
    if (System.getProperty("os.name").lowercase().contains("windows")) "NUL" else "/dev/null"

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

  private val VERSION_REGEX = Regex("(?<major>\\d+)\\.(?<minor>\\d+)\\.(?<patch>\\d+)([^.]*)")

  private fun Result<ProcessResult>.parseVersion(): Version {
    ok { result ->
      result.stdOut.toString(UTF_8).split("\n")
        // first not empty should have the version
        .find(String::isNotEmpty)?.let { line ->
          if ("no_version" in line) {
            return Version.Head()
          }
          VERSION_REGEX.find(line.trim())?.let { result ->
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

  data class ProcessResult(
    val exit: Int,
    val stdOut: ByteArray,
    val stdErr: ByteArray,
  )

  private fun Result<ProcessResult>.onFailThrow() = onFailure {
    throw it
  }

  private inline fun <R> Result<ProcessResult>.ok(action: (ProcessResult) -> R) = fold(
    onSuccess = action,
    onFailure = { err -> throw err },
  )

  fun Path.run(inDirectory: Path, vararg args: String): Result<ProcessResult> =
    ProcessBuilder().command(this.toString(), *args).directory(inDirectory.toFile()).start()
      .let { process ->
        println("Running [${fileName} ${args.joinToString(" ")}]...")
        val executor = Executors.newCachedThreadPool();
        try {
          val stdOut = executor.submit(process.inputStream.streamTo(System.out))
          val stdErr = executor.submit(process.errorStream.streamTo(System.out))
          if (process.waitFor(1500, TimeUnit.SECONDS) && process.exitValue() == 0) {
            return Result.success(
              ProcessResult(
                exit = 0,
                stdErr = stdErr.get(),
                stdOut = stdOut.get(),
              ),
            )
          }
          process.destroyForcibly()
          return Result.failure(
            AssertionError(
              """
            $this ${args.joinToString(" ")} exited ${process.waitFor()}:
            stdout:
            ${stdOut.get().toString(UTF_8)}
            stderr:
            ${stdErr.get().toString(UTF_8)}
          """.trimIndent(),
            ),
          )
        } finally {
          executor.shutdown();
          executor.awaitTermination(1, TimeUnit.SECONDS);
        }
      }

  private fun InputStream.streamTo(out: OutputStream): Callable<ByteArray> {
    return Callable {
      val result = ByteArrayOutputStream();
      BufferedInputStream(this).apply {
        val buffer = ByteArray(4096)
        var read = 0
        do {
          if (Thread.currentThread().isInterrupted) {
            out.flush()
            break
          }
          result.write(buffer, 0, read);
          out.write(buffer, 0, read)
          read = read(buffer)
        } while (read != -1)
      }
      return@Callable result.toByteArray()
    }
  }
}
