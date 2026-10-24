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

    operator fun invoke(block: Builder.() -> Unit): Outputs = Builder().apply(block).build()
  }

  @ModelDsl
  class Builder(model: Outputs = Outputs()) {
    var jar = model.jar
    var jdeps = model.jdeps
    var srcjar = model.srcjar
    var abijar = model.abijar
    var generatedJavaSrcJar = model.generatedJavaSrcJar
    var generatedJavaStubJar = model.generatedJavaStubJar
    var generatedClassJar = model.generatedClassJar
    var generatedKspSrcJar = model.generatedKspSrcJar
    var generatedKspClassesJar = model.generatedKspClassesJar

    fun jar(value: String) = apply { jar = value }

    fun jdeps(value: String) = apply { jdeps = value }

    fun srcjar(value: String) = apply { srcjar = value }

    fun abijar(value: String) = apply { abijar = value }

    fun generatedJavaSrcJar(value: String) = apply { generatedJavaSrcJar = value }

    fun generatedJavaStubJar(value: String) = apply { generatedJavaStubJar = value }

    fun generatedClassJar(value: String) = apply { generatedClassJar = value }

    fun generatedKspSrcJar(value: String) = apply { generatedKspSrcJar = value }

    fun generatedKspClassesJar(value: String) = apply { generatedKspClassesJar = value }

    fun build(): Outputs =
      Outputs(
        jar = jar,
        jdeps = jdeps,
        srcjar = srcjar,
        abijar = abijar,
        generatedJavaSrcJar = generatedJavaSrcJar,
        generatedJavaStubJar = generatedJavaStubJar,
        generatedClassJar = generatedClassJar,
        generatedKspSrcJar = generatedKspSrcJar,
        generatedKspClassesJar = generatedKspClassesJar,
      )
  }
}
