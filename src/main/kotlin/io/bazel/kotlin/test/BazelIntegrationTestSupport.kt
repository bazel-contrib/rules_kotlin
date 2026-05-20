package io.bazel.kotlin.test

import io.bazel.kotlin.builder.utils.BazelRunFiles
import org.apache.commons.compress.archivers.tar.TarArchiveInputStream
import java.io.BufferedInputStream
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.io.OutputStream
import java.nio.charset.StandardCharsets.UTF_8
import java.nio.file.FileSystem
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

internal object BazelIntegrationTestSupport {
  data class PreparedWorkspace(
    val bazel: Path,
    val workspace: Path,
    val isWindows: Boolean,
    val version: Version,
    val startupFlagSets: FlagSets,
    val commandFlagSets: FlagSets,
  )

  fun fileSystem(): FileSystem = FileSystems.getDefault()

  fun bazelBinary(fs: FileSystem = fileSystem()): Path = fs.getPath(System.getenv("BIT_BAZEL_BINARY"))

  fun workspaceDirectory(fs: FileSystem = fileSystem()): Path = fs.getPath(System.getenv("BIT_WORKSPACE_DIR"))

  fun testTmpDir(fs: FileSystem = fileSystem()): Path = fs.getPath(System.getenv("TEST_TMPDIR"))

  fun releaseArchive(fs: FileSystem = fileSystem()): Path =
    BazelRunFiles.resolveVerifiedFromProperty(fs, "@rules_kotlin...rules_kotlin_release")

  fun unpackRelease(
    release: Path,
    destination: Path,
  ) {
    val normalizedDestination = destination.toAbsolutePath().normalize()
    TarArchiveInputStream(GZIPInputStream(release.inputStream())).use { stream ->
      generateSequence(stream::getNextEntry).forEach { entry ->
        val dest = normalizedDestination.resolve(entry.name).normalize()
        require(dest.startsWith(normalizedDestination)) {
          "Refusing to extract archive entry outside destination: ${entry.name}"
        }
        when {
          entry.isDirectory -> dest.createDirectories()
          entry.isFile -> Files.write(dest.apply { parent.createDirectories() }, stream.readBytes())
          else -> throw NotImplementedError(entry.toString())
        }
      }
    }
  }

  fun prepareWorkspace(): PreparedWorkspace {
    val isWindows = System.getProperty("os.name").lowercase().contains("windows")
    val fs = fileSystem()
    val bazel = bazelBinary(fs)
    val workspace = workspaceDirectory(fs)
    val unpack = testTmpDir(fs).resolve("rules_kotlin")
    val release = releaseArchive(fs)

    unpackRelease(release, unpack)

    val version = bazel.run(workspace, "--version").parseVersion()
    val moduleFlags =
      FlagSets(
        listOf(
          listOf(Flag("--override_module=rules_kotlin=$unpack")),
        ),
      )
    val deprecationFlags =
      FlagSets(
        listOf(
          listOf(Flag("--incompatible_disallow_empty_glob=false")),
        ),
      )
    val experimentFlags =
      FlagSets(
        listOf(
          listOf(Flag("--@rules_kotlin//kotlin/settings:experimental_build_tools_api=false")),
          listOf(Flag("--@rules_kotlin//kotlin/settings:experimental_build_tools_api=true")),
        ),
      )

    return PreparedWorkspace(
      bazel = bazel,
      workspace = workspace,
      isWindows = isWindows,
      version = version,
      startupFlagSets = version.resolveBazelRc(workspace),
      commandFlagSets = moduleFlags * deprecationFlags * experimentFlags,
    )
  }

  fun forEachCommandVariant(
    prepared: PreparedWorkspace,
    action: (Array<String>, Array<String>) -> Unit,
  ) {
    prepared.startupFlagSets.asStringsFor(prepared.version).forEach { systemFlags ->
      prepared.commandFlagSets.asStringsFor(prepared.version).forEach { commandFlags ->
        prepared.bazel.run(prepared.workspace, *systemFlags, "shutdown", *commandFlags).onFailThrow()
        prepared.bazel.run(prepared.workspace, *systemFlags, "info", *commandFlags).onFailThrow()
        action(systemFlags, commandFlags)
      }
    }
  }

  fun buildWorkspaceFlags(
    workspace: Path,
    unpack: Path,
    version: Version,
  ): Pair<Array<String>, Array<String>> {
    val startupFlags = version.resolveBazelRc(workspace).asStringsFor(version).single()
    val commandFlags = mutableListOf<String>()

    if (workspace.hasModule()) {
      commandFlags.add("--enable_bzlmod=true")
      commandFlags.add("--override_module=rules_kotlin=$unpack")
      if (version >= Version.Known(7, 0, 0)) {
        commandFlags.add("--enable_workspace=false")
      }
    } else if (workspace.hasWorkspace()) {
      commandFlags.add("--override_repository=rules_kotlin=$unpack")
      commandFlags.add("--enable_bzlmod=false")
      if (version >= Version.Known(7, 0, 0)) {
        commandFlags.add("--enable_workspace=true")
      }
    }

    return startupFlags to commandFlags.toTypedArray()
  }

  class Flag(
    val value: String,
    val condition: Predicate<Version>,
  ) {
    constructor(value: String) : this(value, { true })
  }

  class FlagSets(
    val sets: List<List<Flag>>,
  ) {
    operator fun times(other: FlagSets): FlagSets =
      FlagSets(
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
    override fun compareTo(other: Version): Int = 1

    abstract fun resolveBazelRc(workspace: Path): FlagSets

    class Head : Version() {
      override fun compareTo(other: Version): Int = (other as? Head)?.let { 0 } ?: 1

      override fun resolveBazelRc(workspace: Path) =
        FlagSets(
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

    class Known(
      private val major: Int,
      private val minor: Int,
      private val patch: Int,
    ) : Version() {
      override fun compareTo(other: Version): Int {
        return (other as? Known)?.let {
          when {
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

      override fun resolveBazelRc(workspace: Path) =
        FlagSets(
          listOf(
            sequence {
              val parts = mutableListOf(major, minor, patch)
              (parts.size downTo 0).forEach { index ->
                val versionSuffix = parts.subList(0, index).joinToString("-")
                yield(if (versionSuffix.isEmpty()) "" else ".$versionSuffix")
              }
            }.map { suffix -> workspace.resolve(".bazelrc${suffix}") }
              .filter(Path::exists)
              .map { path -> Flag("--bazelrc=$path") }
              .toList()
              .takeIf { it.isNotEmpty() }
              ?: listOf(Flag("--bazelrc=${nullBazelRcPath()}")),
          ),
        )
    }
  }

  data class ProcessResult(
    val exit: Int,
    val stdOut: ByteArray,
    val stdErr: ByteArray,
  )

  private val VERSION_REGEX = Regex("(?<major>\\d+)\\.(?<minor>\\d+)\\.(?<patch>\\d+)([^.]*)")

  fun Result<ProcessResult>.onFailThrow() = onFailure { throw it }

  inline fun <R> Result<ProcessResult>.ok(action: (ProcessResult) -> R) = fold(
    onSuccess = action,
    onFailure = { err -> throw err },
  )

  fun Result<ProcessResult>.parseVersion(): Version {
    ok { result ->
      result.stdOut.toString(UTF_8).split("\n")
        .find(String::isNotEmpty)?.let { line ->
          if ("no_version" in line) {
            return Version.Head()
          }
          VERSION_REGEX.find(line.trim())?.let { match ->
            return Version.Known(
              major = match.groups["major"]?.value?.toInt() ?: 0,
              minor = match.groups["minor"]?.value?.toInt() ?: 0,
              patch = match.groups["patch"]?.value?.toInt() ?: 0,
            )
          }
        }
      throw IllegalStateException("Bazel version not available")
    }
  }

  fun Path.run(
    inDirectory: Path,
    vararg args: String,
  ): Result<ProcessResult> =
    ProcessBuilder().command(this.toString(), *args).directory(inDirectory.toFile()).start()
      .let { process ->
        println("Running [${fileName} ${args.joinToString(" ")}]...")
        val executor = Executors.newCachedThreadPool()
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
          executor.shutdown()
          executor.awaitTermination(1, TimeUnit.SECONDS)
        }
      }

  private fun InputStream.streamTo(out: OutputStream): Callable<ByteArray> {
    return Callable {
      val result = ByteArrayOutputStream()
      BufferedInputStream(this).apply {
        val buffer = ByteArray(4096)
        var read = 0
        do {
          if (Thread.currentThread().isInterrupted) {
            out.flush()
            break
          }
          result.write(buffer, 0, read)
          out.write(buffer, 0, read)
          read = read(buffer)
        } while (read != -1)
      }
      result.toByteArray()
    }
  }

  private fun Path.hasModule() = resolve("MODULE").exists() || resolve("MODULE.bazel").exists()

  private fun Path.hasWorkspace() =
    resolve("WORKSPACE").exists() || resolve("WORKSPACE.bazel").exists()
}
