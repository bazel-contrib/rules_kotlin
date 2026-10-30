/*
 * Copyright 2018 The Bazel Authors. All rights reserved.
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

import java.util.function.Consumer;
import java.util.stream.Collectors;

import static com.google.common.truth.Truth.assertThat;
import static io.bazel.kotlin.builder.KotlinJvmTestBuilder.KOTLIN_ANNOTATIONS;
import static io.bazel.kotlin.builder.KotlinJvmTestBuilder.KOTLIN_STDLIB;

@RunWith(JUnit4.class)
public class KotlinBuilderJvmKaptTest {
    private static final Dep AUTO_VALUE_ANNOTATIONS =
            Dep.fromLabel("auto_value_annotations");
    private static final Dep AUTO_VALUE =
            Dep.fromLabel("auto_value");
    private static final AnnotationProcessor AUTO_VALUE_ANNOTATION_PROCESSOR =
            AnnotationProcessor.builder()
                    .processClass("com.google.auto.value.processor.AutoValueProcessor")
                    .processorPath(
                            Dep.classpathOf(AUTO_VALUE_ANNOTATIONS, AUTO_VALUE, KOTLIN_ANNOTATIONS)
                                    .collect(Collectors.toSet()))
                    .build();

    private static final KotlinJvmTestBuilder ctx = new KotlinJvmTestBuilder();

    private static final Consumer<KotlinJvmTestBuilder.TaskBuilder> ADD_AUTO_VALUE_PLUGIN =
            (c) -> {
                c.addAnnotationProcessors(AUTO_VALUE_ANNOTATION_PROCESSOR);
                c.addDirectDependencies(AUTO_VALUE_ANNOTATIONS, KOTLIN_ANNOTATIONS, KOTLIN_STDLIB);
            };

    @Test
    public void testKaptKt() {
        ctx.runCompileTask(
                ADD_AUTO_VALUE_PLUGIN,
                c -> {
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
                    c.generatedSourceJar();
                    c.ktStubsJar();
                    c.incrementalData();
                }
        );

        ctx.assertFilesExist(
                DirectoryType.INCREMENTAL_DATA,
                "autovalue/TestKtValue.class");
        ctx.assertFilesExist(DirectoryType.JAVA_SOURCE_GEN, "autovalue/AutoValue_TestKtValue.java");
    }

    @Test
    public void testMixedKaptBiReferences() {
        ctx.runCompileTask(
                ADD_AUTO_VALUE_PLUGIN,
                ctx -> {
                    ctx.addSource(
                            "TestKtValue.kt",
                            "package autovalue.a\n"
                                    + "\n"
                                    + "import com.google.auto.value.AutoValue\n"
                                    + "import autovalue.b.TestAutoValue\n"
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

                    ctx.addSource(
                            "TestAutoValue.java",
                            "package autovalue.b;\n"
                                    + "\n"
                                    + "import com.google.auto.value.AutoValue;\n"
                                    + "import autovalue.a.TestKtValue;\n"
                                    + "\n"
                                    + "@AutoValue\n"
                                    + "public abstract class TestAutoValue {\n"
                                    + "    abstract String name();\n"
                                    + "\n"
                                    + "\n"
                                    + "    static Builder builder() {\n"
                                    + "        return new AutoValue_TestAutoValue.Builder();\n"
                                    + "    }\n"
                                    + "\n"
                                    + "    @AutoValue.Builder\n"
                                    + "    abstract static class Builder {\n"
                                    + "        abstract Builder setName(String name);\n"
                                    + "        abstract TestAutoValue build();\n"
                                    + "    }\n"
                                    + "\n"
                                    + "}");
                    ctx.outputJar();
                    ctx.generatedSourceJar();
                    ctx.ktStubsJar();
                    ctx.incrementalData();
                });
        ctx.assertFilesExist(
                DirectoryType.JAVA_SOURCE_GEN,
                "autovalue/a/AutoValue_TestKtValue.java",
                "autovalue/b/AutoValue_TestAutoValue.java");
    }

    @Test
    public void testKaptStubsFollowPassthroughFlags() {
        // The pre-pass takes the pass-through flags of the main compile. With -jvm-target 17 the
        // stub classes get the class file major version 61. The toolchain's target 11 would give 55.
        ctx.runCompileTask(
                ADD_AUTO_VALUE_PLUGIN,
                c -> {
                    c.addPassthroughFlags("-jvm-target", "17");
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
                    c.generatedSourceJar();
                    c.ktStubsJar();
                    c.incrementalData();
                }
        );

        assertThat(ctx.classFileMajorVersion(DirectoryType.INCREMENTAL_DATA, "autovalue/TestKtValue.class"))
                .isEqualTo(61);
    }
}
