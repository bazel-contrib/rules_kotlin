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

import io.bazel.kotlin.builder.Deps.AnnotationProcessor;
import io.bazel.kotlin.builder.Deps.Dep;
import io.bazel.kotlin.builder.DirectoryType;
import io.bazel.kotlin.builder.KotlinJvmTestBuilder;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

import java.util.stream.Collectors;

import static com.google.common.truth.Truth.assertThat;
import static io.bazel.kotlin.builder.KotlinJvmTestBuilder.KOTLIN_ANNOTATIONS;
import static io.bazel.kotlin.builder.KotlinJvmTestBuilder.KOTLIN_STDLIB;

/** Compiles through the Build Tools API path (toolchain-supplied btapi runtime present). */
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

    @Test
    public void testNoKotlinHomeResolutionWarnings() {
        // The typed path passes -no-stdlib/-no-reflect: the rules assemble the complete
        // classpath themselves, and a compiler runtime without a Kotlin home distribution
        // (e.g. the embeddable family) would otherwise emit "Unable to find kotlin-stdlib.jar"
        // warnings on every compile, failing compilations that enable -Werror.
        ctx.runCompileTask(
                c -> {
                    c.useBuildToolsApi();
                    c.compileKotlin();
                    c.addSource("AClass.kt", "package something;" + "class AClass{}");
                    c.outputJar();
                    c.outputJdeps();
                });
        assertThat(String.join("\n", ctx.outLines())).doesNotContain("Unable to find");
    }

    @Test
    public void testTypedArgumentsFollowToolchainJvmTarget() {
        // The worker passes jvm_target as a typed Build Tools API argument (no CLI flattening);
        // the produced bytecode must follow the toolchain's target (11 -> class file major 55).
        ctx.runCompileTask(
                c -> {
                    c.useBuildToolsApi();
                    c.compileKotlin();
                    c.addSource("AClass.kt", "package something;" + "class AClass{}");
                    c.outputJar();
                    c.outputJdeps();
                });
        assertThat(ctx.classFileMajorVersion("something/AClass.class")).isEqualTo(55);
    }

    @Test
    public void testPassthroughFlagsOverrideTypedToolchainDefaults() {
        // User pass-through flags are applied before the typed defaults and must win: an explicit
        // -jvm-target 17 (class file major 61) overrides the toolchain's jvm_target 11.
        ctx.runCompileTask(
                c -> {
                    c.useBuildToolsApi();
                    c.compileKotlin();
                    c.addPassthroughFlags("-jvm-target", "17", "-Xjdk-release=17");
                    c.addSource("AClass.kt", "package something;" + "class AClass{}");
                    c.outputJar();
                    c.outputJdeps();
                });
        assertThat(ctx.classFileMajorVersion("something/AClass.class")).isEqualTo(61);
    }

    @Test
    public void testKaptRunsThroughTypedPluginConfig() {
        // On the Build Tools API path the KAPT stubs-and-apt pre-pass is configured as a typed
        // plugin descriptor (no base64 -P configuration blob); the annotation processor must
        // still run and generate sources that are compiled into the output.
        Dep autoValueAnnotations = Dep.fromLabel("auto_value_annotations");
        Dep autoValue = Dep.fromLabel("auto_value");
        AnnotationProcessor autoValueProcessor =
                AnnotationProcessor.builder()
                        .processClass("com.google.auto.value.processor.AutoValueProcessor")
                        .processorPath(
                                Dep.classpathOf(autoValueAnnotations, autoValue, KOTLIN_ANNOTATIONS)
                                        .collect(Collectors.toSet()))
                        .build();

        ctx.runCompileTask(
                c -> {
                    c.useBuildToolsApi();
                    c.compileKotlin();
                    c.addAnnotationProcessors(autoValueProcessor);
                    c.addDirectDependencies(autoValueAnnotations, KOTLIN_ANNOTATIONS, KOTLIN_STDLIB);
                    c.addSource(
                            "TestKtValue.kt",
                            "package autovalue\n"
                                    + "\n"
                                    + "import com.google.auto.value.AutoValue\n"
                                    + "\n"
                                    + "@AutoValue\n"
                                    + "abstract class TestKtValue {\n"
                                    + "    abstract fun name(): String\n"
                                    + "    fun builder(): Builder = AutoValue_TestKtValue.Builder()\n"
                                    + "\n"
                                    + "    @AutoValue.Builder\n"
                                    + "    abstract class Builder {\n"
                                    + "        abstract fun setName(name: String): Builder\n"
                                    + "        abstract fun build(): TestKtValue\n"
                                    + "    }\n"
                                    + "}");
                    c.outputJar();
                    c.outputJdeps();
                    c.generatedSourceJar();
                    c.ktStubsJar();
                    c.incrementalData();
                });

        ctx.assertFilesExist(DirectoryType.JAVA_SOURCE_GEN, "autovalue/AutoValue_TestKtValue.java");
        ctx.assertFilesExist(DirectoryType.CLASSES, "autovalue/TestKtValue.class");
    }

    @Test
    public void testAbiJarGeneration() {
        // The abi jar is produced by the jvm-abi-gen compiler plugin configured as a typed
        // descriptor; the plugin must load in the compiler runtime the test harness configures
        // (the embeddable compiler family). The output jar is requested too: without it the
        // skip-code-gen plugin would engage, and that plugin does not support the K2 compiler.
        ctx.runCompileTask(
                c -> {
                    c.useBuildToolsApi();
                    c.compileKotlin();
                    c.addSource("AClass.kt", "package something;" + "class AClass{}");
                    c.outputJar();
                    c.outputAbiJar();
                    c.outputJdeps();
                });
        ctx.assertFilesExist(DirectoryType.ABI_CLASSES, "something/AClass.class");
    }

    @Test
    public void testJdkApiSurfaceLimitedToJvmTarget() {
        // The BTAPI implementation enforces compile-time JDK API version to correspond to the selected jvm_target via -Xjdk-release.
        ctx.runFailingCompileTaskAndValidateOutput(
                () -> ctx.runCompileTask(
                        c -> {
                            c.useBuildToolsApi();
                            c.compileKotlin();
                            // java.util.HexFormat exists since JDK 17, while the test toolchain targets jvm 11.
                            c.addSource("HexUser.kt", "package something;", "fun hex(): String = java.util.HexFormat.of().toString()");
                            c.outputJar();
                            c.outputJdeps();
                        }),
                lines -> assertThat(String.join("\n", lines)).contains("HexFormat"));
    }

}
