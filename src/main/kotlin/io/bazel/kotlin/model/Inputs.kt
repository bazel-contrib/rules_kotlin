package io.bazel.kotlin.model

data class Inputs(
  val classpathList: List<String> = emptyList(),
  val directDependenciesList: List<String> = emptyList(),
  val kotlinSourcesList: List<String> = emptyList(),
  val javaSourcesList: List<String> = emptyList(),
  val sourceJarsList: List<String> = emptyList(),
  val processorsList: List<String> = emptyList(),
  val processorpathsList: List<String> = emptyList(),
  val stubsPluginOptionsList: List<String> = emptyList(),
  val stubsPluginsList: List<String> = emptyList(),
  val stubsPluginClasspathList: List<String> = emptyList(),
  val compilerPluginOptionsList: List<String> = emptyList(),
  val compilerPluginsList: List<String> = emptyList(),
  val compilerPluginClasspathList: List<String> = emptyList(),
  val javacFlagsList: List<String> = emptyList(),
  val depsArtifactsList: List<String> = emptyList(),
  val pluginsList: List<Plugin> = emptyList(),
) {
  companion object {
    @JvmStatic fun builder(): Builder = Builder()

    operator fun invoke(block: Builder.() -> Unit): Inputs = Builder().apply(block).build()
  }

  @ModelDsl
  class Builder(model: Inputs = Inputs()) {
    val classpathList = model.classpathList.toMutableList()
    val directDependenciesList = model.directDependenciesList.toMutableList()
    val kotlinSourcesList = model.kotlinSourcesList.toMutableList()
    val javaSourcesList = model.javaSourcesList.toMutableList()
    val sourceJarsList = model.sourceJarsList.toMutableList()
    val processorsList = model.processorsList.toMutableList()
    val processorpathsList = model.processorpathsList.toMutableList()
    val stubsPluginOptionsList = model.stubsPluginOptionsList.toMutableList()
    val stubsPluginsList = model.stubsPluginsList.toMutableList()
    val stubsPluginClasspathList = model.stubsPluginClasspathList.toMutableList()
    val compilerPluginOptionsList = model.compilerPluginOptionsList.toMutableList()
    val compilerPluginsList = model.compilerPluginsList.toMutableList()
    val compilerPluginClasspathList = model.compilerPluginClasspathList.toMutableList()
    val javacFlagsList = model.javacFlagsList.toMutableList()
    val depsArtifactsList = model.depsArtifactsList.toMutableList()
    val pluginsList = model.pluginsList.toMutableList()

    fun classpathList(value: List<String>) = apply {
      val snapshot = value.toList()
      classpathList.clear()
      classpathList.addAll(snapshot)
    }

    fun addClasspath(value: String) = apply { classpathList += value }

    fun addAllClasspath(values: Iterable<String>) = apply { classpathList += values }

    fun directDependenciesList(value: List<String>) = apply {
      val snapshot = value.toList()
      directDependenciesList.clear()
      directDependenciesList.addAll(snapshot)
    }

    fun addDirectDependencies(value: String) = apply { directDependenciesList += value }

    fun addAllDirectDependencies(values: Iterable<String>) =
      apply { directDependenciesList += values }

    fun kotlinSourcesList(value: List<String>) = apply {
      val snapshot = value.toList()
      kotlinSourcesList.clear()
      kotlinSourcesList.addAll(snapshot)
    }

    fun addKotlinSources(value: String) = apply { kotlinSourcesList += value }

    fun addAllKotlinSources(values: Iterable<String>) = apply { kotlinSourcesList += values }

    fun javaSourcesList(value: List<String>) = apply {
      val snapshot = value.toList()
      javaSourcesList.clear()
      javaSourcesList.addAll(snapshot)
    }

    fun addJavaSources(value: String) = apply { javaSourcesList += value }

    fun addAllJavaSources(values: Iterable<String>) = apply { javaSourcesList += values }

    fun sourceJarsList(value: List<String>) = apply {
      val snapshot = value.toList()
      sourceJarsList.clear()
      sourceJarsList.addAll(snapshot)
    }

    fun addSourceJars(value: String) = apply { sourceJarsList += value }

    fun addAllSourceJars(values: Iterable<String>) = apply { sourceJarsList += values }

    fun processorsList(value: List<String>) = apply {
      val snapshot = value.toList()
      processorsList.clear()
      processorsList.addAll(snapshot)
    }

    fun addProcessors(value: String) = apply { processorsList += value }

    fun addAllProcessors(values: Iterable<String>) = apply { processorsList += values }

    fun processorpathsList(value: List<String>) = apply {
      val snapshot = value.toList()
      processorpathsList.clear()
      processorpathsList.addAll(snapshot)
    }

    fun addProcessorpaths(value: String) = apply { processorpathsList += value }

    fun addAllProcessorpaths(values: Iterable<String>) = apply { processorpathsList += values }

    fun stubsPluginOptionsList(value: List<String>) = apply {
      val snapshot = value.toList()
      stubsPluginOptionsList.clear()
      stubsPluginOptionsList.addAll(snapshot)
    }

    fun addStubsPluginOptions(value: String) = apply { stubsPluginOptionsList += value }

    fun addAllStubsPluginOptions(values: Iterable<String>) =
      apply { stubsPluginOptionsList += values }

    fun stubsPluginsList(value: List<String>) = apply {
      val snapshot = value.toList()
      stubsPluginsList.clear()
      stubsPluginsList.addAll(snapshot)
    }

    fun addStubsPlugins(value: String) = apply { stubsPluginsList += value }

    fun addAllStubsPlugins(values: Iterable<String>) = apply { stubsPluginsList += values }

    fun stubsPluginClasspathList(value: List<String>) = apply {
      val snapshot = value.toList()
      stubsPluginClasspathList.clear()
      stubsPluginClasspathList.addAll(snapshot)
    }

    fun addStubsPluginClasspath(value: String) = apply { stubsPluginClasspathList += value }

    fun addAllStubsPluginClasspath(values: Iterable<String>) =
      apply { stubsPluginClasspathList += values }

    fun compilerPluginOptionsList(value: List<String>) = apply {
      val snapshot = value.toList()
      compilerPluginOptionsList.clear()
      compilerPluginOptionsList.addAll(snapshot)
    }

    fun addCompilerPluginOptions(value: String) = apply { compilerPluginOptionsList += value }

    fun addAllCompilerPluginOptions(values: Iterable<String>) =
      apply { compilerPluginOptionsList += values }

    fun compilerPluginsList(value: List<String>) = apply {
      val snapshot = value.toList()
      compilerPluginsList.clear()
      compilerPluginsList.addAll(snapshot)
    }

    fun addCompilerPlugins(value: String) = apply { compilerPluginsList += value }

    fun addAllCompilerPlugins(values: Iterable<String>) = apply { compilerPluginsList += values }

    fun compilerPluginClasspathList(value: List<String>) = apply {
      val snapshot = value.toList()
      compilerPluginClasspathList.clear()
      compilerPluginClasspathList.addAll(snapshot)
    }

    fun addCompilerPluginClasspath(value: String) = apply { compilerPluginClasspathList += value }

    fun addAllCompilerPluginClasspath(values: Iterable<String>) =
      apply { compilerPluginClasspathList += values }

    fun javacFlagsList(value: List<String>) = apply {
      val snapshot = value.toList()
      javacFlagsList.clear()
      javacFlagsList.addAll(snapshot)
    }

    fun addJavacFlags(value: String) = apply { javacFlagsList += value }

    fun addAllJavacFlags(values: Iterable<String>) = apply { javacFlagsList += values }

    fun depsArtifactsList(value: List<String>) = apply {
      val snapshot = value.toList()
      depsArtifactsList.clear()
      depsArtifactsList.addAll(snapshot)
    }

    fun addDepsArtifacts(value: String) = apply { depsArtifactsList += value }

    fun addAllDepsArtifacts(values: Iterable<String>) = apply { depsArtifactsList += values }

    fun pluginsList(value: List<Plugin>) = apply {
      val snapshot = value.toList()
      pluginsList.clear()
      pluginsList.addAll(snapshot)
    }

    fun addPlugins(value: Plugin) = apply { pluginsList += value }

    fun addAllPlugins(values: Iterable<Plugin>) = apply { pluginsList += values }

    fun build(): Inputs =
      Inputs(
        classpathList = classpathList.toList(),
        directDependenciesList = directDependenciesList.toList(),
        kotlinSourcesList = kotlinSourcesList.toList(),
        javaSourcesList = javaSourcesList.toList(),
        sourceJarsList = sourceJarsList.toList(),
        processorsList = processorsList.toList(),
        processorpathsList = processorpathsList.toList(),
        stubsPluginOptionsList = stubsPluginOptionsList.toList(),
        stubsPluginsList = stubsPluginsList.toList(),
        stubsPluginClasspathList = stubsPluginClasspathList.toList(),
        compilerPluginOptionsList = compilerPluginOptionsList.toList(),
        compilerPluginsList = compilerPluginsList.toList(),
        compilerPluginClasspathList = compilerPluginClasspathList.toList(),
        javacFlagsList = javacFlagsList.toList(),
        depsArtifactsList = depsArtifactsList.toList(),
        pluginsList = pluginsList.toList(),
      )
  }
}
