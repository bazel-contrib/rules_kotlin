package io.bazel.kotlin.model

data class KotlinToolchainInfo(
  val common: Common = Common(),
  val jvm: Jvm = Jvm(),
  val btapi: BtapiRuntime? = null,
) {
  companion object {
    @JvmStatic fun builder(): Builder = Builder()
  }

  class Builder {
    private var model = KotlinToolchainInfo()

    fun common(value: Common) = apply { model = model.copy(common = value) }

    fun jvm(value: Jvm) = apply { model = model.copy(jvm = value) }

    fun btapi(value: BtapiRuntime?) = apply { model = model.copy(btapi = value) }

    fun build(): KotlinToolchainInfo = model
  }
}
