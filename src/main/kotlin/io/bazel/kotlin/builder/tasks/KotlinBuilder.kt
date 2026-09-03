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
import io.bazel.kotlin.builder.utils.partitionJvmSources
import io.bazel.kotlin.builder.utils.resolveNewDirectories
import io.bazel.kotlin.model.CompilationTaskInfo
import io.bazel.kotlin.model.JvmCompilationTask
import io.bazel.kotlin.model.KotlinToolchainInfo
import io.bazel.kotlin.model.Platform
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
      GENERATED_CLASSDIR("--kotlin_generated_classdir"),
      FRIEND_PATHS("--kotlin_friend_paths"),
      OUTPUT_JDEPS("--kotlin_output_jdeps"),
      DEBUG("--kotlin_debug_tags"),
      TASK_ID("--kotlin_task_id"),
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
      INTERNAL_SKIP_CODE_GEN_CLASSPATH("--internal_skip_code_gen_classpath"),
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
      @Suppress("WHEN_ENUM_CAN_BE_NULL_IN_JAVA")
      when (compileContext.info.platform) {
        Platform.JVM,
        Platform.ANDROID,
        -> executeJvmTask(compileContext, taskContext.directory, argMap)

        Platform.UNRECOGNIZED -> throw IllegalStateException(
          "unrecognized platform: ${compileContext.info}",
        )
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
    val info = buildTaskInfo(argMap).build()
    val context =
      CompilationTaskContext(info, ctx.asPrintStream())
    return Pair(argMap, context)
  }

  private fun buildTaskInfo(argMap: ArgMap): CompilationTaskInfo.Builder =
    with(CompilationTaskInfo.newBuilder()) {
      addAllDebug(argMap.mandatory(KotlinBuilderFlags.DEBUG))

      label = argMap.mandatorySingle(KotlinBuilderFlags.TARGET_LABEL)
      argMap.mandatorySingle(KotlinBuilderFlags.RULE_KIND).also {
        val splitRuleKind = it.split("_")
        require(splitRuleKind[0] == "kt") { "Invalid rule kind $it" }
        platform = Platform.valueOf(splitRuleKind[1].uppercase())
        ruleKind = RuleKind.valueOf(splitRuleKind.last().uppercase())
      }
      moduleName =
        argMap.mandatorySingle(KotlinBuilderFlags.MODULE_NAME).also {
          check(it.isNotBlank()) { "--kotlin_module_name should not be blank" }
        }
      addAllPassthroughFlags(argMap.optional(KotlinBuilderFlags.PASSTHROUGH_FLAGS) ?: emptyList())

      argMap.optional(KotlinBuilderFlags.FRIEND_PATHS)?.let(::addAllFriendPaths)
      toolchainInfoBuilder.commonBuilder.apiVersion =
        argMap.mandatorySingle(KotlinBuilderFlags.API_VERSION)
      toolchainInfoBuilder.commonBuilder.languageVersion =
        argMap.mandatorySingle(KotlinBuilderFlags.LANGUAGE_VERSION)
      buildBtapiRuntime(argMap, toolchainInfoBuilder)
      strictKotlinDeps = argMap.mandatorySingle(KotlinBuilderFlags.STRICT_KOTLIN_DEPS)
      reducedClasspathMode = argMap.mandatorySingle(KotlinBuilderFlags.REDUCED_CLASSPATH_MODE)
      argMap.optionalSingle(KotlinBuilderFlags.ABI_JAR_INTERNAL_AS_PRIVATE)?.let {
        treatInternalAsPrivateInAbiJar = it == "true"
      }
      argMap.optionalSingle(KotlinBuilderFlags.ABI_JAR_REMOVE_PRIVATE_CLASSES)?.let {
        removePrivateClassesInAbiJar = it == "true"
      }
      argMap.optionalSingle(KotlinBuilderFlags.ABI_JAR_REMOVE_DEBUG_INFO)?.let {
        removeDebugInfo = it == "true"
      }
      argMap.optionalSingle(KotlinBuilderFlags.ABI_JAR_PRESERVE_DECLARATION_ORDER)?.let {
        preserveDeclarationOrder = it == "true"
      }
      argMap
        .optionalSingle(
          KotlinBuilderFlags.ABI_JAR_REMOVE_DATA_CLASS_COPY_IF_CONSTRUCTOR_IS_PRIVATE,
        )?.let {
          removeDataClassCopyIfConstructorIsPrivate = it == "true"
        }
      this
    }

  private fun executeJvmTask(
    context: CompilationTaskContext,
    workingDir: Path,
    argMap: ArgMap,
  ) {
    val task = buildJvmTask(context.info, workingDir, argMap)
    context.whenTracing {
      printProto("jvm task message:", task)
    }
    jvmTaskExecutor.execute(context, task)
  }

  private val btapiRuntimeFlags =
    listOf(
      KotlinBuilderFlags.BTAPI_IMPL_CLASSPATH,
      KotlinBuilderFlags.INTERNAL_JVM_ABI_GEN_CLASSPATH,
      KotlinBuilderFlags.INTERNAL_SKIP_CODE_GEN_CLASSPATH,
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
   */
  private fun buildBtapiRuntime(
    argMap: ArgMap,
    toolchainInfo: KotlinToolchainInfo.Builder,
  ) {
    val missing = btapiRuntimeFlags.filter { argMap.optional(it) == null }
    if (missing.size == btapiRuntimeFlags.size) {
      return
    }
    check(missing.isEmpty()) {
      "incomplete Build Tools API runtime flag set: missing ${missing.joinToString { it.flag }}"
    }
    toolchainInfo.btapiBuilder.apply {
      addAllApiImplClasspath(argMap.mandatory(KotlinBuilderFlags.BTAPI_IMPL_CLASSPATH))
      addAllJvmAbiGenClasspath(
        argMap.mandatory(KotlinBuilderFlags.INTERNAL_JVM_ABI_GEN_CLASSPATH),
      )
      addAllSkipCodeGenClasspath(
        argMap.mandatory(KotlinBuilderFlags.INTERNAL_SKIP_CODE_GEN_CLASSPATH),
      )
      addAllKaptClasspath(argMap.mandatory(KotlinBuilderFlags.INTERNAL_KAPT_CLASSPATH))
      addAllJdepsGenClasspath(argMap.mandatory(KotlinBuilderFlags.INTERNAL_JDEPS_GEN_CLASSPATH))
    }
  }

  private fun buildJvmTask(
    info: CompilationTaskInfo,
    workingDir: Path,
    argMap: ArgMap,
  ): JvmCompilationTask =
    JvmCompilationTask.newBuilder().let { root ->
      root.info = info

      root.compileKotlin = argMap.mandatorySingle(KotlinBuilderFlags.BUILD_KOTLIN).toBoolean()
      root.instrumentCoverage =
        argMap
          .mandatorySingle(
            KotlinBuilderFlags.INSTRUMENT_COVERAGE,
          ).toBoolean()

      with(root.outputsBuilder) {
        argMap.optionalSingle(KotlinBuilderFlags.OUTPUT)?.let { jar = it }
        argMap.optionalSingle(KotlinBuilderFlags.OUTPUT_SRCJAR)?.let { srcjar = it }

        argMap.optionalSingle(KotlinBuilderFlags.OUTPUT_JDEPS)?.apply { jdeps = this }
        argMap.optionalSingle(KotlinBuilderFlags.GENERATED_JAVA_SRC_JAR)?.apply {
          generatedJavaSrcJar = this
        }
        argMap.optionalSingle(KotlinBuilderFlags.GENERATED_JAVA_STUB_JAR)?.apply {
          generatedJavaStubJar = this
        }
        argMap.optionalSingle(KotlinBuilderFlags.ABI_JAR)?.let { abijar = it }
        argMap.optionalSingle(KotlinBuilderFlags.GENERATED_CLASS_JAR)?.let {
          generatedClassJar = it
        }
      }

      with(root.directoriesBuilder) {
        val moduleName = argMap.mandatorySingle(KotlinBuilderFlags.MODULE_NAME)
        classes =
          workingDir.resolveNewDirectories(getOutputDirPath(moduleName, "classes")).toString()
        javaClasses =
          workingDir
            .resolveNewDirectories(
              getOutputDirPath(moduleName, "java_classes"),
            ).toString()
        if (argMap.hasAll(KotlinBuilderFlags.ABI_JAR)) {
          abiClasses =
            workingDir
              .resolveNewDirectories(
                getOutputDirPath(moduleName, "abi_classes"),
              ).toString()
        }
        generatedClasses =
          workingDir
            .resolveNewDirectories(getOutputDirPath(moduleName, "generated_classes"))
            .toString()
        temp =
          workingDir
            .resolveNewDirectories(
              getOutputDirPath(moduleName, "temp"),
            ).toString()
        generatedSources =
          workingDir
            .resolveNewDirectories(getOutputDirPath(moduleName, "generated_sources"))
            .toString()
        generatedJavaSources =
          workingDir
            .resolveNewDirectories(getOutputDirPath(moduleName, "generated_java_sources"))
            .toString()
        generatedStubClasses =
          workingDir.resolveNewDirectories(getOutputDirPath(moduleName, "stubs")).toString()
        coverageMetadataClasses =
          workingDir
            .resolveNewDirectories(getOutputDirPath(moduleName, "coverage-metadata"))
            .toString()
      }

      with(root.inputsBuilder) {
        addAllClasspath(argMap.mandatory(KotlinBuilderFlags.CLASSPATH))
        addAllDepsArtifacts(
          argMap.optional(KotlinBuilderFlags.DEPS_ARTIFACTS) ?: emptyList(),
        )
        addAllDirectDependencies(argMap.mandatory(KotlinBuilderFlags.DIRECT_DEPENDENCIES))

        addAllProcessors(argMap.optional(KotlinBuilderFlags.PROCESSORS) ?: emptyList())
        addAllProcessorpaths(argMap.optional(KotlinBuilderFlags.PROCESSOR_PATH) ?: emptyList())

        val plugins =
          argMap
            .optional(KotlinBuilderFlags.PLUGINS_PAYLOAD)
            ?.singleOrNull()
            ?.let(PluginsPayloadParser::parse)
            ?: emptyList()
        addAllPlugins(plugins)

        // Expand the structured plugins into the per-phase fields the compilation paths consume.
        // The expansion reproduces the exact strings the legacy per-phase worker flags used to
        // carry, so the -Xplugin/-P arguments handed to kotlinc are unchanged.
        for (plugin in plugins) {
          val optionStrings =
            plugin.optionsList.map { option ->
              if (option.value.isEmpty()) {
                "${plugin.id}:${option.key}"
              } else {
                "${plugin.id}:${option.key}=${option.value}"
              }
            }
          if (JvmCompilationTask.Inputs.PluginPhase.PLUGIN_PHASE_STUBS in plugin.phasesList) {
            addAllStubsPluginClasspath(plugin.classpathList)
            addAllStubsPluginOptions(optionStrings)
          }
          if (JvmCompilationTask.Inputs.PluginPhase.PLUGIN_PHASE_COMPILE in plugin.phasesList) {
            addAllCompilerPluginClasspath(plugin.classpathList)
            addAllCompilerPluginOptions(optionStrings)
          }
        }

        argMap
          .optional(KotlinBuilderFlags.SOURCES)
          ?.iterator()
          ?.partitionJvmSources(
            { addKotlinSources(it) },
            { addJavaSources(it) },
          )
        argMap
          .optional(KotlinBuilderFlags.SOURCE_JARS)
          ?.also {
            addAllSourceJars(it)
          }
      }

      with(root.infoBuilder) {
        toolchainInfoBuilder.jvmBuilder.jvmTarget =
          argMap.mandatorySingle(KotlinBuilderFlags.JVM_TARGET)
      }
      root.build()
    }

  private fun getOutputDirPath(
    moduleName: String,
    dirName: String,
  ) = "_kotlinc/${moduleName}_jvm/$dirName"
}
