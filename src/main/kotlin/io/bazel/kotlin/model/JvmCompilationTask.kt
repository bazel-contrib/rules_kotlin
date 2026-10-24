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

    operator fun invoke(block: Builder.() -> Unit): JvmCompilationTask =
      Builder().apply(block).build()
  }

  @ModelDsl
  class Builder(model: JvmCompilationTask = JvmCompilationTask()) {
    var info = model.info
    var directories = model.directories
    var outputs = model.outputs
    var inputs = model.inputs
    var compileKotlin = model.compileKotlin
    var instrumentCoverage = model.instrumentCoverage

    fun info(value: CompilationTaskInfo) = apply { info = value }

    @JvmSynthetic
    fun info(block: CompilationTaskInfo.Builder.() -> Unit) {
      info = CompilationTaskInfo.Builder(info).apply(block).build()
    }

    fun directories(value: Directories) = apply { directories = value }

    @JvmSynthetic
    fun directories(block: Directories.Builder.() -> Unit) {
      directories = Directories.Builder(directories).apply(block).build()
    }

    fun outputs(value: Outputs) = apply { outputs = value }

    @JvmSynthetic
    fun outputs(block: Outputs.Builder.() -> Unit) {
      outputs = Outputs.Builder(outputs).apply(block).build()
    }

    fun inputs(value: Inputs) = apply { inputs = value }

    @JvmSynthetic
    fun inputs(block: Inputs.Builder.() -> Unit) {
      inputs = Inputs.Builder(inputs).apply(block).build()
    }

    fun compileKotlin(value: Boolean) = apply { compileKotlin = value }

    fun instrumentCoverage(value: Boolean) = apply { instrumentCoverage = value }

    fun build(): JvmCompilationTask =
      JvmCompilationTask(
        info = info,
        directories = directories,
        outputs = outputs,
        inputs = inputs,
        compileKotlin = compileKotlin,
        instrumentCoverage = instrumentCoverage,
      )
  }
}
