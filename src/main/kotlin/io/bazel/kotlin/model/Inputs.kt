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
  }

  class Builder {
    private var model = Inputs()
    private val classpathList = mutableListOf<String>()
    private val directDependenciesList = mutableListOf<String>()
    private val kotlinSourcesList = mutableListOf<String>()
    private val javaSourcesList = mutableListOf<String>()
    private val sourceJarsList = mutableListOf<String>()
    private val processorsList = mutableListOf<String>()
    private val processorpathsList = mutableListOf<String>()
    private val stubsPluginOptionsList = mutableListOf<String>()
    private val stubsPluginsList = mutableListOf<String>()
    private val stubsPluginClasspathList = mutableListOf<String>()
    private val compilerPluginOptionsList = mutableListOf<String>()
    private val compilerPluginsList = mutableListOf<String>()
    private val compilerPluginClasspathList = mutableListOf<String>()
    private val javacFlagsList = mutableListOf<String>()
    private val depsArtifactsList = mutableListOf<String>()
    private val pluginsList = mutableListOf<Plugin>()

    fun classpathList(value: List<String>) =
      apply {
        classpathList.clear()
        classpathList.addAll(value)
      }

    fun addClasspath(value: String) = apply { classpathList.add(value) }

    fun addAllClasspath(values: Iterable<String>) = apply { classpathList.addAll(values) }

    fun directDependenciesList(value: List<String>) =
      apply {
        directDependenciesList.clear()
        directDependenciesList.addAll(value)
      }

    fun addDirectDependencies(value: String) = apply { directDependenciesList.add(value) }

    fun addAllDirectDependencies(values: Iterable<String>) =
      apply {
        directDependenciesList.addAll(values)
      }

    fun kotlinSourcesList(value: List<String>) =
      apply {
        kotlinSourcesList.clear()
        kotlinSourcesList.addAll(value)
      }

    fun addKotlinSources(value: String) = apply { kotlinSourcesList.add(value) }

    fun addAllKotlinSources(values: Iterable<String>) = apply { kotlinSourcesList.addAll(values) }

    fun javaSourcesList(value: List<String>) =
      apply {
        javaSourcesList.clear()
        javaSourcesList.addAll(value)
      }

    fun addJavaSources(value: String) = apply { javaSourcesList.add(value) }

    fun addAllJavaSources(values: Iterable<String>) = apply { javaSourcesList.addAll(values) }

    fun sourceJarsList(value: List<String>) =
      apply {
        sourceJarsList.clear()
        sourceJarsList.addAll(value)
      }

    fun addSourceJars(value: String) = apply { sourceJarsList.add(value) }

    fun addAllSourceJars(values: Iterable<String>) = apply { sourceJarsList.addAll(values) }

    fun processorsList(value: List<String>) =
      apply {
        processorsList.clear()
        processorsList.addAll(value)
      }

    fun addProcessors(value: String) = apply { processorsList.add(value) }

    fun addAllProcessors(values: Iterable<String>) = apply { processorsList.addAll(values) }

    fun processorpathsList(value: List<String>) =
      apply {
        processorpathsList.clear()
        processorpathsList.addAll(value)
      }

    fun addProcessorpaths(value: String) = apply { processorpathsList.add(value) }

    fun addAllProcessorpaths(values: Iterable<String>) = apply { processorpathsList.addAll(values) }

    fun stubsPluginOptionsList(value: List<String>) =
      apply {
        stubsPluginOptionsList.clear()
        stubsPluginOptionsList.addAll(value)
      }

    fun addStubsPluginOptions(value: String) = apply { stubsPluginOptionsList.add(value) }

    fun addAllStubsPluginOptions(values: Iterable<String>) =
      apply {
        stubsPluginOptionsList.addAll(values)
      }

    fun stubsPluginsList(value: List<String>) =
      apply {
        stubsPluginsList.clear()
        stubsPluginsList.addAll(value)
      }

    fun addStubsPlugins(value: String) = apply { stubsPluginsList.add(value) }

    fun addAllStubsPlugins(values: Iterable<String>) = apply { stubsPluginsList.addAll(values) }

    fun stubsPluginClasspathList(value: List<String>) =
      apply {
        stubsPluginClasspathList.clear()
        stubsPluginClasspathList.addAll(value)
      }

    fun addStubsPluginClasspath(value: String) = apply { stubsPluginClasspathList.add(value) }

    fun addAllStubsPluginClasspath(values: Iterable<String>) =
      apply {
        stubsPluginClasspathList.addAll(values)
      }

    fun compilerPluginOptionsList(value: List<String>) =
      apply {
        compilerPluginOptionsList.clear()
        compilerPluginOptionsList.addAll(value)
      }

    fun addCompilerPluginOptions(value: String) = apply { compilerPluginOptionsList.add(value) }

    fun addAllCompilerPluginOptions(values: Iterable<String>) =
      apply {
        compilerPluginOptionsList.addAll(values)
      }

    fun compilerPluginsList(value: List<String>) =
      apply {
        compilerPluginsList.clear()
        compilerPluginsList.addAll(value)
      }

    fun addCompilerPlugins(value: String) = apply { compilerPluginsList.add(value) }

    fun addAllCompilerPlugins(values: Iterable<String>) =
      apply { compilerPluginsList.addAll(values) }

    fun compilerPluginClasspathList(value: List<String>) =
      apply {
        compilerPluginClasspathList.clear()
        compilerPluginClasspathList.addAll(value)
      }

    fun addCompilerPluginClasspath(value: String) = apply { compilerPluginClasspathList.add(value) }

    fun addAllCompilerPluginClasspath(values: Iterable<String>) =
      apply {
        compilerPluginClasspathList.addAll(values)
      }

    fun javacFlagsList(value: List<String>) =
      apply {
        javacFlagsList.clear()
        javacFlagsList.addAll(value)
      }

    fun addJavacFlags(value: String) = apply { javacFlagsList.add(value) }

    fun addAllJavacFlags(values: Iterable<String>) = apply { javacFlagsList.addAll(values) }

    fun depsArtifactsList(value: List<String>) =
      apply {
        depsArtifactsList.clear()
        depsArtifactsList.addAll(value)
      }

    fun addDepsArtifacts(value: String) = apply { depsArtifactsList.add(value) }

    fun addAllDepsArtifacts(values: Iterable<String>) = apply { depsArtifactsList.addAll(values) }

    fun pluginsList(value: List<Plugin>) =
      apply {
        pluginsList.clear()
        pluginsList.addAll(value)
      }

    fun addPlugins(value: Plugin) = apply { pluginsList.add(value) }

    fun addAllPlugins(values: Iterable<Plugin>) = apply { pluginsList.addAll(values) }

    fun build(): Inputs =
      model.copy(
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
