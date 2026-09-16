package io.bazel.kotlin.builder.tasks.jvm

import com.google.common.truth.Truth.assertThat
import com.google.devtools.build.lib.view.proto.Deps
import com.google.devtools.build.lib.view.proto.Deps.Dependency
import io.bazel.kotlin.builder.tasks.MergeJdeps
import io.bazel.kotlin.builder.tasks.jvm.JdepsMerger.Companion.JdepsMergerFlags
import io.bazel.kotlin.builder.utils.Flag
import io.bazel.kotlin.builder.utils.jars.JarCreator
import io.bazel.worker.Status
import io.bazel.worker.Status.SUCCESS
import io.bazel.worker.WorkerContext
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.JUnit4
import java.io.*
import java.nio.file.Files
import java.nio.file.Path

@RunWith(JUnit4::class)
class JdepsMergerTest {

  private val wrkDir = Files.createTempDirectory("JdepsMergerEnvironmentTest")
  private val merger = JdepsMerger()

  private fun jdeps(
    path: String,
    buildDeps: (Deps.Dependencies.Builder.() -> Deps.Dependencies.Builder),
  ): Path {
    val jdepsPath = Files.createDirectories(wrkDir.resolve("jdeps")).resolve(path)

    BufferedOutputStream(Files.newOutputStream(jdepsPath)).use {
      Deps.Dependencies.newBuilder().buildDeps().build().writeTo(it)
    }

    return jdepsPath
  }

  private fun out(name: String): Path {
    return Files.createDirectories(wrkDir.resolve("out")).resolve(name)
  }

  fun ktJvmLibrary(label: String, suffix: String = ""): String {
    val path = Files.createDirectories(wrkDir.resolve("out")).resolve("lib${label}$suffix.jar")
    JarCreator(
      path = path,
      normalize = true,
      verbose = false,
    ).also {
      it.setJarOwner(label, "kt_jvm_library")
      it.execute()
    }
    return path.toString()
  }

  @Test
  fun `large unicode dependency output preserves ordering and strongest kinds`() {
    val dependencies = (0 until 5000).map { index ->
      Dependency.newBuilder()
        .setPath("/classpath/κotlin/模块/dependency-$index.jar")
        .setKind(Dependency.Kind.UNUSED)
        .build()
    }
    val explicit = dependencies.filterIndexed { index, _ -> index % 3 == 0 }
      .map { it.toBuilder().setKind(Dependency.Kind.EXPLICIT).build() }
    val first = jdeps("large-first.jdeps") { addAllDependency(dependencies) }
    val second = jdeps("large-second.jdeps") { addAllDependency(explicit) }
    val output = out("large-merged.jdeps")
    val result = WorkerContext.run {
      doTask("large merge") { taskCtx ->
        MergeJdeps(merger).invoke(
          taskCtx,
          args {
            flag(JdepsMergerFlags.TARGET_LABEL, "//large:unicode")
            input(first)
            input(second)
            flag(JdepsMergerFlags.OUTPUT, output)
            flag(JdepsMergerFlags.REPORT_UNUSED_DEPS, "off")
          },
        )
      }
    }
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//large:unicode")
      .setSuccess(true)
      .addAllDependency(
        dependencies.mapIndexed { index, dependency ->
          if (index % 3 == 0) dependency.toBuilder().setKind(Dependency.Kind.EXPLICIT).build()
          else dependency
        }.sortedBy { it.path },
      )
      .build()
      .toByteArray()
    assertThat(result.status).isEqualTo(SUCCESS)
    assertThat(expected.size).isGreaterThan(8192)
    assertThat(Files.readAllBytes(output)).isEqualTo(expected)
  }

  @Test
  fun `merge all deps`() {

    val kotlinJdeps = jdeps("kt.jdeps") {
      addDependency(
        with(Dependency.newBuilder()) {
          kind = Dependency.Kind.EXPLICIT
          path = "/path/to/kt_dep.jar"
          build()
        },
      )
    }

    val javaJdeps = jdeps("java.jdeps") {
      addDependency(
        with(Dependency.newBuilder()) {
          kind = Dependency.Kind.EXPLICIT
          path = "/path/to/java_dep.jar"
          build()
        },
      )
    }

    val mergedJdeps = out("merged.jdeps")

    val result = WorkerContext.run {
      doTask("jdepsmerge") { taskCtx ->
        MergeJdeps(merger = merger).invoke(
          taskCtx,
          args {
            flag(JdepsMergerFlags.TARGET_LABEL, "//foo/bar:baz")
            input(kotlinJdeps)
            input(javaJdeps)
            flag(JdepsMergerFlags.OUTPUT, mergedJdeps)
            flag(JdepsMergerFlags.REPORT_UNUSED_DEPS, "off")
          },
        )
      }
    }

    assertThat(result.status).isEqualTo(SUCCESS)

    val depsProto = depsProto(mergedJdeps)
    assertThat(depsProto.ruleLabel).isEqualTo("//foo/bar:baz")
    assertThat(depsProto.dependencyList.map { it.path }).containsExactly(
      "/path/to/kt_dep.jar",
      "/path/to/java_dep.jar",
    )
  }

  @Test
  fun `merge conflicting deps`() {

    val kotlinJdeps = jdeps("kt.jdeps") {
      addDependency(
        with(Dependency.newBuilder()) {
          kind = Dependency.Kind.UNUSED
          path = "/path/to/shared_dep.jar"
          build()
        },
      )
    }

    val javaJdeps = jdeps("java.jdeps") {
      addDependency(
        with(Dependency.newBuilder()) {
          kind = Dependency.Kind.EXPLICIT
          path = "/path/to/shared_dep.jar"
          build()
        },
      )
    }

    val mergedJdeps = out("merged.jdeps")

    val result = WorkerContext.run {
      doTask("jdepsmerge") { taskCtx ->
        MergeJdeps(merger = merger).invoke(
          taskCtx,
          args {
            flag(JdepsMergerFlags.TARGET_LABEL, "//foo/bar:baz")
            input(kotlinJdeps)
            input(javaJdeps)
            flag(JdepsMergerFlags.OUTPUT, mergedJdeps)
            flag(JdepsMergerFlags.REPORT_UNUSED_DEPS, "off")
          },
        )
      }
    }

    assertThat(result.status).isEqualTo(SUCCESS)

    val depsProto = depsProto(mergedJdeps)
    assertThat(depsProto.dependencyList.map { it.path }).containsExactly("/path/to/shared_dep.jar")
    assertThat(depsProto.dependencyList.map { it.kind }).containsExactly(Dependency.Kind.EXPLICIT)
  }

  @Test
  fun `unused deps report warning`() {

    val unusedKotlinDep = ktJvmLibrary("kotlin_dep")
    val kotlinJdeps = jdeps("kt.jdeps") {
      addDependency(
        with(Dependency.newBuilder()) {
          kind = Dependency.Kind.UNUSED
          path = unusedKotlinDep
          build()
        },
      )
    }

    val javaJdeps = jdeps("java.jdeps") {
      addDependency(
        with(Dependency.newBuilder()) {
          kind = Dependency.Kind.EXPLICIT
          path = ktJvmLibrary("java_dep")
          build()
        },
      )
    }

    val mergedJdeps = out("merged.jdeps")

    val result = WorkerContext.run {
      doTask("jdepsmerge") { taskCtx ->
        MergeJdeps(merger = merger).invoke(
          taskCtx,
          args {
            input(kotlinJdeps)
            input(javaJdeps)
            flag(JdepsMergerFlags.TARGET_LABEL, "//foo/bar:baz")
            flag(JdepsMergerFlags.OUTPUT, mergedJdeps)
            flag(JdepsMergerFlags.REPORT_UNUSED_DEPS, "warn")
          },
        )
      }
    }
    assertThat(result.status).isEqualTo(SUCCESS)
    assertThat(result.log.out.toString()).contains("'remove deps kotlin_dep' //foo/bar:baz")

    val depsProto = depsProto(mergedJdeps)
    assertThat(
      depsProto.dependencyList
        .filter { it.kind == Dependency.Kind.UNUSED }
        .map { it.path },
    ).containsExactly(unusedKotlinDep)
  }

  @Test
  fun `unused deps report error`() {

    val unusedKotlinDep = ktJvmLibrary("kotlin_dep")
    val kotlinJdeps = jdeps("kt.jdeps") {
      addDependency(
        with(Dependency.newBuilder()) {
          kind = Dependency.Kind.UNUSED
          path = unusedKotlinDep
          build()
        },
      )
    }

    val javaJdeps = jdeps("java.jdeps") {
      addDependency(
        with(Dependency.newBuilder()) {
          kind = Dependency.Kind.EXPLICIT
          path = ktJvmLibrary("java_dep")
          build()
        },
      )
    }

    val mergedJdeps = out("merged.jdeps")

    val worker = MergeJdeps(merger)
    val result = WorkerContext.run {
      doTask("jdepsmerge") { taskCtx ->
        worker.invoke(
          taskCtx,
          args {
            input(kotlinJdeps)
            input(javaJdeps)
            flag(JdepsMergerFlags.TARGET_LABEL, "//foo/bar:baz")
            flag(JdepsMergerFlags.OUTPUT, mergedJdeps)
            flag(JdepsMergerFlags.REPORT_UNUSED_DEPS, "error")
          },
        )
      }
    }
    assertThat(result.status).isEqualTo(Status.ERROR)
    assertThat(result.log.out.toString()).contains("'remove deps kotlin_dep' //foo/bar:baz")

    val depsProto = depsProto(mergedJdeps)
    assertThat(
      depsProto.dependencyList
        .filter { it.kind == Dependency.Kind.UNUSED }
        .map { it.path },
    ).containsExactly(unusedKotlinDep)
  }

  @Test
  fun `unused deps multiple jars for label`() {

    val unusedKotlinDepA = ktJvmLibrary("kotlin_dep", "_a")
    val unusedKotlinDepB = ktJvmLibrary("kotlin_dep", "_b")
    val kotlinJdeps = jdeps("kt.jdeps") {
      addDependency(
        with(Dependency.newBuilder()) {
          kind = Dependency.Kind.UNUSED
          path = unusedKotlinDepA
          build()
        },
      )
      addDependency(
        with(Dependency.newBuilder()) {
          kind = Dependency.Kind.UNUSED
          path = unusedKotlinDepB
          build()
        },
      )
    }

    val mergedJdeps = out("merged.jdeps")

    val result = WorkerContext.run {
      doTask("jdepsmerge") { taskCtx ->
        MergeJdeps(merger = merger).invoke(
          taskCtx,
          args {
            input(kotlinJdeps)
            flag(JdepsMergerFlags.TARGET_LABEL, "//foo/bar:baz")
            flag(JdepsMergerFlags.OUTPUT, mergedJdeps)
            flag(JdepsMergerFlags.REPORT_UNUSED_DEPS, "warn")
          },
        )
      }
    }
    assertThat(result.status).isEqualTo(SUCCESS)
    assertThat(result.log.out.toString()).contains("'remove deps kotlin_dep' //foo/bar:baz")
  }

  @Test
  fun `used deps multiple jars for label`() {

    val unusedKotlinDep = ktJvmLibrary("kotlin_dep", "_a")
    val usedKotlinDep = ktJvmLibrary("kotlin_dep", "_b")
    val kotlinJdeps = jdeps("kt.jdeps") {
      addDependency(
        with(Dependency.newBuilder()) {
          kind = Dependency.Kind.UNUSED
          path = unusedKotlinDep
          build()
        },
      )
      addDependency(
        with(Dependency.newBuilder()) {
          kind = Dependency.Kind.EXPLICIT
          path = usedKotlinDep
          build()
        },
      )
    }

    val mergedJdeps = out("merged.jdeps")

    val result = WorkerContext.run {
      doTask("jdepsmerge") { taskCtx ->
        MergeJdeps(merger = merger).invoke(
          taskCtx,
          args {
            input(kotlinJdeps)
            flag(JdepsMergerFlags.TARGET_LABEL, "//foo/bar:baz")
            flag(JdepsMergerFlags.OUTPUT, mergedJdeps)
            flag(JdepsMergerFlags.REPORT_UNUSED_DEPS, "warn")
          },
        )
      }
    }
    assertThat(result.status).isEqualTo(SUCCESS)

    val depsProto = depsProto(mergedJdeps)
    assertThat(
      depsProto.dependencyList
        .filter { it.kind == Dependency.Kind.EXPLICIT }
        .map { it.path },
    ).containsExactly(usedKotlinDep)
  }

  private fun depsProto(mergedJdeps: Path) =
    Deps.Dependencies.parseFrom(BufferedInputStream(Files.newInputStream(mergedJdeps)))

  private fun args(init: ArgsBuilder.() -> Unit) = with(ArgsBuilder()) {
    init()
    list()
  }

  class ArgsBuilder(val args: MutableMap<Flag, MutableList<String>> = mutableMapOf()) {
    fun flag(flag: Flag, value: String) {
      args[flag] = (args[flag] ?: mutableListOf()).also {
        it.add(value)
      }
    }

    fun flag(flag: Flag, p: Path) {
      flag(flag, p.toString())
    }

    fun input(src: Path) {
      flag(JdepsMergerFlags.INPUTS, src.toString())
    }

    fun list(): List<String> {
      return args.flatMap { entry ->
        entry.value.flatMap { value ->
          listOf(entry.key.flag, value)
        }
      }
    }
  }
}
