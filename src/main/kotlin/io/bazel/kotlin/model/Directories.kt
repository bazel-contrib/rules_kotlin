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
  }

  class Builder {
    private var model = Directories()

    fun classes(value: String) = apply { model = model.copy(classes = value) }

    fun generatedClasses(value: String) = apply { model = model.copy(generatedClasses = value) }

    fun generatedSources(value: String) = apply { model = model.copy(generatedSources = value) }

    fun temp(value: String) = apply { model = model.copy(temp = value) }

    fun generatedStubClasses(value: String) =
      apply {
        model =
          model.copy(generatedStubClasses = value)
      }

    fun abiClasses(value: String) = apply { model = model.copy(abiClasses = value) }

    fun generatedJavaSources(value: String) =
      apply {
        model =
          model.copy(generatedJavaSources = value)
      }

    fun javaClasses(value: String) = apply { model = model.copy(javaClasses = value) }

    fun coverageMetadataClasses(value: String) =
      apply {
        model =
          model.copy(coverageMetadataClasses = value)
      }

    fun build(): Directories = model
  }
}
