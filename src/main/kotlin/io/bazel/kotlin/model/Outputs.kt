package io.bazel.kotlin.model

data class Outputs(
  val jar: String = "",
  val jdeps: String = "",
  val srcjar: String = "",
  val abijar: String = "",
  val generatedJavaSrcJar: String = "",
  val generatedJavaStubJar: String = "",
  val generatedClassJar: String = "",
  val generatedKspSrcJar: String = "",
  val generatedKspClassesJar: String = "",
) {
  companion object {
    @JvmStatic fun builder(): Builder = Builder()
  }

  class Builder {
    private var model = Outputs()

    fun jar(value: String) = apply { model = model.copy(jar = value) }

    fun jdeps(value: String) = apply { model = model.copy(jdeps = value) }

    fun srcjar(value: String) = apply { model = model.copy(srcjar = value) }

    fun abijar(value: String) = apply { model = model.copy(abijar = value) }

    fun generatedJavaSrcJar(value: String) =
      apply { model = model.copy(generatedJavaSrcJar = value) }

    fun generatedJavaStubJar(value: String) =
      apply {
        model =
          model.copy(generatedJavaStubJar = value)
      }

    fun generatedClassJar(value: String) = apply { model = model.copy(generatedClassJar = value) }

    fun generatedKspSrcJar(value: String) = apply { model = model.copy(generatedKspSrcJar = value) }

    fun generatedKspClassesJar(value: String) =
      apply {
        model =
          model.copy(generatedKspClassesJar = value)
      }

    fun build(): Outputs = model
  }
}
