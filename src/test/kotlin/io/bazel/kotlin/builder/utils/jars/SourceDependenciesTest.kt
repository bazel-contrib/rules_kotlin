package io.bazel.kotlin.builder.utils.jars

import com.google.common.truth.Truth.assertThat
import com.google.devtools.build.lib.view.proto.Deps.Dependency.Kind
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.JUnit4
import java.nio.file.Files

@RunWith(JUnit4::class)
class SourceDependenciesTest {
  private fun kindsByPath(
    directDependencies: List<String>,
    explicitJars: List<String>,
    implicitJars: List<String>,
  ): List<Pair<String, Kind>> =
    jdepsOf("//pkg:target", directDependencies, explicitJars, implicitJars)
      .dependencyList
      .map { it.path to it.kind }

  @Test
  fun `jdeps list the unused direct dependencies and the used jars sorted by path`() {
    assertThat(
      kindsByPath(
        directDependencies = listOf("d.jar", "a.jar", "d.jar"),
        explicitJars = listOf("c.jar", "a.jar"),
        implicitJars = listOf("b.jar", "c.jar"),
      ),
    ).containsExactly(
      "a.jar" to Kind.EXPLICIT,
      "b.jar" to Kind.IMPLICIT,
      "c.jar" to Kind.EXPLICIT,
      "d.jar" to Kind.UNUSED,
    ).inOrder()
  }

  @Test
  fun `a direct dependency used only implicitly lists as unused, then implicit`() {
    assertThat(
      kindsByPath(
        directDependencies = listOf("a.jar"),
        explicitJars = emptyList(),
        implicitJars = listOf("a.jar"),
      ),
    ).containsExactly("a.jar" to Kind.UNUSED, "a.jar" to Kind.IMPLICIT).inOrder()
  }

  @Test
  fun `jdeps record the label and success`() {
    val jdeps = jdepsOf("//pkg:target", emptyList(), emptyList(), emptyList())

    assertThat(jdeps.ruleLabel).isEqualTo("//pkg:target")
    assertThat(jdeps.success).isTrue()
    assertThat(jdeps.dependencyList).isEmpty()
  }

  @Test
  fun `the per-source file keeps every source, including those without dependencies`() {
    val file = Files.createTempDirectory("SourceDependenciesTest").resolve("source_deps")
    val dependencies =
      mapOf(
        "/src/A.kt" to SourceDependencies(setOf("a.jar", "b.jar"), setOf("c.jar")),
        "/src/B.kt" to SourceDependencies(emptySet(), emptySet()),
        "/src/C.kt" to SourceDependencies(emptySet(), setOf("c.jar")),
      )

    SourceDependenciesFile.write(file, dependencies)

    assertThat(SourceDependenciesFile.read(file)).isEqualTo(dependencies)
  }

  @Test
  fun `an update replaces the analyzed sources and keeps the others`() {
    val file = Files.createTempDirectory("SourceDependenciesTest").resolve("source_deps")
    SourceDependenciesFile.write(
      file,
      mapOf(
        "/src/A.kt" to SourceDependencies(setOf("a.jar"), emptySet()),
        "/src/B.kt" to SourceDependencies(setOf("b.jar"), emptySet()),
      ),
    )

    SourceDependenciesFile.update(
      file,
      mapOf(
        "/src/A.kt" to SourceDependencies(emptySet(), emptySet()),
        "/src/C.kt" to SourceDependencies(setOf("c.jar"), emptySet()),
      ),
    )

    assertThat(SourceDependenciesFile.read(file))
      .containsExactly(
        "/src/A.kt",
        SourceDependencies(emptySet(), emptySet()),
        "/src/B.kt",
        SourceDependencies(setOf("b.jar"), emptySet()),
        "/src/C.kt",
        SourceDependencies(setOf("c.jar"), emptySet()),
      )
  }

  @Test
  fun `a missing per-source file has no sources`() {
    val file = Files.createTempDirectory("SourceDependenciesTest").resolve("missing")

    assertThat(SourceDependenciesFile.read(file)).isEmpty()
  }
}
