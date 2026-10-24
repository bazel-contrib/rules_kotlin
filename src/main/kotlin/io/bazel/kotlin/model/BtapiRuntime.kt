package io.bazel.kotlin.model

data class BtapiRuntime(
  val apiImplClasspathList: List<String> = emptyList(),
  val jvmAbiGenClasspathList: List<String> = emptyList(),
  val kaptClasspathList: List<String> = emptyList(),
  val jdepsGenClasspathList: List<String> = emptyList(),
  val classpathFingerprint: String = "",
) {
  companion object {
    @JvmStatic fun builder(): Builder = Builder()

    operator fun invoke(block: Builder.() -> Unit): BtapiRuntime = Builder().apply(block).build()
  }

  @ModelDsl
  class Builder(model: BtapiRuntime = BtapiRuntime()) {
    val apiImplClasspathList = model.apiImplClasspathList.toMutableList()
    val jvmAbiGenClasspathList = model.jvmAbiGenClasspathList.toMutableList()
    val kaptClasspathList = model.kaptClasspathList.toMutableList()
    val jdepsGenClasspathList = model.jdepsGenClasspathList.toMutableList()
    var classpathFingerprint = model.classpathFingerprint

    fun apiImplClasspathList(value: List<String>) = apply {
      val snapshot = value.toList()
      apiImplClasspathList.clear()
      apiImplClasspathList.addAll(snapshot)
    }

    fun addApiImplClasspath(value: String) = apply { apiImplClasspathList += value }

    fun addAllApiImplClasspath(values: Iterable<String>) = apply { apiImplClasspathList += values }

    fun jvmAbiGenClasspathList(value: List<String>) = apply {
      val snapshot = value.toList()
      jvmAbiGenClasspathList.clear()
      jvmAbiGenClasspathList.addAll(snapshot)
    }

    fun addJvmAbiGenClasspath(value: String) = apply { jvmAbiGenClasspathList += value }

    fun addAllJvmAbiGenClasspath(values: Iterable<String>) =
      apply { jvmAbiGenClasspathList += values }

    fun kaptClasspathList(value: List<String>) = apply {
      val snapshot = value.toList()
      kaptClasspathList.clear()
      kaptClasspathList.addAll(snapshot)
    }

    fun addKaptClasspath(value: String) = apply { kaptClasspathList += value }

    fun addAllKaptClasspath(values: Iterable<String>) = apply { kaptClasspathList += values }

    fun jdepsGenClasspathList(value: List<String>) = apply {
      val snapshot = value.toList()
      jdepsGenClasspathList.clear()
      jdepsGenClasspathList.addAll(snapshot)
    }

    fun addJdepsGenClasspath(value: String) = apply { jdepsGenClasspathList += value }

    fun addAllJdepsGenClasspath(values: Iterable<String>) =
      apply { jdepsGenClasspathList += values }

    fun classpathFingerprint(value: String) = apply { classpathFingerprint = value }

    fun build(): BtapiRuntime =
      BtapiRuntime(
        apiImplClasspathList = apiImplClasspathList.toList(),
        jvmAbiGenClasspathList = jvmAbiGenClasspathList.toList(),
        kaptClasspathList = kaptClasspathList.toList(),
        jdepsGenClasspathList = jdepsGenClasspathList.toList(),
        classpathFingerprint = classpathFingerprint,
      )
  }
}
