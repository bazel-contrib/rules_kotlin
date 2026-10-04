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
  }

  class Builder {
    private var model = BtapiRuntime()
    private val apiImplClasspathList = mutableListOf<String>()
    private val jvmAbiGenClasspathList = mutableListOf<String>()
    private val kaptClasspathList = mutableListOf<String>()
    private val jdepsGenClasspathList = mutableListOf<String>()

    fun apiImplClasspathList(value: List<String>) =
      apply {
        apiImplClasspathList.clear()
        apiImplClasspathList.addAll(value)
      }

    fun addApiImplClasspath(value: String) = apply { apiImplClasspathList.add(value) }

    fun addAllApiImplClasspath(values: Iterable<String>) =
      apply { apiImplClasspathList.addAll(values) }

    fun jvmAbiGenClasspathList(value: List<String>) =
      apply {
        jvmAbiGenClasspathList.clear()
        jvmAbiGenClasspathList.addAll(value)
      }

    fun addJvmAbiGenClasspath(value: String) = apply { jvmAbiGenClasspathList.add(value) }

    fun addAllJvmAbiGenClasspath(values: Iterable<String>) =
      apply {
        jvmAbiGenClasspathList.addAll(values)
      }

    fun kaptClasspathList(value: List<String>) =
      apply {
        kaptClasspathList.clear()
        kaptClasspathList.addAll(value)
      }

    fun addKaptClasspath(value: String) = apply { kaptClasspathList.add(value) }

    fun addAllKaptClasspath(values: Iterable<String>) = apply { kaptClasspathList.addAll(values) }

    fun jdepsGenClasspathList(value: List<String>) =
      apply {
        jdepsGenClasspathList.clear()
        jdepsGenClasspathList.addAll(value)
      }

    fun addJdepsGenClasspath(value: String) = apply { jdepsGenClasspathList.add(value) }

    fun addAllJdepsGenClasspath(values: Iterable<String>) =
      apply {
        jdepsGenClasspathList.addAll(values)
      }

    fun classpathFingerprint(value: String) =
      apply {
        model =
          model.copy(classpathFingerprint = value)
      }

    fun build(): BtapiRuntime =
      model.copy(
        apiImplClasspathList = apiImplClasspathList.toList(),
        jvmAbiGenClasspathList = jvmAbiGenClasspathList.toList(),
        kaptClasspathList = kaptClasspathList.toList(),
        jdepsGenClasspathList = jdepsGenClasspathList.toList(),
      )
  }
}
