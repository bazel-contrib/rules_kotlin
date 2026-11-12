package io.bazel.kotlin.plugin.jdeps

import io.bazel.kotlin.builder.utils.jars.SourceDependencies
import io.bazel.kotlin.builder.utils.jars.SourceDependenciesFile
import io.bazel.kotlin.plugin.jdeps.k2.SourceClasses
import org.jetbrains.kotlin.config.CompilerConfiguration
import java.io.File
import java.nio.file.Paths

abstract class BaseJdepsGenExtension(
  protected val configuration: CompilerConfiguration,
) {
  /**
   * Appends the dependencies of the analyzed sources to the output, without reading it.
   * Incremental compilation analyzes only the recompiled sources, possibly over several rounds:
   * the builder merges the records of every round.
   *
   * @param classesBySource the classes each analyzed source uses, by the source's path.
   */
  internal fun onAnalysisCompleted(classesBySource: Map<String, SourceClasses>) {
    val output = configuration.getNotNull(JdepsGenConfigurationKeys.OUTPUT)
    val fullClasspath = configuration.getList(JdepsGenConfigurationKeys.FULL_CLASSPATH)

    // Create mapping from canonical paths to original classpath paths
    val canonicalToClasspath = createCanonicalToClasspathMap(fullClasspath)

    // Sources share most of their jars: resolve each jar once.
    val classpathJars = HashMap<String, String>()

    fun jarsOf(classes: Set<String>): Set<String> =
      classes.mapNotNullTo(LinkedHashSet()) {
        classpathJarOf(it, canonicalToClasspath, classpathJars)
      }

    SourceDependenciesFile.append(
      Paths.get(output),
      classesBySource.mapValues { (_, classes) ->
        SourceDependencies(jarsOf(classes.explicit), jarsOf(classes.implicit))
      },
    )
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
   * The classpath entry of the jar a class is loaded from, or null if it is not loaded from a jar.
   * Uses the canonical-to-classpath mapping to preserve original classpath paths.
   *
   * @param classpathJars the classpath entries of the jars resolved so far, by the jar's path.
   */
  private fun classpathJarOf(
    classPath: String,
    canonicalToClasspath: Map<String, String>,
    classpathJars: MutableMap<String, String>,
  ): String? {
    val jarPath = classPath.substringBefore("!/")
    if (!jarPath.endsWith(".jar")) {
      return null
    }
    return classpathJars.getOrPut(jarPath) {
      // Canonicalize for lookup so K2's forward-slash paths match classpath entries on Windows.
      canonicalToClasspath[canonicalizePath(jarPath)] ?: jarPath
    }
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
