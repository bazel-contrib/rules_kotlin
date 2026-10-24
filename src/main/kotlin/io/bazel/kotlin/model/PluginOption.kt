package io.bazel.kotlin.model

data class PluginOption(
  val key: String = "",
  val value: String = "",
) {
  companion object {
    @JvmStatic fun builder(): Builder = Builder()

    operator fun invoke(block: Builder.() -> Unit): PluginOption = Builder().apply(block).build()
  }

  @ModelDsl
  class Builder(model: PluginOption = PluginOption()) {
    var key = model.key
    var value = model.value

    fun key(value: String) = apply { key = value }

    fun value(value: String) = apply { this.value = value }

    fun build(): PluginOption =
      PluginOption(
        key = key,
        value = value,
      )
  }
}
