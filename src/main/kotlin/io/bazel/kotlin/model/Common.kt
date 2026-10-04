package io.bazel.kotlin.model

data class Common(
  val languageVersion: String = "",
  val apiVersion: String = "",
  val coroutines: String = "",
) {
  companion object {
    @JvmStatic fun builder(): Builder = Builder()
  }

  class Builder {
    private var model = Common()

    fun languageVersion(value: String) = apply { model = model.copy(languageVersion = value) }

    fun apiVersion(value: String) = apply { model = model.copy(apiVersion = value) }

    fun coroutines(value: String) = apply { model = model.copy(coroutines = value) }

    fun build(): Common = model
  }
}
