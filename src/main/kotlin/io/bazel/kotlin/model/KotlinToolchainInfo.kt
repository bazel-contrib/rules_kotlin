package io.bazel.kotlin.model

data class KotlinToolchainInfo(
  val common: Common = Common(),
  val jvm: Jvm = Jvm(),
  val btapi: BtapiRuntime? = null,
) {
  companion object {
    @JvmStatic fun builder(): Builder = Builder()

    operator fun invoke(block: Builder.() -> Unit): KotlinToolchainInfo =
      Builder().apply(block).build()
  }

  @ModelDsl
  class Builder(model: KotlinToolchainInfo = KotlinToolchainInfo()) {
    var common = model.common
    var jvm = model.jvm
    var btapi = model.btapi

    fun common(value: Common) = apply { common = value }

    @JvmSynthetic
    fun common(block: Common.Builder.() -> Unit) {
      common = Common.Builder(common).apply(block).build()
    }

    fun jvm(value: Jvm) = apply { jvm = value }

    @JvmSynthetic
    fun jvm(block: Jvm.Builder.() -> Unit) {
      jvm = Jvm.Builder(jvm).apply(block).build()
    }

    fun btapi(value: BtapiRuntime?) = apply { btapi = value }

    @JvmSynthetic
    fun btapi(block: BtapiRuntime.Builder.() -> Unit) {
      btapi = BtapiRuntime.Builder(btapi ?: BtapiRuntime()).apply(block).build()
    }

    fun build(): KotlinToolchainInfo =
      KotlinToolchainInfo(
        common = common,
        jvm = jvm,
        btapi = btapi,
      )
  }
}
