/*
 * Copyright 2026 The Bazel Authors. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package io.bazel.kotlin.builder.tasks.jvm;

import io.bazel.kotlin.builder.DirectoryType;
import io.bazel.kotlin.builder.KotlinJvmTestBuilder;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

import static com.google.common.truth.Truth.assertThat;

/** Compiles through the Build Tools API path ({@code --build_tools_api=true}). */
@RunWith(JUnit4.class)
public class KotlinBuilderJvmBtaTest {
    private static final KotlinJvmTestBuilder ctx = new KotlinJvmTestBuilder();

    @Test
    public void testSimpleKotlinCompile() {
        ctx.runCompileTask(
                c -> {
                    c.useBuildToolsApi();
                    c.compileKotlin();
                    c.addSource("AClass.kt", "package something;" + "class AClass{}");
                    c.outputJar();
                    c.outputJdeps();
                });
        ctx.assertFilesExist(DirectoryType.CLASSES, "something/AClass.class");
    }

    @Test
    public void testMixedModeCompile() {
        // The Kotlin class references the Java class, so the compilation is only successful, if the .java source reaches the compiler's source list.
        ctx.runCompileTask(
                c -> {
                    c.useBuildToolsApi();
                    c.compileKotlin();
                    c.addSource(
                            "AClass.kt",
                            "package something;" + "class AClass{ val other = AnotherClass() }");
                    c.addSource(
                            "AnotherClass.java",
                            "package something;",
                            "",
                            "public class AnotherClass{}");
                    c.outputJar();
                    c.outputJdeps();
                });
        ctx.assertFilesExist(DirectoryType.CLASSES, "something/AClass.class");
    }

    @Test
    public void testVerboseOutputIsReported() {
        // The tracing mode enabled by 'compileKotlin()' is mapped to compiler's -verbose flag, which enables task output to stderr
        ctx.runCompileTask(
                c -> {
                    c.useBuildToolsApi();
                    c.compileKotlin();
                    c.addSource("AClass.kt", "package something;" + "class AClass{}");
                    c.outputJar();
                    c.outputJdeps();
                });
        assertThat(String.join("\n", ctx.outLines())).contains("Loading modules");
    }

    @Test
    public void testCompilerDiagnosticsAreReported() {
        // Compiler diagnostics must be printed to stderr
        ctx.runFailingCompileTaskAndValidateOutput(
                () -> ctx.runCompileTask(
                        c -> {
                            c.useBuildToolsApi();
                            c.compileKotlin();
                            c.addSource(
                                    "Broken.kt",
                                    "package something;",
                                    "",
                                    "val broken = DoesNotExist()");
                            c.outputJar();
                            c.outputJdeps();
                        }),
                lines -> assertThat(String.join("\n", lines)).contains("DoesNotExist"));
    }
}
