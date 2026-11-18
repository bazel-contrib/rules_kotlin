package io.bazel.kotlin.builder.tasks.jvm

import io.bazel.kotlin.builder.utils.bazelRuleKind
import io.bazel.kotlin.builder.utils.jars.JarCreator
import io.bazel.kotlin.model.JvmCompilationTask
import org.jacoco.core.instr.Instrumenter
import org.jacoco.core.runtime.OfflineInstrumentationAccessGenerator
import java.nio.file.FileVisitResult
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.Paths
import java.nio.file.SimpleFileVisitor
import java.nio.file.StandardOpenOption
import java.nio.file.attribute.BasicFileAttributes

internal fun JvmCompilationTask.createCoverageInstrumentedJar() {
  val instrumentedClassesDirectory = Paths.get(directories.coverageMetadataClasses)
  Files.createDirectories(instrumentedClassesDirectory)

  val instr = Instrumenter(OfflineInstrumentationAccessGenerator())

  instrumentRecursively(instr, instrumentedClassesDirectory, Paths.get(directories.classes))
  instrumentRecursively(instr, instrumentedClassesDirectory, Paths.get(directories.javaClasses))
  instrumentRecursively(
    instr,
    instrumentedClassesDirectory,
    Paths.get(directories.generatedClasses),
  )

  val pathsForCoverage =
    instrumentedClassesDirectory.resolve(
      "${Paths.get(outputs.jar).fileName}-paths-for-coverage.txt",
    )
  Files.write(
    pathsForCoverage,
    inputs.javaSourcesList + inputs.kotlinSourcesList,
  )

  JarCreator(
    path = Paths.get(outputs.jar),
    normalize = true,
    verbose = false,
  ).also {
    it.addDirectory(Paths.get(directories.classes))
    it.addDirectory(Paths.get(directories.javaClasses))
    it.addDirectory(Paths.get(directories.generatedClasses))
    it.addDirectory(instrumentedClassesDirectory)
    it.setJarOwner(info.jarOwnerLabel, info.bazelRuleKind)
    it.execute()
  }
}

private fun instrumentRecursively(
  instr: Instrumenter,
  metadataDir: Path,
  root: Path,
) {
  val visitor =
    object : SimpleFileVisitor<Path>() {
      override fun visitFile(
        file: Path,
        attrs: BasicFileAttributes,
      ): FileVisitResult {
        if (file.toFile().extension != "class") {
          return FileVisitResult.CONTINUE
        }

        val absoluteUninstrumentedCopy = Paths.get("$file.uninstrumented")
        val uninstrumentedCopy = metadataDir.resolve(root.relativize(absoluteUninstrumentedCopy))

        Files.createDirectories(uninstrumentedCopy.parent)
        Files.copy(file, uninstrumentedCopy)

        Files.newInputStream(uninstrumentedCopy).buffered().use { input ->
          Files
            .newOutputStream(file, StandardOpenOption.TRUNCATE_EXISTING)
            .buffered()
            .use { output ->
              instr.instrument(input, output, file.toString())
            }
        }

        return FileVisitResult.CONTINUE
      }
    }
  Files.walkFileTree(root, visitor)
}
