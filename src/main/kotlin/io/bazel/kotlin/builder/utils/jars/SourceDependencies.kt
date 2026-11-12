package io.bazel.kotlin.builder.utils.jars

import com.google.devtools.build.lib.view.proto.Deps
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.StandardOpenOption

/**
 * The jdeps of a compilation: the direct dependencies no source uses, the jars the sources use
 * explicitly, and the ones they need only implicitly, e.g. for a supertype. The builder writes
 * them from the dependencies of each source, see [SourceDependenciesFile], so that a compilation
 * of some of the sources writes the bytes a compilation of all of them writes.
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
 * it. Incremental compilation recompiles some sources only, possibly over several rounds: the jdeps
 * plugin appends a record for each source a round analyzes, without reading the file, and a
 * source's last record replaces its earlier ones.
 *
 * A record is a `source` line, then an `explicit` or `implicit` line for each jar the source uses:
 * the kind and the path, separated by a tab.
 */
object SourceDependenciesFile {
  private const val SOURCE = "source"
  private const val EXPLICIT = "explicit"
  private const val IMPLICIT = "implicit"

  /** The dependencies of each source, from its last record. */
  fun read(path: Path): Map<String, SourceDependencies> {
    if (!Files.isRegularFile(path)) {
      return emptyMap()
    }
    val explicit = LinkedHashMap<String, MutableSet<String>>()
    val implicit = LinkedHashMap<String, MutableSet<String>>()
    var source: String? = null

    fun currentSource(line: String) = checkNotNull(source) { "$path: no source before: $line" }
    Files.readAllLines(path, StandardCharsets.UTF_8).forEach { line ->
      val (kind, value) = line.split('\t', limit = 2)
      when (kind) {
        SOURCE -> {
          explicit[value] = linkedSetOf()
          implicit[value] = linkedSetOf()
          source = value
        }

        EXPLICIT -> {
          explicit.getValue(currentSource(line)).add(value)
        }

        IMPLICIT -> {
          implicit.getValue(currentSource(line)).add(value)
        }

        else -> {
          error("$path: unknown dependency kind in: $line")
        }
      }
    }
    return explicit.keys.associateWith {
      SourceDependencies(explicit.getValue(it), implicit.getValue(it))
    }
  }

  /** Writes a record for each source, replacing the file. */
  fun write(
    path: Path,
    dependencies: Map<String, SourceDependencies>,
  ) {
    Files.write(path, records(dependencies), StandardCharsets.UTF_8)
  }

  /** Appends a record for each source, which replaces the source's earlier records. */
  fun append(
    path: Path,
    dependencies: Map<String, SourceDependencies>,
  ) {
    Files.write(
      path,
      records(dependencies),
      StandardCharsets.UTF_8,
      StandardOpenOption.CREATE,
      StandardOpenOption.APPEND,
    )
  }

  private fun records(dependencies: Map<String, SourceDependencies>): List<String> =
    dependencies.flatMap { (source, used) ->
      listOf("$SOURCE\t$source") +
        used.explicitJars.map { "$EXPLICIT\t$it" } +
        used.implicitJars.map { "$IMPLICIT\t$it" }
    }
}
