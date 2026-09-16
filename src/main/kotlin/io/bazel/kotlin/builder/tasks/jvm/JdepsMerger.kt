package io.bazel.kotlin.builder.tasks.jvm

import com.google.devtools.build.lib.view.proto.Deps
import io.bazel.kotlin.builder.utils.ArgMap
import io.bazel.kotlin.builder.utils.ArgMaps
import io.bazel.kotlin.builder.utils.Flag
import io.bazel.kotlin.builder.utils.jars.JarHelper.Companion.INJECTING_RULE_KIND
import io.bazel.kotlin.builder.utils.jars.JarHelper.Companion.TARGET_LABEL
import io.bazel.worker.WorkerContext
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.File
import java.io.IOException
import java.io.UncheckedIOException
import java.nio.charset.StandardCharsets
import java.nio.file.FileSystems
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.Paths
import java.util.jar.JarFile

/**
 * Persistent worker capable command line program for merging multiple Jdeps files into a single
 * file.
 */
class JdepsMerger {
  companion object {
    @JvmStatic
    private val FLAGFILE_RE = Regex("""^--flagfile=((.*)-(\d+).params)$""")

    /**
     * Declares the flags used by the java builder.
     */
    enum class JdepsMergerFlags(
      override val flag: String,
    ) : Flag {
      INPUTS("--inputs"),
      OUTPUT("--output"),
      TARGET_LABEL("--target_label"),
      REPORT_UNUSED_DEPS("--report_unused_deps"),
    }

    private fun readJarOwnerFromManifest(jarPath: Path): JarOwner {
      try {
        JarFile(jarPath.toFile()).use { jarFile ->
          val manifest = jarFile.manifest ?: return JarOwner(jarPath)
          val attributes = manifest.mainAttributes
          val label =
            attributes[TARGET_LABEL] as String?
              ?: return JarOwner(jarPath)
          val injectingRuleKind = attributes[INJECTING_RULE_KIND] as String?
          return JarOwner(jarPath, label, injectingRuleKind)
        }
      } catch (e: IOException) {
        // This jar file pretty much has to exist.
        throw UncheckedIOException(e)
      }
    }

    fun merge(
      ctx: WorkerContext.TaskContext,
      label: String,
      inputs: List<String>,
      output: String,
      reportUnusedDeps: String,
    ): Int {
      val rootBuilder = Deps.Dependencies.newBuilder()
      rootBuilder.success = false
      rootBuilder.ruleLabel = label

      val dependencyMap = sortedMapOf<String, Deps.Dependency>()
      inputs.forEach { input ->
        BufferedInputStream(Paths.get(input).toFile().inputStream()).use {
          val deps: Deps.Dependencies = Deps.Dependencies.parseFrom(it)
          deps.getDependencyList().forEach {
            val dependency = dependencyMap.get(it.path)
            // Replace dependency if it has a stronger kind than one we encountered before.
            if (dependency == null || dependency.kind > it.kind) {
              dependencyMap.put(it.path, it)
            }
          }
        }
      }

      rootBuilder.addAllDependency(dependencyMap.values)

      rootBuilder.success = true

      BufferedOutputStream(File(output).outputStream()).use {
        it.write(rootBuilder.build().toByteArray())
      }

      if (reportUnusedDeps != "off") {
        val kindMap = mutableMapOf<String, Deps.Dependency.Kind>()

        // A target might produce multiple jars (Android produces _resources.jar)
        // so we need to make sure wedon't mart the dependency as unused
        // unless all of the jars are unused.
        dependencyMap.values.forEach {
          var label = readJarOwnerFromManifest(Paths.get(it.path)).label
          if (label != null) {
            if (label.startsWith("@@") || label.startsWith("@/")) {
              label = label.substring(1)
            }
            if (kindMap.getOrDefault(label, Deps.Dependency.Kind.UNUSED) >= it.kind) {
              kindMap.put(label, it.kind)
            }
          }
        }

        val unusedLabels =
          kindMap.entries
            .filter { it.value == Deps.Dependency.Kind.UNUSED }
            .map { it.key }
            .filter { it != label }

        if (unusedLabels.isNotEmpty()) {
          ctx.info {
            val open = "\u001b[35m\u001b[1m"
            val close = "\u001b[0m"
            return@info """
            |$open ** Please remove the following dependencies:$close ${unusedLabels.joinToString(
              " ",
            )} from $label 
            |$open ** You can use the following buildozer command:$close buildozer 'remove deps ${
              unusedLabels.joinToString(" ")
            }' $label
            """.trimMargin()
          }
          return if (reportUnusedDeps == "error") 1 else 0
        }
      }
      return 0
    }
  }

  private data class JarOwner(
    val jar: Path,
    val label: String? = null,
    val aspect: String? = null,
  )

  private fun getArgs(args: List<String>): ArgMap {
    check(args.isNotEmpty()) { "expected at least a single arg got: ${args.joinToString(" ")}" }
    val lines =
      FLAGFILE_RE.matchEntire(args[0])?.groups?.get(1)?.let {
        Files.readAllLines(FileSystems.getDefault().getPath(it.value), StandardCharsets.UTF_8)
      } ?: args

    return ArgMaps.from(lines)
  }

  fun execute(
    ctx: WorkerContext.TaskContext,
    args: List<String>,
  ): Int {
    val argMap = getArgs(args)
    val inputs = argMap.mandatory(JdepsMergerFlags.INPUTS)
    val output = argMap.mandatorySingle(JdepsMergerFlags.OUTPUT)
    val label = argMap.mandatorySingle(JdepsMergerFlags.TARGET_LABEL)
    val reportUnusedDeps = argMap.mandatorySingle(JdepsMergerFlags.REPORT_UNUSED_DEPS)

    return merge(ctx, label, inputs, output, reportUnusedDeps)
  }
}
