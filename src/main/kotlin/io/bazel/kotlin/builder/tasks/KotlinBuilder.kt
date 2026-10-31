/*
 * Copyright 2018 The Bazel Authors. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 */
package io.bazel.kotlin.builder.tasks

import io.bazel.kotlin.builder.toolchain.CompilationStatusException
import io.bazel.kotlin.builder.toolchain.CompilationTaskContext
import io.bazel.kotlin.builder.utils.ArgMap
import io.bazel.kotlin.builder.utils.ArgMaps
import io.bazel.kotlin.builder.utils.Flag
import io.bazel.kotlin.builder.utils.fingerprintOf
import io.bazel.kotlin.builder.utils.partitionJvmSources
import io.bazel.kotlin.builder.utils.resolveNewDirectories
import io.bazel.kotlin.model.BtapiRuntime
import io.bazel.kotlin.model.CompilationTaskInfo
import io.bazel.kotlin.model.JvmCompilationTask
import io.bazel.kotlin.model.Platform
import io.bazel.kotlin.model.PluginPhase
import io.bazel.kotlin.model.RuleKind
import io.bazel.worker.WorkerContext
import java.nio.charset.StandardCharsets
import java.nio.file.FileSystems
import java.nio.file.Files
import java.nio.file.Path
import java.util.regex.Pattern

@Suppress("MemberVisibilityCanBePrivate")
class KotlinBuilder(
  private val jvmTaskExecutor: JvmTaskExecutor,
) {
  companion object {
    @JvmStatic
    private val FLAGFILE_RE = Pattern.compile("""^--flagfile=((.*)-(\d+).params)$""").toRegex()

    enum class KotlinBuilderFlags(
      override val flag: String,
    ) : Flag {
      TARGET_LABEL("--target_label"),
      CLASSPATH("--classpath"),
      DIRECT_DEPENDENCIES("--direct_dependencies"),
      DEPS_ARTIFACTS("--deps_artifacts"),
      SOURCES("--sources"),
      SOURCE_JARS("--source_jars"),
      PROCESSOR_PATH("--processorpath"),
      PROCESSORS("--processors"),
      PLUGINS_PAYLOAD("--plugins_payload"),
      OUTPUT("--output"),
      RULE_KIND("--rule_kind"),
      MODULE_NAME("--kotlin_module_name"),
      PASSTHROUGH_FLAGS("--kotlin_passthrough_flags"),
      API_VERSION("--kotlin_api_version"),
      LANGUAGE_VERSION("--kotlin_language_version"),
      JVM_TARGET("--kotlin_jvm_target"),
      OUTPUT_SRCJAR("--kotlin_output_srcjar"),
      FRIEND_PATHS("--kotlin_friend_paths"),
      OUTPUT_JDEPS("--kotlin_output_jdeps"),
      DEBUG("--kotlin_debug_tags"),
      ABI_JAR("--abi_jar"),
      ABI_JAR_INTERNAL_AS_PRIVATE("--treat_internal_as_private_in_abi_jar"),
      ABI_JAR_REMOVE_PRIVATE_CLASSES("--remove_private_classes_in_abi_jar"),
      ABI_JAR_REMOVE_DEBUG_INFO("--remove_debug_info_in_abi_jar"),
      ABI_JAR_PRESERVE_DECLARATION_ORDER("--preserve_declaration_order"),
      ABI_JAR_REMOVE_DATA_CLASS_COPY_IF_CONSTRUCTOR_IS_PRIVATE(
        "--remove_data_class_copy_if_constructor_is_private",
      ),
      GENERATED_JAVA_SRC_JAR("--generated_java_srcjar"),
      GENERATED_JAVA_STUB_JAR("--kapt_generated_stub_jar"),
      GENERATED_CLASS_JAR("--kapt_generated_class_jar"),
      BUILD_KOTLIN("--build_kotlin"),
      STRICT_KOTLIN_DEPS("--strict_kotlin_deps"),
      REDUCED_CLASSPATH_MODE("--reduced_classpath_mode"),
      INSTRUMENT_COVERAGE("--instrument_coverage"),
      BTAPI_IMPL_CLASSPATH("--btapi_impl_classpath"),
      INTERNAL_JVM_ABI_GEN_CLASSPATH("--internal_jvm_abi_gen_classpath"),
      INTERNAL_KAPT_CLASSPATH("--internal_kapt_classpath"),
      INTERNAL_JDEPS_GEN_CLASSPATH("--internal_jdeps_gen_classpath"),
    }
  }

  fun build(
    taskContext: WorkerContext.TaskContext,
    args: List<String>,
  ): Int {
    val (argMap, compileContext) = buildContext(taskContext, args)
    var success = false
    var status = 0
    try {
      when (compileContext.info.platform) {
        Platform.JVM,
        Platform.ANDROID,
        -> executeJvmTask(compileContext, taskContext.directory, argMap)
      }
      success = true
    } catch (ex: CompilationStatusException) {
      taskContext.error { "Compilation failure: ${ex.message}" }
      status = ex.status
    } catch (throwable: Throwable) {
      taskContext.error(throwable) { "Uncaught exception" }
      status = 1
    } finally {
      compileContext.finalize(success)
    }
    return status
  }

  private fun buildContext(
    ctx: WorkerContext.TaskContext,
    args: List<String>,
  ): Pair<ArgMap, CompilationTaskContext> {
    check(args.isNotEmpty()) { "expected at least a single arg got: ${args.joinToString(" ")}" }
    val lines =
      FLAGFILE_RE.matchEntire(args[0])?.groups?.get(1)?.let {
        Files.readAllLines(FileSystems.getDefault().getPath(it.value), StandardCharsets.UTF_8)
      } ?: args

    val argMap = ArgMaps.from(lines)
    val info = buildTaskInfo(argMap, ctx.inputDigests)
    val context =
      CompilationTaskContext(info, ctx.asPrintStream())
    return Pair(argMap, context)
  }

  private fun buildTaskInfo(
    argMap: ArgMap,
    inputDigests: Map<String, String>,
  ): CompilationTaskInfo {
    val (platform, ruleKind) =
      argMap.mandatorySingle(KotlinBuilderFlags.RULE_KIND).let {
        val splitRuleKind = it.split("_")
        require(splitRuleKind[0] == "kt") { "Invalid rule kind $it" }
        return@let Platform.valueOf(splitRuleKind[1].uppercase()) to
          RuleKind.valueOf(splitRuleKind.last().uppercase())
      }
    val moduleName =
      argMap.mandatorySingle(KotlinBuilderFlags.MODULE_NAME).also {
        check(it.isNotBlank()) { "--kotlin_module_name should not be blank" }
      }
    return CompilationTaskInfo {
      label = argMap.mandatorySingle(KotlinBuilderFlags.TARGET_LABEL)
      this.platform = platform
      this.ruleKind = ruleKind
      this.moduleName = moduleName
      passthroughFlagsList += argMap.optional(KotlinBuilderFlags.PASSTHROUGH_FLAGS).orEmpty()
      toolchainInfo {
        common {
          apiVersion = argMap.mandatorySingle(KotlinBuilderFlags.API_VERSION)
          languageVersion = argMap.mandatorySingle(KotlinBuilderFlags.LANGUAGE_VERSION)
        }
        btapi = buildBtapiRuntime(argMap, inputDigests)
      }
      friendPathsList += argMap.optional(KotlinBuilderFlags.FRIEND_PATHS).orEmpty()
      debugList += argMap.mandatory(KotlinBuilderFlags.DEBUG)
      strictKotlinDeps = argMap.mandatorySingle(KotlinBuilderFlags.STRICT_KOTLIN_DEPS)
      reducedClasspathMode = argMap.mandatorySingle(KotlinBuilderFlags.REDUCED_CLASSPATH_MODE)
      treatInternalAsPrivateInAbiJar =
        argMap.optionalSingle(KotlinBuilderFlags.ABI_JAR_INTERNAL_AS_PRIVATE) == "true"
      removePrivateClassesInAbiJar =
        argMap.optionalSingle(KotlinBuilderFlags.ABI_JAR_REMOVE_PRIVATE_CLASSES) == "true"
      removeDebugInfo =
        argMap.optionalSingle(KotlinBuilderFlags.ABI_JAR_REMOVE_DEBUG_INFO) == "true"
      preserveDeclarationOrder =
        argMap.optionalSingle(KotlinBuilderFlags.ABI_JAR_PRESERVE_DECLARATION_ORDER) == "true"
      removeDataClassCopyIfConstructorIsPrivate =
        argMap.optionalSingle(
          KotlinBuilderFlags.ABI_JAR_REMOVE_DATA_CLASS_COPY_IF_CONSTRUCTOR_IS_PRIVATE,
        ) == "true"
    }
  }

  private fun executeJvmTask(
    context: CompilationTaskContext,
    workingDir: Path,
    argMap: ArgMap,
  ) {
    val task = buildJvmTask(context.info, workingDir, argMap)
    context.whenTracing {
      printMsg("jvm task message:", task)
    }
    jvmTaskExecutor.execute(context, task)
  }

  private val btapiRuntimeFlags =
    listOf(
      KotlinBuilderFlags.BTAPI_IMPL_CLASSPATH,
      KotlinBuilderFlags.INTERNAL_JVM_ABI_GEN_CLASSPATH,
      KotlinBuilderFlags.INTERNAL_KAPT_CLASSPATH,
      KotlinBuilderFlags.INTERNAL_JDEPS_GEN_CLASSPATH,
    )

  /**
   * The task's Build Tools API runtime configuration, recorded on the toolchain info. The
   * --btapi_* and --internal_* flags are emitted together and only when the Build Tools API
   * compilation is enabled for the action, so the runtime flag set is none-or-everything:
   * all flags absent means a legacy request and the btapi message stays absent -- its
   * presence is the worker's signal to compile through the Build Tools API. A partial flag
   * set can only come from a malformed direct worker invocation and is rejected.
   *
   * The classpath fingerprint identifies the jars of the implementation classpath, the data the
   * cached compiler depends on; it is built from the request input digests ([fingerprintOf]) and
   * stays empty when the request carried none.
   */
  private fun buildBtapiRuntime(
    argMap: ArgMap,
    inputDigests: Map<String, String>,
  ): BtapiRuntime? {
    val missing = btapiRuntimeFlags.filter { argMap.optional(it) == null }
    if (missing.size == btapiRuntimeFlags.size) {
      return null
    }
    check(missing.isEmpty()) {
      "incomplete Build Tools API runtime flag set: missing ${missing.joinToString { it.flag }}"
    }
    val apiImplClasspath = argMap.mandatory(KotlinBuilderFlags.BTAPI_IMPL_CLASSPATH)
    return BtapiRuntime {
      apiImplClasspathList += apiImplClasspath
      jvmAbiGenClasspathList += argMap.mandatory(KotlinBuilderFlags.INTERNAL_JVM_ABI_GEN_CLASSPATH)
      kaptClasspathList += argMap.mandatory(KotlinBuilderFlags.INTERNAL_KAPT_CLASSPATH)
      jdepsGenClasspathList += argMap.mandatory(KotlinBuilderFlags.INTERNAL_JDEPS_GEN_CLASSPATH)
      classpathFingerprint = fingerprintOf(apiImplClasspath, inputDigests)
    }
  }

  private fun buildJvmTask(
    info: CompilationTaskInfo,
    workingDir: Path,
    argMap: ArgMap,
  ): JvmCompilationTask {
    val moduleName = argMap.mandatorySingle(KotlinBuilderFlags.MODULE_NAME)

    fun directory(name: String): String =
      workingDir.resolveNewDirectories(getOutputDirPath(moduleName, name)).toString()

    return JvmCompilationTask {
      this.info = info
      info {
        toolchainInfo {
          jvm { jvmTarget = argMap.mandatorySingle(KotlinBuilderFlags.JVM_TARGET) }
        }
      }
      outputs {
        jar = argMap.optionalSingle(KotlinBuilderFlags.OUTPUT).orEmpty()
        srcjar = argMap.optionalSingle(KotlinBuilderFlags.OUTPUT_SRCJAR).orEmpty()
        jdeps = argMap.optionalSingle(KotlinBuilderFlags.OUTPUT_JDEPS).orEmpty()
        generatedJavaSrcJar =
          argMap.optionalSingle(KotlinBuilderFlags.GENERATED_JAVA_SRC_JAR).orEmpty()
        generatedJavaStubJar =
          argMap.optionalSingle(KotlinBuilderFlags.GENERATED_JAVA_STUB_JAR).orEmpty()
        abijar = argMap.optionalSingle(KotlinBuilderFlags.ABI_JAR).orEmpty()
        generatedClassJar = argMap.optionalSingle(KotlinBuilderFlags.GENERATED_CLASS_JAR).orEmpty()
      }
      directories {
        classes = directory("classes")
        javaClasses = directory("java_classes")
        if (argMap.hasAll(KotlinBuilderFlags.ABI_JAR)) {
          abiClasses = directory("abi_classes")
        }
        generatedClasses = directory("generated_classes")
        temp = directory("temp")
        generatedSources = directory("generated_sources")
        generatedJavaSources = directory("generated_java_sources")
        generatedStubClasses = directory("stubs")
        coverageMetadataClasses = directory("coverage-metadata")
      }
      inputs {
        pluginsList +=
          argMap
            .optional(KotlinBuilderFlags.PLUGINS_PAYLOAD)
            ?.singleOrNull()
            ?.let(PluginsPayloadParser::parse)
            .orEmpty()

        // Expand structured plugins into the legacy per-phase compiler arguments.
        for (plugin in pluginsList) {
          val optionStrings =
            plugin.optionsList.map { option ->
              if (option.value.isEmpty()) {
                "${plugin.id}:${option.key}"
              } else {
                "${plugin.id}:${option.key}=${option.value}"
              }
            }
          if (PluginPhase.PLUGIN_PHASE_STUBS in plugin.phasesList) {
            stubsPluginClasspathList += plugin.classpathList
            stubsPluginOptionsList += optionStrings
          }
          if (PluginPhase.PLUGIN_PHASE_COMPILE in plugin.phasesList) {
            compilerPluginClasspathList += plugin.classpathList
            compilerPluginOptionsList += optionStrings
          }
        }
        argMap.optional(KotlinBuilderFlags.SOURCES)?.iterator()?.partitionJvmSources(
          { kotlinSourcesList += it },
          { javaSourcesList += it },
        )
        classpathList += argMap.optional(KotlinBuilderFlags.CLASSPATH).orEmpty()
        directDependenciesList += argMap.optional(KotlinBuilderFlags.DIRECT_DEPENDENCIES).orEmpty()
        sourceJarsList += argMap.optional(KotlinBuilderFlags.SOURCE_JARS).orEmpty()
        processorsList += argMap.optional(KotlinBuilderFlags.PROCESSORS).orEmpty()
        processorpathsList += argMap.optional(KotlinBuilderFlags.PROCESSOR_PATH).orEmpty()
        depsArtifactsList += argMap.optional(KotlinBuilderFlags.DEPS_ARTIFACTS).orEmpty()
      }
      compileKotlin = argMap.mandatorySingle(KotlinBuilderFlags.BUILD_KOTLIN).toBoolean()
      instrumentCoverage =
        argMap.mandatorySingle(KotlinBuilderFlags.INSTRUMENT_COVERAGE).toBoolean()
    }
  }

  private fun getOutputDirPath(
    moduleName: String,
    dirName: String,
  ) = "_kotlinc/${moduleName}_jvm/$dirName"
}
