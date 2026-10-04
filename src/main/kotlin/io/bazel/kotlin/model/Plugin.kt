package io.bazel.kotlin.model

data class Plugin(
  val id: String = "",
  val classpathList: List<String> = emptyList(),
  val optionsList: List<PluginOption> = emptyList(),
  val phasesList: List<PluginPhase> = emptyList(),
) {
  companion object {
    @JvmStatic fun builder(): Builder = Builder()
  }

  class Builder {
    private var model = Plugin()
    private val classpathList = mutableListOf<String>()
    private val optionsList = mutableListOf<PluginOption>()
    private val phasesList = mutableListOf<PluginPhase>()

    fun id(value: String) = apply { model = model.copy(id = value) }

    fun classpathList(value: List<String>) =
      apply {
        classpathList.clear()
        classpathList.addAll(value)
      }

    fun addClasspath(value: String) = apply { classpathList.add(value) }

    fun addAllClasspath(values: Iterable<String>) = apply { classpathList.addAll(values) }

    fun optionsList(value: List<PluginOption>) =
      apply {
        optionsList.clear()
        optionsList.addAll(value)
      }

    fun addOptions(value: PluginOption) = apply { optionsList.add(value) }

    fun addAllOptions(values: Iterable<PluginOption>) = apply { optionsList.addAll(values) }

    fun phasesList(value: List<PluginPhase>) =
      apply {
        phasesList.clear()
        phasesList.addAll(value)
      }

    fun addPhases(value: PluginPhase) = apply { phasesList.add(value) }

    fun addAllPhases(values: Iterable<PluginPhase>) = apply { phasesList.addAll(values) }

    fun build(): Plugin =
      model.copy(
        classpathList = classpathList.toList(),
        optionsList = optionsList.toList(),
        phasesList = phasesList.toList(),
      )
  }
}
