package io.bazel.kotlin.model

data class Plugin(
  val id: String = "",
  val classpathList: List<String> = emptyList(),
  val optionsList: List<PluginOption> = emptyList(),
  val phasesList: List<PluginPhase> = emptyList(),
) {
  companion object {
    @JvmStatic fun builder(): Builder = Builder()

    operator fun invoke(block: Builder.() -> Unit): Plugin = Builder().apply(block).build()
  }

  @ModelDsl
  class Builder(model: Plugin = Plugin()) {
    var id = model.id
    val classpathList = model.classpathList.toMutableList()
    val optionsList = model.optionsList.toMutableList()
    val phasesList = model.phasesList.toMutableList()

    fun id(value: String) = apply { id = value }

    fun classpathList(value: List<String>) = apply {
      val snapshot = value.toList()
      classpathList.clear()
      classpathList.addAll(snapshot)
    }

    fun addClasspath(value: String) = apply { classpathList += value }

    fun addAllClasspath(values: Iterable<String>) = apply { classpathList += values }

    fun optionsList(value: List<PluginOption>) = apply {
      val snapshot = value.toList()
      optionsList.clear()
      optionsList.addAll(snapshot)
    }

    fun addOptions(value: PluginOption) = apply { optionsList += value }

    fun addAllOptions(values: Iterable<PluginOption>) = apply { optionsList += values }

    fun phasesList(value: List<PluginPhase>) = apply {
      val snapshot = value.toList()
      phasesList.clear()
      phasesList.addAll(snapshot)
    }

    fun addPhases(value: PluginPhase) = apply { phasesList += value }

    fun addAllPhases(values: Iterable<PluginPhase>) = apply { phasesList += values }

    fun build(): Plugin =
      Plugin(
        id = id,
        classpathList = classpathList.toList(),
        optionsList = optionsList.toList(),
        phasesList = phasesList.toList(),
      )
  }
}
