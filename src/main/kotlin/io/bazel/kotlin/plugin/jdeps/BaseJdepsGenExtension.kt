package io.bazel.kotlin.plugin.jdeps

import com.google.devtools.build.lib.view.proto.Deps
import io.bazel.kotlin.builder.utils.jars.JarOwner
import org.jetbrains.kotlin.config.CompilerConfiguration
import java.io.BufferedOutputStream
import java.io.File
import java.nio.file.Paths

abstract class BaseJdepsGenExtension(
  protected val configuration: CompilerConfiguration,
) {
  protected fun onAnalysisCompleted(
    explicitClassesCanonicalPaths: Set<String>,
    implicitClassesCanonicalPaths: Set<String>,
  ) {
    val directDeps = configuration.getList(JdepsGenConfigurationKeys.DIRECT_DEPENDENCIES)
    val targetLabel = configuration.getNotNull(JdepsGenConfigurationKeys.TARGET_LABEL)
    val fullClasspath = configuration.getList(JdepsGenConfigurationKeys.FULL_CLASSPATH)

    // Create mapping from canonical paths to original classpath paths
    val canonicalToClasspath = createCanonicalToClasspathMap(fullClasspath)

    val explicitDeps = createDepsMap(explicitClassesCanonicalPaths, canonicalToClasspath)

    doWriteJdeps(
      directDeps,
      targetLabel,
      explicitDeps,
      implicitClassesCanonicalPaths,
      canonicalToClasspath,
    )

    doStrictDeps(configuration, targetLabel, directDeps, explicitDeps)
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

  private fun doWriteJdeps(
    directDeps: List<String>,
    targetLabel: String,
    explicitDeps: Map<String, List<String>>,
    implicitClassesCanonicalPaths: Set<String>,
    canonicalToClasspath: Map<String, String>,
  ) {
    val implicitDeps = createDepsMap(implicitClassesCanonicalPaths, canonicalToClasspath)

    // Build and write out deps.proto
    val jdepsOutput = configuration.getNotNull(JdepsGenConfigurationKeys.OUTPUT_JDEPS)

    val rootBuilder = Deps.Dependencies.newBuilder()
    rootBuilder.success = true
    rootBuilder.ruleLabel = targetLabel

    val unusedDeps = directDeps.subtract(explicitDeps.keys)
    unusedDeps.forEach { jarPath ->
      val dependency = Deps.Dependency.newBuilder()
      dependency.kind = Deps.Dependency.Kind.UNUSED
      dependency.path = jarPath
      rootBuilder.addDependency(dependency)
    }

    explicitDeps.forEach { (jarPath, _) ->
      val dependency = Deps.Dependency.newBuilder()
      dependency.kind = Deps.Dependency.Kind.EXPLICIT
      dependency.path = jarPath
      rootBuilder.addDependency(dependency)
    }

    implicitDeps.keys.subtract(explicitDeps.keys).forEach {
      val dependency = Deps.Dependency.newBuilder()
      dependency.kind = Deps.Dependency.Kind.IMPLICIT
      dependency.path = it
      rootBuilder.addDependency(dependency)
    }

    BufferedOutputStream(File(jdepsOutput).outputStream()).use {
      it.write(rootBuilder.buildSorted().toByteArray())
    }
  }

  private fun doStrictDeps(
    compilerConfiguration: CompilerConfiguration,
    targetLabel: String,
    directDeps: List<String>,
    explicitDeps: Map<String, List<String>>,
  ) {
    when (compilerConfiguration.getNotNull(JdepsGenConfigurationKeys.STRICT_KOTLIN_DEPS)) {
      "warn" -> checkStrictDeps(explicitDeps, directDeps, targetLabel)
      "error" -> {
        if (checkStrictDeps(explicitDeps, directDeps, targetLabel)) {
          error(
            "Strict Deps Violations - please fix",
          )
        }
      }
    }
  }

  /**
   * Prints strict deps warnings and returns true if violations were found.
   */
  private fun checkStrictDeps(
    result: Map<String, List<String>>,
    directDeps: List<String>,
    targetLabel: String,
  ): Boolean {
    val missingStrictDeps =
      result.keys
        .filter { !directDeps.contains(it) }
        .map { JarOwner.readJarOwnerFromManifest(Paths.get(it)) }

    if (missingStrictDeps.isNotEmpty()) {
      val missingStrictLabels = missingStrictDeps.mapNotNull { it.label }

      val open = "\u001b[35m\u001b[1m"
      val close = "\u001b[0m"

      var command =
        """
        $open ** Please add the following dependencies:$close
        ${
          missingStrictDeps.map { it.label ?: it.jar }.joinToString(" ")
        } to $targetLabel
        """

      if (missingStrictLabels.isNotEmpty()) {
        command += """$open ** You can use the following buildozer command:$close
        buildozer 'add deps ${
          missingStrictLabels.joinToString(" ")
        }' $targetLabel
        """
      }

      println(command.trimIndent())
      return true
    }
    return false
  }
}

private fun Deps.Dependencies.Builder.buildSorted(): Deps.Dependencies {
  val sortedDeps = dependencyList.sortedBy { it.path }
  sortedDeps.forEachIndexed { index, dep ->
    setDependency(index, dep)
  }
  return build()
}
