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

import io.bazel.kotlin.builder.tasks.jvm.InternalCompilerPlugins;
import io.bazel.kotlin.builder.toolchain.CompilationStatusException;
import io.bazel.kotlin.builder.toolchain.CompilationTaskContext;
import io.bazel.kotlin.builder.toolchain.KotlinToolchain;
import io.bazel.kotlin.model.CompilationTaskInfo;
import io.bazel.kotlin.model.KotlinToolchainInfo;
import io.bazel.kotlin.model.Platform;
import io.bazel.kotlin.model.RuleKind;

import java.io.*;
import java.nio.file.FileSystem;
import java.nio.file.FileSystems;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Arrays;
import java.util.List;
import java.util.Objects;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.BiFunction;
import java.util.function.Consumer;
import java.util.stream.Collectors;
import java.util.stream.Stream;

import static com.google.common.truth.Truth.assertWithMessage;
import static java.nio.charset.StandardCharsets.UTF_8;
import static java.util.Collections.unmodifiableList;
import static java.util.stream.Collectors.toList;

abstract class KotlinAbstractTestBuilder<T> {
    private static final Path BAZEL_TEST_DIR =
            FileSystems.getDefault().getPath(System.getenv("TEST_TMPDIR"));

    private static final AtomicInteger counter = new AtomicInteger(0);
    private final CompilationTaskInfo.Builder infoBuilder = CompilationTaskInfo.newBuilder();
    private Path instanceRoot = null;
    private String label = null;
    private List<String> outLines = null;

    private static void assertFileExistence(Stream<Path> pathStream, boolean shouldExist) {
        pathStream.forEach(
                path -> {
                    if (shouldExist)
                        assertWithMessage("file did not exist: %s", path).that(path.toFile().exists()).isTrue();
                    else assertWithMessage("file existed: " + path).that(path.toFile().exists()).isFalse();
                });
    }

    /**
     * Normalize a path string.
     *
     * @param path a path using '/' as the separator.
     * @return a path string suitable for the target platform.
     */
    private static Path toPlatformPath(String path) {
        assert !path.startsWith("/") : path + " is an absolute path";
        String[] parts = path.split("/");
        return parts.length == 1
                ? Paths.get(parts[0])
                : Paths.get(parts[0], Arrays.copyOfRange(parts, 1, parts.length));
    }

    abstract void setupForNext(CompilationTaskInfo.Builder infoBuilder);

    abstract T buildTask();

    final String label() {
        return Objects.requireNonNull(label);
    }

    final Path instanceRoot() {
        return Objects.requireNonNull(instanceRoot);
    }

    @SuppressWarnings("WeakerAccess")
    public final List<String> outLines() {
        return outLines;
    }

    public final void resetForNext() {
        outLines = null;
        label = "a-test-" + counter.incrementAndGet();
        infoBuilder
                .setLabel("//some/bogus:" + label())
                .setModuleName("some_bogus_module")
                .setPlatform(Platform.JVM)
                .setRuleKind(RuleKind.LIBRARY)
                .setToolchainInfo(
                        KotlinToolchainInfo.newBuilder()
                                .setCommon(
                                        KotlinToolchainInfo.Common.newBuilder()
                                                .setApiVersion("2.0")
                                                .setCoroutines("enabled")
                                                .setLanguageVersion("2.0"))
                                .setJvm(KotlinToolchainInfo.Jvm.newBuilder().setJvmTarget("11")));
        try {
            this.instanceRoot = Files.createTempDirectory(BAZEL_TEST_DIR, label);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
        setupForNext(infoBuilder);
    }

    final Path directory(DirectoryType type) {
        return type.resolve(instanceRoot);
    }

    @SuppressWarnings("unused")
    public final void setDebugTags(String... tags) {
        infoBuilder.addAllDebug(Arrays.asList(tags));
    }

    final Path writeFile(DirectoryType dirType, String filename, String[] lines) {
        Path path = directory(dirType).resolve(filename).toAbsolutePath();
        try {
            Files.createDirectories(path.getParent());
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
        try (FileOutputStream fos = new FileOutputStream(path.toFile())) {
            fos.write(String.join("\n", lines).getBytes(UTF_8));
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
        return path;
    }


    public final Path writeSourceFile(String filename, String[] lines) {
        return writeFile(DirectoryType.SOURCES, filename, lines);
    }

    public final Path writeGeneratedSourceFile(String filename, String[] lines) {
        return writeFile(DirectoryType.SOURCE_GEN, filename, lines);
    }

    final <R> R runCompileTask(BiFunction<CompilationTaskContext, T, R> operation) {
        T task = buildTask();
        return runCompileTask(infoBuilder.build(), task, (ctx, t) -> operation.apply(ctx, task));
    }

    private <R> R runCompileTask(
            CompilationTaskInfo info, T task, BiFunction<CompilationTaskContext, T, R> operation) {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        try (PrintStream outputStream = new PrintStream(out)) {
            return operation.apply(new CompilationTaskContext(info, outputStream,
                    instanceRoot().toAbsolutePath() + File.separator), task);
        } finally {
            outLines = unmodifiableList(
                    new BufferedReader(new InputStreamReader(new ByteArrayInputStream(out.toByteArray())))
                            .lines()
                            .collect(toList()));
        }
    }

    public final void assertFilesExist(DirectoryType dir, String... paths) {
        assertFileExistence(resolved(dir, paths), true);
    }

    final void assertFilesExist(String... paths) {
        assertFileExistence(Stream.of(paths).map(Paths::get), true);
    }

    @SuppressWarnings("unused")
    public final void assertFilesDoNotExist(DirectoryType dir, String... filePath) {
        assertFileExistence(resolved(dir, filePath), false);
    }

    /**
     * Run a compilation task expecting it to fail with a {@link CompilationStatusException}.
     *
     * @param task      the compilation task
     * @param validator a consumer for the output produced by the task.
     */
    public final void runFailingCompileTaskAndValidateOutput(
            Runnable task, Consumer<List<String>> validator) {
        try {
            task.run();
        } catch (CompilationStatusException ex) {
            validator.accept(outLines());
            return;
        }
        throw new RuntimeException("compilation task should have failed.");
    }

    private Stream<Path> resolved(DirectoryType dir, String... filePath) {
        Path directory = directory(dir);
        return Stream.of(filePath).map(f -> directory.resolve(toPlatformPath(f)));
    }

    public final String toPlatform(String path) {
        return KotlinAbstractTestBuilder.toPlatformPath(path).toString();
    }

    @SuppressWarnings("unused")
    private Stream<Path> directoryContents(DirectoryType type) {
        try {
            return Files.walk(directory(type)).map(p -> directory(type).relativize(p));
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    @SuppressWarnings("unused")
    public final void logDirectoryContents(DirectoryType type) {
        System.out.println(
                directoryContents(type)
                        .map(Path::toString)
                        .collect(Collectors.joining("\n", "directory " + type.name + " contents:\n", "")));
    }

    static KotlinToolchain toolchainForTest() {
        return KotlinToolchain.createToolchain(
                new File(Deps.Dep.fromLabel("//kotlin/compiler:kotlin-compiler").singleCompileJar()),
                new File(Deps.Dep.fromLabel("//kotlin/compiler:kotlin-build-tools-impl").singleCompileJar()),
                new File(Deps.Dep.fromLabel("//src/main/kotlin:compiler").singleCompileJar()),
                new File(Deps.Dep.fromLabel("//kotlin/compiler:jvm-abi-gen").singleCompileJar()),
                new File(Deps.Dep.fromLabel("//src/main/kotlin:skip-code-gen").singleCompileJar()),
                new File(Deps.Dep.fromLabel("//src/main/kotlin:jdeps-gen").singleCompileJar()),
                new File(Deps.Dep.fromLabel("//kotlin/compiler:kotlin-annotation-processing").singleCompileJar()),
                new File(Deps.Dep.fromLabel("//kotlin/compiler:kotlin-stdlib").singleCompileJar()),
                new File(Deps.Dep.fromLabel("//kotlin/compiler:kotlin-reflect").singleCompileJar()),
                new File(Deps.Dep.fromLabel("//kotlin/compiler:kotlinx-serialization-core-jvm").singleCompileJar()),
                new File(Deps.Dep.fromLabel("//kotlin/compiler:kotlinx-serialization-json-jvm").singleCompileJar())
        );
    }

    static InternalCompilerPlugins internalPluginsForTest() {
        return new InternalCompilerPlugins(
                new KotlinToolchain.CompilerPlugin(
                        Deps.Dep.fromLabel("//kotlin/compiler:jvm-abi-gen").singleCompileJar(),
                        "org.jetbrains.kotlin.jvm.abi"),
                new KotlinToolchain.CompilerPlugin(
                        Deps.Dep.fromLabel("//src/main/kotlin:skip-code-gen").singleCompileJar(),
                        "io.bazel.kotlin.plugin.SkipCodeGen"),
                new KotlinToolchain.CompilerPlugin(
                        Deps.Dep.fromLabel("//kotlin/compiler:kotlin-annotation-processing").singleCompileJar(),
                        "org.jetbrains.kotlin.kapt3"),
                new KotlinToolchain.CompilerPlugin(
                        Deps.Dep.fromLabel("//src/main/kotlin:jdeps-gen").singleCompileJar(),
                        "io.bazel.kotlin.plugin.jdeps.JDepsGen")
        );
    }
}
