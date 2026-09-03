/*
 * Copyright 2018 The Bazel Authors. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 */
package io.bazel.kotlin.builder;

import com.google.common.base.Preconditions;
import com.google.common.collect.ImmutableList;
import io.bazel.kotlin.builder.Deps.AnnotationProcessor;
import io.bazel.kotlin.builder.Deps.Dep;
import io.bazel.kotlin.builder.tasks.jvm.InternalCompilerPlugins;
import io.bazel.kotlin.builder.tasks.jvm.KotlinJvmTaskExecutor;
import io.bazel.kotlin.builder.tasks.jvm.btapi.BtapiTaskExecutor;
import io.bazel.kotlin.builder.toolchain.CompilationTaskContext;
import io.bazel.kotlin.builder.toolchain.KotlinToolchain;
import io.bazel.kotlin.model.CompilationTaskInfo;
import io.bazel.kotlin.model.JvmCompilationTask;
import io.bazel.kotlin.model.KotlinToolchainInfo;

import java.util.Arrays;
import java.util.EnumSet;
import java.util.HashSet;
import java.util.function.BiConsumer;
import java.util.function.Consumer;
import java.util.stream.Collectors;
import java.util.stream.Stream;

public final class KotlinJvmTestBuilder extends KotlinAbstractTestBuilder<JvmCompilationTask> {

    @SuppressWarnings({"unused", "WeakerAccess"})
    public static Dep
            KOTLIN_ANNOTATIONS = Dep.fromLabel("//kotlin/compiler:annotations"),
            KOTLIN_STDLIB = Dep.fromLabel("//kotlin/compiler:kotlin-stdlib"),
            KOTLIN_STDLIB_JDK7 = Dep.fromLabel("//kotlin/compiler:kotlin-stdlib-jdk7"),
            KOTLIN_STDLIB_JDK8 = Dep.fromLabel("//kotlin/compiler:kotlin-stdlib-jdk8"),
            JVM_ABI_GEN = Dep.fromLabel("//kotlin/compiler:jvm-abi-gen");

    private static final JvmCompilationTask.Builder taskBuilder = JvmCompilationTask.newBuilder();
    private static final EnumSet<DirectoryType> ALL_DIRECTORY_TYPES =
            EnumSet.of(
                    DirectoryType.SOURCES,
                    DirectoryType.CLASSES,
                    DirectoryType.JAVA_CLASSES,
                    DirectoryType.ABI_CLASSES,
                    DirectoryType.SOURCE_GEN,
                    DirectoryType.JAVA_SOURCE_GEN,
                    DirectoryType.GENERATED_CLASSES,
                    DirectoryType.TEMP,
                    DirectoryType.COVERAGE_METADATA);

    private final TaskBuilder taskBuilderInstance = new TaskBuilder();
    private static KotlinJvmTaskExecutor jvmTaskExecutor;
    private static BtapiTaskExecutor btapiTaskExecutor;
    private static KotlinToolchainInfo.BtapiRuntime btapiRuntime;

    @Override
    void setupForNext(CompilationTaskInfo.Builder taskInfo) {
        taskBuilder.clear().setInfo(taskInfo);

        DirectoryType.createAll(instanceRoot(), ALL_DIRECTORY_TYPES);

        taskBuilder.getInputsBuilder()
            .addClasspath(KOTLIN_STDLIB.singleCompileJar())
            .addClasspath(KOTLIN_STDLIB_JDK7.singleCompileJar())
            .addClasspath(KOTLIN_STDLIB_JDK8.singleCompileJar());

        taskBuilder
                .getDirectoriesBuilder()
                .setClasses(directory(DirectoryType.CLASSES).toAbsolutePath().toString())
                .setJavaClasses(directory(DirectoryType.JAVA_CLASSES).toAbsolutePath().toString())
                .setAbiClasses(directory(DirectoryType.ABI_CLASSES).toAbsolutePath().toString())
                .setGeneratedSources(directory(DirectoryType.SOURCE_GEN).toAbsolutePath().toString())
                .setGeneratedJavaSources(directory(DirectoryType.JAVA_SOURCE_GEN).toAbsolutePath().toString())
                .setGeneratedStubClasses(directory(DirectoryType.GENERATED_STUBS).toAbsolutePath().toString())
                .setTemp(directory(DirectoryType.TEMP).toAbsolutePath().toString())
                .setGeneratedClasses(directory(DirectoryType.GENERATED_CLASSES).toAbsolutePath().toString())
                .setCoverageMetadataClasses(directory(DirectoryType.COVERAGE_METADATA).toAbsolutePath().toString());
    }

    @Override
    public JvmCompilationTask buildTask() {
        return taskBuilder.build();
    }

    @SafeVarargs
    public final Dep runCompileTask(Consumer<TaskBuilder>... setup) {
        // Mirror the worker's dispatch: tasks flagged for the Build Tools API run through the
        // typed executor, everything else through the legacy executor.
        return executeTask(
                (context, task) -> {
                    if (task.getInfo().getToolchainInfo().hasBtapi()) {
                        btapiTaskExecutor().execute(context, task);
                    } else {
                        jvmTaskExecutor().execute(context, task);
                    }
                },
                setup);
    }

    private static KotlinJvmTaskExecutor jvmTaskExecutor() {
        if (jvmTaskExecutor == null) {
            KotlinToolchain toolchain = toolchainForTest();
            InternalCompilerPlugins plugins = new InternalCompilerPlugins(
                    toolchain.getJvmAbiGen(),
                    toolchain.getSkipCodeGen(),
                    toolchain.getKapt3Plugin(),
                    toolchain.getJdepsGen()
            );
            jvmTaskExecutor = new KotlinJvmTaskExecutor(toolchain, plugins);
        }
        return jvmTaskExecutor;
    }

    private static BtapiTaskExecutor btapiTaskExecutor() {
        if (btapiTaskExecutor == null) {
            btapiTaskExecutor = new BtapiTaskExecutor(toolchainForTest().getBtapiClassLoader());
        }
        return btapiTaskExecutor;
    }

    /**
     * The Build Tools API runtime the worker would receive through the --btapi_* and --internal_*
     * flags. Tests run the embeddable compiler family (the dialect the Maven-published compiler
     * plugins are built against) with the matching embeddable internal plugin variants, while the
     * default toolchain exercises the CLI-distribution family through the integration fixtures.
     */
    static KotlinToolchainInfo.BtapiRuntime btapiRuntimeForTest() {
        if (btapiRuntime == null) {
            btapiRuntime = KotlinToolchainInfo.BtapiRuntime.newBuilder()
                    .addApiImplClasspath(Dep.fromLabel("@kotlin_build_tools_impl//file").singleCompileJar())
                    .addApiImplClasspath(Dep.fromLabel("//kotlin/compiler:kotlin-daemon-client").singleCompileJar())
                    .addApiImplClasspath(Dep.fromLabel("@kotlin_compiler_embeddable//file").singleCompileJar())
                    .addApiImplClasspath(Dep.fromLabel("//kotlin/compiler:kotlin-stdlib").singleCompileJar())
                    .addApiImplClasspath(Dep.fromLabel("@rules_kotlin//kotlin/compiler:kotlin-reflect").singleCompileJar())
                    .addApiImplClasspath(Dep.fromLabel("@kotlinx_coroutines_core_jvm//file").singleCompileJar())
                    .addApiImplClasspath(Dep.fromLabel("//kotlin/compiler:annotations").singleCompileJar())
                    .addApiImplClasspath(Dep.fromLabel("@kotlinx_serialization_core_jvm//file").singleCompileJar())
                    .addApiImplClasspath(Dep.fromLabel("@kotlinx_serialization_json//file").singleCompileJar())
                    .addApiImplClasspath(Dep.fromLabel("@kotlinx_serialization_json_jvm//file").singleCompileJar())
                    .addJvmAbiGenClasspath(Dep.fromLabel("@jvm_abi_gen//file").singleCompileJar())
                    .addSkipCodeGenClasspath(Dep.fromLabel("//src/main/kotlin:skip-code-gen-embeddable").singleCompileJar())
                    .addKaptClasspath(Dep.fromLabel("@kotlin_annotation_processing_embeddable//file").singleCompileJar())
                    .addJdepsGenClasspath(Dep.fromLabel("//src/main/kotlin:jdeps-gen-embeddable").singleCompileJar())
                    .build();
        }
        return btapiRuntime;
    }

    /**
     * The class-file major version of a compiled class, read from the CLASSES output directory.
     */
    public final int classFileMajorVersion(String relativeClassPath) {
        try {
            byte[] bytes = java.nio.file.Files.readAllBytes(
                    directory(DirectoryType.CLASSES).resolve(relativeClassPath));
            return ((bytes[6] & 0xFF) << 8) | (bytes[7] & 0xFF);
        } catch (java.io.IOException e) {
            throw new java.io.UncheckedIOException(e);
        }
    }

    private Dep executeTask(
            BiConsumer<CompilationTaskContext, JvmCompilationTask> executor,
            Consumer<TaskBuilder>[] setup) {
        resetForNext();
        Stream.of(setup).forEach(it -> it.accept(taskBuilderInstance));
        return runCompileTask(
                (taskContext, task) -> {
                    executor.accept(taskContext, task);

                    JvmCompilationTask.Outputs outputs = task.getOutputs();
                    assertFilesExist(
                            Stream.of(
                                            outputs.getAbijar(),
                                            outputs.getJar(),
                                            outputs.getJdeps(),
                                            outputs.getSrcjar())
                                    .filter(p -> !p.isEmpty())
                                    .toArray(String[]::new)
                    );

                    return Dep.builder()
                            .label(task.getInfo().getLabel())
                            .compileJars(ImmutableList.of(
                                    outputs.getAbijar().isEmpty() ? outputs.getJar() : outputs.getAbijar()
                            ))
                            .jdeps(outputs.getJdeps())
                            .runtimeDeps(ImmutableList.copyOf(task.getInputs().getClasspathList()))
                            .sourceJar(outputs.getSrcjar())
                            .build();
                });
    }

    public void tearDown() {
        jvmTaskExecutor = null;
    }

    public class TaskBuilder {
        TaskBuilder() {
        }

        public void setLabel(String label) {
            taskBuilder.getInfoBuilder().setLabel(label);
        }

        public void addSource(String filename, String... lines) {
            String pathAsString = writeSourceFile(filename, lines).toString();
            if (pathAsString.endsWith(".kt")) {
                taskBuilder.getInputsBuilder().addKotlinSources(pathAsString);
            } else if (pathAsString.endsWith(".java")) {
                taskBuilder.getInputsBuilder().addJavaSources(pathAsString);
            } else {
                throw new RuntimeException("unhandled file type: " + pathAsString);
            }
        }

        public TaskBuilder compileJava() {
            return this;
        }

        public TaskBuilder compileKotlin() {
            taskBuilder.getInfoBuilder().addDebug("trace").addDebug("timings");
            taskBuilder.setCompileKotlin(true);
            return this;
        }

        public TaskBuilder coverage() {
            taskBuilder.setInstrumentCoverage(true);
            return this;
        }

        public void addAnnotationProcessors(AnnotationProcessor... annotationProcessors) {
            Preconditions.checkState(
                    taskBuilder.getInputs().getProcessorsList().isEmpty(), "processors already set");
            HashSet<String> processorClasses = new HashSet<>();
            taskBuilder
                    .getInputsBuilder()
                    .addAllProcessorpaths(
                            Stream.of(annotationProcessors)
                                    .peek(it -> processorClasses.add(it.processClass()))
                                    .flatMap(it -> it.processorPath().stream())
                                    .distinct()
                                    .collect(Collectors.toList()))
                    .addAllProcessors(processorClasses);
        }

        public void addDirectDependencies(Dep... dependencies) {
            Dep.classpathOf(dependencies).forEach(dependency -> {
                taskBuilder.getInputsBuilder().addClasspath(dependency);
                taskBuilder.getInputsBuilder().addDirectDependencies(dependency);
            });
        }

        public void addTransitiveDependencies(Dep... dependencies) {
            Dep.classpathOf(dependencies).forEach(dependency -> {
                taskBuilder.getInputsBuilder().addClasspath(dependency);
            });
        }

        public TaskBuilder outputSrcJar() {
            taskBuilder.getOutputsBuilder()
                    .setSrcjar(instanceRoot().resolve("jar_file-sources.jar").toAbsolutePath().toString());
            return this;
        }

        public TaskBuilder outputJar() {
            taskBuilder.getOutputsBuilder()
                    .setJar(instanceRoot().resolve("jar_file.jar").toAbsolutePath().toString());
            return this;
        }

        public TaskBuilder outputJdeps() {
            taskBuilder.getOutputsBuilder()
                    .setJdeps(instanceRoot().resolve("jdeps_file.jdeps").toAbsolutePath().toString());
            return this;
        }

        public TaskBuilder kotlinStrictDeps(String level) {
            taskBuilder.getInfoBuilder().setStrictKotlinDeps(level);
            return this;
        }

        public TaskBuilder outputAbiJar() {
            taskBuilder.getOutputsBuilder()
                    .setAbijar(instanceRoot().resolve("abi.jar").toAbsolutePath().toString());
            return this;
        }

        public TaskBuilder publicOnlyAbiJar() {
            taskBuilder.getInfoBuilder().setTreatInternalAsPrivateInAbiJar(true).setRemovePrivateClassesInAbiJar(true);
            return this;
        }

        public TaskBuilder generatedSourceJar() {
            taskBuilder.getOutputsBuilder()
                    .setGeneratedJavaSrcJar(instanceRoot().resolve("gen-src.jar").toAbsolutePath().toString());
            return this;
        }

        public TaskBuilder ktStubsJar() {
            taskBuilder.getOutputsBuilder()
                    .setGeneratedJavaStubJar(instanceRoot().resolve("kt-stubs.jar").toAbsolutePath().toString());
            return this;
        }

        public TaskBuilder incrementalData() {
            taskBuilder.getOutputsBuilder()
                    .setGeneratedClassJar(instanceRoot().resolve("incremental.jar").toAbsolutePath().toString());
            return this;
        }

        public TaskBuilder useK2() {
            taskBuilder.getInfoBuilder()
                    .getToolchainInfoBuilder()
                    .getCommonBuilder()
                    .setLanguageVersion("2.0");
            return this;
        }

        public TaskBuilder useBuildToolsApi() {
            taskBuilder.getInfoBuilder().getToolchainInfoBuilder().setBtapi(btapiRuntimeForTest());
            return this;
        }

        public TaskBuilder addPassthroughFlags(String... flags) {
            taskBuilder.getInfoBuilder().addAllPassthroughFlags(Arrays.asList(flags));
            return this;
        }
    }
}
