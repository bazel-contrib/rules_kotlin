package io.bazel.kotlin.model

data class CompilationTaskInfo(
  val label: String = "",
  val platform: Platform = Platform.JVM,
  val ruleKind: RuleKind = RuleKind.LIBRARY,
  val moduleName: String = "",
  val passthroughFlagsList: List<String> = emptyList(),
  val toolchainInfo: KotlinToolchainInfo = KotlinToolchainInfo(),
  val friendPathsList: List<String> = emptyList(),
  val primaryOutputPath: String = "",
  val debugList: List<String> = emptyList(),
  val strictKotlinDeps: String = "",
  val reducedClasspathMode: String = "",
  val treatInternalAsPrivateInAbiJar: Boolean = false,
  val removePrivateClassesInAbiJar: Boolean = false,
  val removeDebugInfo: Boolean = false,
  val preserveDeclarationOrder: Boolean = false,
  val removeDataClassCopyIfConstructorIsPrivate: Boolean = false,
  // The Target-Label spelling of the jar fold (str(ctx.label)); empty falls back to [label].
  val manifestTargetLabel: String = "",
) {
  /**
   * The `Target-Label` the builder writes into the manifests of its jars. It matches the spelling of a folded
   * jar, so a jar keeps its manifest whether or not the fold runs. Jdeps and diagnostics keep using [label].
   */
  val jarOwnerLabel: String
    get() = manifestTargetLabel.ifEmpty { label }

  companion object {
    @JvmStatic fun builder(): Builder = Builder()

    operator fun invoke(block: Builder.() -> Unit): CompilationTaskInfo =
      Builder().apply(block).build()
  }

  @ModelDsl
  class Builder(
    model: CompilationTaskInfo = CompilationTaskInfo(),
  ) {
    var label = model.label
    var manifestTargetLabel = model.manifestTargetLabel
    var platform = model.platform
    var ruleKind = model.ruleKind
    var moduleName = model.moduleName
    val passthroughFlagsList = model.passthroughFlagsList.toMutableList()
    var toolchainInfo = model.toolchainInfo
    val friendPathsList = model.friendPathsList.toMutableList()
    var primaryOutputPath = model.primaryOutputPath
    val debugList = model.debugList.toMutableList()
    var strictKotlinDeps = model.strictKotlinDeps
    var reducedClasspathMode = model.reducedClasspathMode
    var treatInternalAsPrivateInAbiJar = model.treatInternalAsPrivateInAbiJar
    var removePrivateClassesInAbiJar = model.removePrivateClassesInAbiJar
    var removeDebugInfo = model.removeDebugInfo
    var preserveDeclarationOrder = model.preserveDeclarationOrder
    var removeDataClassCopyIfConstructorIsPrivate = model.removeDataClassCopyIfConstructorIsPrivate

    fun label(value: String) = apply { label = value }

    fun manifestTargetLabel(value: String) = apply { manifestTargetLabel = value }

    fun platform(value: Platform) = apply { platform = value }

    fun ruleKind(value: RuleKind) = apply { ruleKind = value }

    fun moduleName(value: String) = apply { moduleName = value }

    fun passthroughFlagsList(value: List<String>) =
      apply {
        val snapshot = value.toList()
        passthroughFlagsList.clear()
        passthroughFlagsList.addAll(snapshot)
      }

    fun addPassthroughFlags(value: String) = apply { passthroughFlagsList += value }

    fun addAllPassthroughFlags(values: Iterable<String>) = apply { passthroughFlagsList += values }

    fun toolchainInfo(value: KotlinToolchainInfo) = apply { toolchainInfo = value }

    @JvmSynthetic
    fun toolchainInfo(block: KotlinToolchainInfo.Builder.() -> Unit) {
      toolchainInfo = KotlinToolchainInfo.Builder(toolchainInfo).apply(block).build()
    }

    fun friendPathsList(value: List<String>) =
      apply {
        val snapshot = value.toList()
        friendPathsList.clear()
        friendPathsList.addAll(snapshot)
      }

    fun addFriendPaths(value: String) = apply { friendPathsList += value }

    fun addAllFriendPaths(values: Iterable<String>) = apply { friendPathsList += values }

    fun primaryOutputPath(value: String) = apply { primaryOutputPath = value }

    fun debugList(value: List<String>) =
      apply {
        val snapshot = value.toList()
        debugList.clear()
        debugList.addAll(snapshot)
      }

    fun addDebug(value: String) = apply { debugList += value }

    fun addAllDebug(values: Iterable<String>) = apply { debugList += values }

    fun strictKotlinDeps(value: String) = apply { strictKotlinDeps = value }

    fun reducedClasspathMode(value: String) = apply { reducedClasspathMode = value }

    fun treatInternalAsPrivateInAbiJar(value: Boolean) =
      apply { treatInternalAsPrivateInAbiJar = value }

    fun removePrivateClassesInAbiJar(value: Boolean) =
      apply { removePrivateClassesInAbiJar = value }

    fun removeDebugInfo(value: Boolean) = apply { removeDebugInfo = value }

    fun preserveDeclarationOrder(value: Boolean) = apply { preserveDeclarationOrder = value }

    fun removeDataClassCopyIfConstructorIsPrivate(value: Boolean) =
      apply { removeDataClassCopyIfConstructorIsPrivate = value }

    fun build(): CompilationTaskInfo =
      CompilationTaskInfo(
        label = label,
        manifestTargetLabel = manifestTargetLabel,
        platform = platform,
        ruleKind = ruleKind,
        moduleName = moduleName,
        passthroughFlagsList = passthroughFlagsList.toList(),
        toolchainInfo = toolchainInfo,
        friendPathsList = friendPathsList.toList(),
        primaryOutputPath = primaryOutputPath,
        debugList = debugList.toList(),
        strictKotlinDeps = strictKotlinDeps,
        reducedClasspathMode = reducedClasspathMode,
        treatInternalAsPrivateInAbiJar = treatInternalAsPrivateInAbiJar,
        removePrivateClassesInAbiJar = removePrivateClassesInAbiJar,
        removeDebugInfo = removeDebugInfo,
        preserveDeclarationOrder = preserveDeclarationOrder,
        removeDataClassCopyIfConstructorIsPrivate = removeDataClassCopyIfConstructorIsPrivate,
      )
  }
}
