package io.bazel.kotlin.model

data class PluginOption(
  val key: String = "",
  val value: String = "",
) {
  companion object {
    @JvmStatic fun builder(): Builder = Builder()
  }

  class Builder {
    private var model = PluginOption()

    fun key(value: String) = apply { model = model.copy(key = value) }

    fun value(value: String) = apply { model = model.copy(value = value) }

    fun build(): PluginOption = model
  }
}
