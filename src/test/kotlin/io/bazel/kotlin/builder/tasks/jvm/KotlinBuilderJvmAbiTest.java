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
import io.bazel.kotlin.builder.KotlinJvmTestBuilder;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

import java.io.IOException;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;

import static org.hamcrest.MatcherAssert.assertThat;
import static org.hamcrest.core.Is.is;
import static org.hamcrest.core.IsNot.not;
import static org.hamcrest.core.IsNull.nullValue;

@RunWith(JUnit4.class)
public class KotlinBuilderJvmAbiTest {
  private static final KotlinJvmTestBuilder ctx = new KotlinJvmTestBuilder();

  @Test
  public void testGeneratesAbiOnly() {
    Deps.Dep d = ctx.runCompileTask(
        c -> {
          c.addPassthroughFlags("-jvm-target", "17");
          c.addSource("AClass.kt", "package something;" + "class AClass{}");
          c.addSource("AnotherClass.kt", "package something;", "", "class AnotherClass{}");
          c.outputAbiJar();
          c.compileKotlin();
          c.outputJdeps();
        });
    assertThat(ctx.classFileMajorVersion("something/AClass.class"), is(61));
    ctx.runCompileTask(
        c -> {
          c.addDirectDependencies(d);
          c.addSource("Dependent.kt",
              "package dep;",
              "import something.AClass",
              "class Dependent{}");
          c.outputJar().outputJdeps().compileKotlin();
        });
  }

  @Test
  public void testGeneratesAbiJarSource() {
    ctx.runCompileTask(
        c -> {
          c.addSource("AClass.kt", "package something;" + "class AClass{}");
          c.addSource("AnotherClass.kt", "package something;", "", "class AnotherClass{}");
          c.outputJar();
          c.outputJdeps();
          c.outputAbiJar();
          c.compileKotlin();
        });
  }

    @Test
    public void testGeneratesPublicAbiOnly() throws IOException {
        Deps.Dep d = ctx.runCompileTask(
                c -> {
                    c.addSource("AClass.kt", "package something;" + "class AClass{}");
                    c.addSource("AnotherClass.kt", "package something;", "", "class AnotherClass{}");
                    c.addSource("NonPublicClass.kt", "package something;", "", "internal class NonPublicClass{}");
                    c.outputJar();
                    c.outputAbiJar();
                    c.publicOnlyAbiJar();
                    c.compileKotlin();
                    c.outputJdeps();
                });

        String abiJarPath = d.compileJars()
                .stream()
                .filter( (name)->name.endsWith("abi.jar") )
                .findFirst()
                .orElse(null);

        assertThat(abiJarPath, is(not(nullValue())));

        ZipEntry entry = null;
        try( ZipFile zipFile = new ZipFile(abiJarPath) ) {
            entry = zipFile.getEntry("something/NonPublicClass.class");
        }
        assertThat(entry, is(nullValue()));
    }


    @Test
    public void testGeneratesAbiIncludingInternal() throws IOException {
        Deps.Dep d = ctx.runCompileTask(
                c -> {
                    c.addSource("AClass.kt", "package something;" + "class AClass{}");
                    c.addSource("AnotherClass.kt", "package something;", "", "class AnotherClass{}");
                    c.addSource("NonPublicClass.kt", "package something;", "", "internal class NonPublicClass{}");
                    c.outputJar();
                    c.outputAbiJar();
                    c.compileKotlin();
                    c.outputJdeps();
                });

        String abiJarPath = d.compileJars()
                .stream()
                .filter( (name)->name.endsWith("abi.jar") )
                .findFirst()
                .orElse(null);

        assertThat(abiJarPath, is(not(nullValue())));

        ZipEntry entry = null;
        try( ZipFile zipFile = new ZipFile(abiJarPath) ) {
            entry = zipFile.getEntry("something/NonPublicClass.class");
        }
        assertThat(entry, is(not(nullValue())));
    }
}
