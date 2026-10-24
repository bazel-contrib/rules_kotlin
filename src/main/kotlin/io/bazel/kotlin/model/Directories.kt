package io.bazel.kotlin.model

data class Directories(
  val classes: String = "",
  val generatedClasses: String = "",
  val generatedSources: String = "",
  val temp: String = "",
  val generatedStubClasses: String = "",
  val abiClasses: String = "",
  val generatedJavaSources: String = "",
  val javaClasses: String = "",
  val coverageMetadataClasses: String = "",
) {
  companion object {
    @JvmStatic fun builder(): Builder = Builder()

    operator fun invoke(block: Builder.() -> Unit): Directories = Builder().apply(block).build()
  }

  @ModelDsl
  class Builder(model: Directories = Directories()) {
    var classes = model.classes
    var generatedClasses = model.generatedClasses
    var generatedSources = model.generatedSources
    var temp = model.temp
    var generatedStubClasses = model.generatedStubClasses
    var abiClasses = model.abiClasses
    var generatedJavaSources = model.generatedJavaSources
    var javaClasses = model.javaClasses
    var coverageMetadataClasses = model.coverageMetadataClasses

    fun classes(value: String) = apply { classes = value }

    fun generatedClasses(value: String) = apply { generatedClasses = value }

    fun generatedSources(value: String) = apply { generatedSources = value }

    fun temp(value: String) = apply { temp = value }

    fun generatedStubClasses(value: String) = apply { generatedStubClasses = value }

    fun abiClasses(value: String) = apply { abiClasses = value }

    fun generatedJavaSources(value: String) = apply { generatedJavaSources = value }

    fun javaClasses(value: String) = apply { javaClasses = value }

    fun coverageMetadataClasses(value: String) = apply { coverageMetadataClasses = value }

    fun build(): Directories =
      Directories(
        classes = classes,
        generatedClasses = generatedClasses,
        generatedSources = generatedSources,
        temp = temp,
        generatedStubClasses = generatedStubClasses,
        abiClasses = abiClasses,
        generatedJavaSources = generatedJavaSources,
        javaClasses = javaClasses,
        coverageMetadataClasses = coverageMetadataClasses,
      )
  }
}
