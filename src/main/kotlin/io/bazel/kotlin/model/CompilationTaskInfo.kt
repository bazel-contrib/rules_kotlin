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
) {
  companion object {
    @JvmStatic fun builder(): Builder = Builder()
  }

  class Builder {
    private var model = CompilationTaskInfo()
    private val passthroughFlagsList = mutableListOf<String>()
    private val friendPathsList = mutableListOf<String>()
    private val debugList = mutableListOf<String>()

    fun label(value: String) = apply { model = model.copy(label = value) }

    fun platform(value: Platform) = apply { model = model.copy(platform = value) }

    fun ruleKind(value: RuleKind) = apply { model = model.copy(ruleKind = value) }

    fun moduleName(value: String) = apply { model = model.copy(moduleName = value) }

    fun passthroughFlagsList(value: List<String>) =
      apply {
        passthroughFlagsList.clear()
        passthroughFlagsList.addAll(value)
      }

    fun addPassthroughFlags(value: String) = apply { passthroughFlagsList.add(value) }

    fun addAllPassthroughFlags(values: Iterable<String>) =
      apply { passthroughFlagsList.addAll(values) }

    fun toolchainInfo(value: KotlinToolchainInfo) =
      apply {
        model =
          model.copy(toolchainInfo = value)
      }

    fun friendPathsList(value: List<String>) =
      apply {
        friendPathsList.clear()
        friendPathsList.addAll(value)
      }

    fun addFriendPaths(value: String) = apply { friendPathsList.add(value) }

    fun addAllFriendPaths(values: Iterable<String>) = apply { friendPathsList.addAll(values) }

    fun primaryOutputPath(value: String) = apply { model = model.copy(primaryOutputPath = value) }

    fun debugList(value: List<String>) =
      apply {
        debugList.clear()
        debugList.addAll(value)
      }

    fun addDebug(value: String) = apply { debugList.add(value) }

    fun addAllDebug(values: Iterable<String>) = apply { debugList.addAll(values) }

    fun strictKotlinDeps(value: String) = apply { model = model.copy(strictKotlinDeps = value) }

    fun reducedClasspathMode(value: String) =
      apply {
        model =
          model.copy(reducedClasspathMode = value)
      }

    fun treatInternalAsPrivateInAbiJar(value: Boolean) =
      apply {
        model =
          model.copy(treatInternalAsPrivateInAbiJar = value)
      }

    fun removePrivateClassesInAbiJar(value: Boolean) =
      apply {
        model =
          model.copy(removePrivateClassesInAbiJar = value)
      }

    fun removeDebugInfo(value: Boolean) = apply { model = model.copy(removeDebugInfo = value) }

    fun preserveDeclarationOrder(value: Boolean) =
      apply {
        model =
          model.copy(preserveDeclarationOrder = value)
      }

    fun removeDataClassCopyIfConstructorIsPrivate(value: Boolean) =
      apply {
        model =
          model.copy(removeDataClassCopyIfConstructorIsPrivate = value)
      }

    fun build(): CompilationTaskInfo =
      model.copy(
        passthroughFlagsList = passthroughFlagsList.toList(),
        friendPathsList = friendPathsList.toList(),
        debugList = debugList.toList(),
      )
  }
}
