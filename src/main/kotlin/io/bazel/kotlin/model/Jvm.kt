package io.bazel.kotlin.model

data class Jvm(
  val jvmTarget: String = "",
) {
  companion object {
    @JvmStatic fun builder(): Builder = Builder()
  }

  class Builder {
    private var model = Jvm()

    fun jvmTarget(value: String) = apply { model = model.copy(jvmTarget = value) }

    fun build(): Jvm = model
  }
}
