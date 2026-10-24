package io.bazel.kotlin.model

data class Jvm(
  val jvmTarget: String = "",
) {
  companion object {
    @JvmStatic fun builder(): Builder = Builder()

    operator fun invoke(block: Builder.() -> Unit): Jvm = Builder().apply(block).build()
  }

  @ModelDsl
  class Builder(model: Jvm = Jvm()) {
    var jvmTarget = model.jvmTarget

    fun jvmTarget(value: String) = apply { jvmTarget = value }

    fun build(): Jvm =
      Jvm(
        jvmTarget = jvmTarget,
      )
  }
}
