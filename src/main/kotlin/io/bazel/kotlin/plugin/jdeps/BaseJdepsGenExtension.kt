package io.bazel.kotlin.plugin.jdeps

import io.bazel.kotlin.builder.utils.jars.SourceDependencies
import io.bazel.kotlin.builder.utils.jars.SourceDependenciesFile
import org.jetbrains.kotlin.config.CompilerConfiguration
import java.io.File
import java.nio.file.Paths

abstract class BaseJdepsGenExtension(
  protected val configuration: CompilerConfiguration,
) {
  /**
   * Records the dependencies of the analyzed sources in the output. Incremental compilation
   * analyzes only the recompiled sources, possibly over several iterations: the output keeps the
   * dependencies of the other sources.
   *
   * @param explicitClassesBySource the classes each analyzed source uses explicitly, by the
   *   source's path.
   * @param implicitClassesBySource the classes each analyzed source needs implicitly.
   */
  protected fun onAnalysisCompleted(
    explicitClassesBySource: Map<String, Set<String>>,
    implicitClassesBySource: Map<String, Set<String>>,
  ) {
    val output = configuration.getNotNull(JdepsGenConfigurationKeys.OUTPUT)
    val fullClasspath = configuration.getList(JdepsGenConfigurationKeys.FULL_CLASSPATH)

    // Create mapping from canonical paths to original classpath paths
    val canonicalToClasspath = createCanonicalToClasspathMap(fullClasspath)

    val analyzed = explicitClassesBySource.keys + implicitClassesBySource.keys
    val dependencies =
      analyzed.associateWith { source ->
        SourceDependencies(
          explicitJars =
            createDepsMap(explicitClassesBySource[source].orEmpty(), canonicalToClasspath).keys,
          implicitJars =
            createDepsMap(implicitClassesBySource[source].orEmpty(), canonicalToClasspath).keys,
        )
      }
    SourceDependenciesFile.update(Paths.get(output), dependencies)
  }

  /**
   * Creates a mapping from canonical filesystem paths to original classpath paths.
   * This ensures jdeps uses the same paths that were on the compiler's classpath.
   * When multiple classpath entries point to the same canonical file, prefer runfiles paths.
   */
  private fun createCanonicalToClasspathMap(classpathEntries: List<String>): Map<String, String> {
    val mapping = mutableMapOf<String, String>()

    // Create canonical -> original mapping
    // Process entries and prefer runfiles paths over execroot paths
    classpathEntries.forEach { classpathPath ->
      val canonicalPath = canonicalizePath(classpathPath)
      val existing = mapping[canonicalPath]
      // Only update if no existing entry, or if current path is a runfiles path
      // and existing is not
      if (existing == null ||
        (classpathPath.contains("/runfiles/") && !existing.contains("/runfiles/"))
      ) {
        mapping[canonicalPath] = classpathPath
      }
    }
    return mapping
  }

  /**
   * Returns a map of jars to classes loaded from those jars.
   * Uses the canonical-to-classpath mapping to preserve original classpath paths.
   */
  private fun createDepsMap(
    classes: Set<String>,
    canonicalToClasspath: Map<String, String>,
  ): Map<String, List<String>> {
    val jarsToClasses = mutableMapOf<String, MutableList<String>>()
    classes.forEach {
      val parts = it.split("!/")
      val jarPath = parts[0]
      if (jarPath.endsWith(".jar")) {
        // Canonicalize for lookup so K2's forward-slash paths match classpath entries on Windows.
        val canonicalJarPath = canonicalizePath(jarPath)
        // Map back to original classpath path
        val classpathJarPath = canonicalToClasspath[canonicalJarPath] ?: jarPath
        jarsToClasses.computeIfAbsent(classpathJarPath) { ArrayList() }.add(parts[1])
      }
    }
    return jarsToClasses
  }

  private fun canonicalizePath(path: String): String {
    val normalizedPath = if (File.separatorChar == '\\') path.replace('/', '\\') else path
    return try {
      File(normalizedPath).canonicalPath
    } catch (e: Exception) {
      try {
        Paths
          .get(normalizedPath)
          .toAbsolutePath()
          .normalize()
          .toString()
      } catch (_: Exception) {
        normalizedPath
      }
    }
  }
}
