/*
 * Copyright 2020 The Bazel Authors. All rights reserved.
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
package io.bazel.kotlin.builder.tasks.jvm;

import io.bazel.kotlin.builder.Deps;
import io.bazel.kotlin.builder.DirectoryType;
import io.bazel.kotlin.builder.KotlinJvmTestBuilder;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.function.Consumer;

import static com.google.common.truth.Truth.assertThat;

@RunWith(JUnit4.class)
public class KotlinBuilderJvmBasicTest {
    private static final KotlinJvmTestBuilder ctx = new KotlinJvmTestBuilder();

    private static final Consumer<KotlinJvmTestBuilder.TaskBuilder> SETUP_NORMALIZATION_TEST_SOURCES =
            ctx -> {
                ctx.compileKotlin();
                ctx.addSource("AClass.kt", "package something;\n" + "class AClass{}");
                ctx.addSource("BClass.kt", "package something;\n" + "class BClass{}");
                ctx.outputJar();
                ctx.outputJdeps();
            };

    private static String hashDep(String path) {
        try {
            //noinspection UnstableApiUsage
            return com.google.common.hash.Hashing.sha256()
                    .hashBytes(Files.readAllBytes(Paths.get(path)))
                    .toString();
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    @Test
    public void testSimpleMixedModeCompile() {
        ctx.runCompileTask(
                c -> {
                    c.compileKotlin();
                    c.addSource(
                            "AClass.kt",
                            "package something;" + "class AClass{}"
                    );
                    c.outputJar();
                    c.outputJdeps();
                });
        ctx.assertFilesExist(DirectoryType.CLASSES, "something/AClass.class");
    }

    @Test
    public void testGeneratesJDeps() {
        ctx.runCompileTask(
                c -> {
                    c.addSource("AClass.kt", "package something;" + "class AClass{}");
                    // declaring outputJdeps also asserts existance after compile.
                    c.outputJar().outputJdeps().compileKotlin();
                });
    }

    @Test
    public void testKotlinErrorRendering() {
        ctx.runFailingCompileTaskAndValidateOutput(
                () ->
                        ctx.runCompileTask(
                                c -> {
                                    c.compileKotlin();
                                    c.addSource("AClass.kt", "package something;" + "class AClass{");
                                    c.outputJar();
                                    c.outputJdeps();
                                }),
                lines -> assertThat(
                        lines.stream().anyMatch(line -> line.startsWith(ctx.toPlatform("sources/AClass")))
                ).isTrue());
    }

    @Test
    public void testPluginOrderConstraintsReachThePluginLoader() {
        // -Xcompiler-plugin-order travels on the pass-through channel to the compiler's plugin loader.
        // The loader parses every constraint: a malformed one fails the compilation with its diagnostic.
        ctx.runFailingCompileTaskAndValidateOutput(
                () -> ctx.runCompileTask(
                        c -> {
                            c.compileKotlin();
                            c.addPassthroughFlags("-Xcompiler-plugin-order=first.plugin");
                            c.addSource("AClass.kt", "package something;" + "class AClass{}");
                            c.outputJar();
                            c.outputJdeps();
                        }),
                lines -> assertThat(String.join("\n", lines))
                        .containsMatch("(?i)could not parse plugin order constraint: first\\.plugin"));
    }

    @Test
    public void testPluginOrderConstraintsOnUnregisteredPluginsAreIgnored() {
        // The plugin loader ignores a constraint that names a plugin the compilation does not register.
        ctx.runCompileTask(
                c -> {
                    c.compileKotlin();
                    c.addPassthroughFlags("-Xcompiler-plugin-order=first.plugin>second.plugin");
                    c.addSource("AClass.kt", "package something;" + "class AClass{}");
                    c.outputJar();
                    c.outputJdeps();
                });
        ctx.assertFilesExist(DirectoryType.CLASSES, "something/AClass.class");
    }

    @Test
    public void testCompiledJarIsNormalized() {
        Deps.Dep previous = ctx.runCompileTask(SETUP_NORMALIZATION_TEST_SOURCES);
        Deps.Dep recompiled =
                ctx.runCompileTask(ctx -> ctx.setLabel(previous.label()), SETUP_NORMALIZATION_TEST_SOURCES);
        assertThat(previous.label()).isEqualTo(recompiled.label());
        assertThat(hashDep(previous.singleCompileJar()))
                .isEqualTo(hashDep(recompiled.singleCompileJar()));
    }
}
