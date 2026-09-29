package io.bazel.kotlin.test

import com.google.devtools.build.runfiles.Runfiles
import org.apache.commons.compress.archivers.tar.TarArchiveInputStream
import java.io.BufferedInputStream
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.io.OutputStream
import java.nio.charset.StandardCharsets.UTF_8
import java.nio.file.Files
import java.nio.file.Path
import java.util.concurrent.Callable
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.zip.GZIPInputStream
import kotlin.io.path.createDirectories
import kotlin.io.path.inputStream

abstract class BazelIntegrationTestBase {
  protected fun env(name: String): String = requireNotNull(System.getenv(name)) { "Missing $name" }

  // Data belongs to the outer integration test, not an individual runner's runfiles.
  private val runfiles = Runfiles.preload(mapOf("RUNFILES_DIR" to env("TEST_SRCDIR"))).unmapped()
  protected val root: Path = Path.of(env("TEST_TMPDIR"))
  protected val bazel: Path =
    Path.of(env("BIT_BAZEL_BINARY")).also {
      println("Bazel launcher: $it\nResolved path: ${it.toRealPath()}")
    }

  protected fun runfile(path: String): Path = Path.of(runfiles.rlocation(path))

  protected fun unpackRelease(archiveRunfile: String): Path {
    val release = root.resolve("rules_kotlin").createDirectories()
    TarArchiveInputStream(GZIPInputStream(runfile(archiveRunfile).inputStream())).use { tar ->
      generateSequence(tar::getNextEntry).forEach { entry ->
        val destination = release.resolve(entry.name).normalize()
        require(destination.startsWith(release)) { "Archive entry escapes output: $entry" }
        when {
          entry.isDirectory -> {
            destination.createDirectories()
          }

          entry.isFile -> {
            destination.parent.createDirectories()
            Files.copy(tar, destination)
          }

          else -> {
            error("Unsupported archive entry: $entry")
          }
        }
      }
    }
    return release
  }

  data class ProcessResult(
    val exit: Int,
    val stdOut: ByteArray,
    val stdErr: ByteArray,
  )

  protected fun Path.run(
    inDirectory: Path,
    vararg args: String,
  ): Result<ProcessResult> =
    ProcessBuilder()
      .command(this.toString(), *args)
      .directory(inDirectory.toFile())
      .apply { environment().putAll(runfiles.envVars) }
      .start()
      .let { process ->
        println("Running [$fileName ${args.joinToString(" ")}]...")
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
      return@Callable result.toByteArray()
    }
  }
}
