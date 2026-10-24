package io.bazel.kotlin.builder.utils.jars

import com.google.devtools.build.lib.view.proto.Deps
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.nio.file.Path

/**
 * The jdeps of a compilation: the direct dependencies no source uses, the jars the sources use
 * explicitly, and the ones they need only implicitly, e.g. for a supertype. The jdeps plugin and
 * the incremental compilation in the worker both write their jdeps with this, so that an
 * incremental compilation's jdeps are the bytes a full compilation writes.
 */
fun jdepsOf(
  label: String,
  directDependencies: List<String>,
  explicitJars: Collection<String>,
  implicitJars: Collection<String>,
): Deps.Dependencies {
  val explicit = explicitJars.toSet()

  fun dependency(
    kind: Deps.Dependency.Kind,
    jar: String,
  ) = Deps.Dependency
    .newBuilder()
    .setKind(kind)
    .setPath(jar)
    .build()
  val dependencies =
    directDependencies.distinct().filterNot(explicit::contains).map {
      dependency(Deps.Dependency.Kind.UNUSED, it)
    } +
      explicit.map { dependency(Deps.Dependency.Kind.EXPLICIT, it) } +
      implicitJars.distinct().filterNot(explicit::contains).map {
        dependency(Deps.Dependency.Kind.IMPLICIT, it)
      }
  return Deps.Dependencies
    .newBuilder()
    .setSuccess(true)
    .setRuleLabel(label)
    // A stable sort: a direct dependency only used implicitly lists as unused, then implicit.
    .addAllDependency(dependencies.sortedBy { it.path })
    .build()
}

/** The jars one source file uses. */
data class SourceDependencies(
  val explicitJars: Set<String>,
  val implicitJars: Set<String>,
)

/**
 * The jars each source file of a compilation uses, by the source's path as the compiler reports
 * it. Incremental compilation recompiles some sources only: the jdeps plugin replaces the entries
 * of the sources it analyzed, so the file describes every source of the target.
 *
 * One line per used jar: `explicit|implicit`, the jar, and the source, separated by tabs. A source
 * without dependencies has a line with the kind `none`.
 */
object SourceDependenciesFile {
  private const val EXPLICIT = "explicit"
  private const val IMPLICIT = "implicit"
  private const val NONE = "none"

  fun read(path: Path): Map<String, SourceDependencies> {
    if (!Files.isRegularFile(path)) {
      return emptyMap()
    }
    val explicit = LinkedHashMap<String, MutableSet<String>>()
    val implicit = LinkedHashMap<String, MutableSet<String>>()
    Files.readAllLines(path, StandardCharsets.UTF_8).forEach { line ->
      val (kind, jar, source) = line.split('\t', limit = 3)
      explicit.getOrPut(source) { linkedSetOf() }
      implicit.getOrPut(source) { linkedSetOf() }
      when (kind) {
        EXPLICIT -> {
          explicit.getValue(source).add(jar)
        }

        IMPLICIT -> {
          implicit.getValue(source).add(jar)
        }

        NONE -> {}

        else -> {
          error("$path: unknown dependency kind in: $line")
        }
      }
    }
    return explicit.keys.associateWith {
      SourceDependencies(explicit.getValue(it), implicit.getValue(it))
    }
  }

  fun write(
    path: Path,
    dependencies: Map<String, SourceDependencies>,
  ) {
    val lines =
      dependencies.flatMap { (source, used) ->
        if (used.explicitJars.isEmpty() && used.implicitJars.isEmpty()) {
          listOf("$NONE\t\t$source")
        } else {
          used.explicitJars.map { "$EXPLICIT\t$it\t$source" } +
            used.implicitJars.map { "$IMPLICIT\t$it\t$source" }
        }
      }
    Files.write(path, lines, StandardCharsets.UTF_8)
  }

  /**
   * Replaces the dependencies of the [analyzed] sources and keeps those of the other sources,
   * which an incremental compilation did not recompile.
   */
  fun update(
    path: Path,
    analyzed: Map<String, SourceDependencies>,
  ) {
    write(path, read(path).filterKeys { it !in analyzed } + analyzed)
  }
}
