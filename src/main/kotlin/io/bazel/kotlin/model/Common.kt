package io.bazel.kotlin.model

data class Common(
  val languageVersion: String = "",
  val apiVersion: String = "",
  val coroutines: String = "",
) {
  companion object {
    @JvmStatic fun builder(): Builder = Builder()

    operator fun invoke(block: Builder.() -> Unit): Common = Builder().apply(block).build()
  }

  @ModelDsl
  class Builder(model: Common = Common()) {
    var languageVersion = model.languageVersion
    var apiVersion = model.apiVersion
    var coroutines = model.coroutines

    fun languageVersion(value: String) = apply { languageVersion = value }

    fun apiVersion(value: String) = apply { apiVersion = value }

    fun coroutines(value: String) = apply { coroutines = value }

    fun build(): Common =
      Common(
        languageVersion = languageVersion,
        apiVersion = apiVersion,
        coroutines = coroutines,
      )
  }
}
