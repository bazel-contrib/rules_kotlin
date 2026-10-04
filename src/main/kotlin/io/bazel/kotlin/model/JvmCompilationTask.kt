package io.bazel.kotlin.model

data class JvmCompilationTask(
  val info: CompilationTaskInfo = CompilationTaskInfo(),
  val directories: Directories = Directories(),
  val outputs: Outputs = Outputs(),
  val inputs: Inputs = Inputs(),
  val compileKotlin: Boolean = false,
  val instrumentCoverage: Boolean = false,
) {
  companion object {
    @JvmStatic fun builder(): Builder = Builder()
  }

  class Builder {
    private var model = JvmCompilationTask()

    fun info(value: CompilationTaskInfo) = apply { model = model.copy(info = value) }

    fun directories(value: Directories) = apply { model = model.copy(directories = value) }

    fun outputs(value: Outputs) = apply { model = model.copy(outputs = value) }

    fun inputs(value: Inputs) = apply { model = model.copy(inputs = value) }

    fun compileKotlin(value: Boolean) = apply { model = model.copy(compileKotlin = value) }

    fun instrumentCoverage(value: Boolean) =
      apply { model = model.copy(instrumentCoverage = value) }

    fun build(): JvmCompilationTask = model
  }
}
