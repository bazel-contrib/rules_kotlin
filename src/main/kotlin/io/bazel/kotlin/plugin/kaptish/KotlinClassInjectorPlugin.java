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
package io.bazel.kotlin.plugin.kaptish;

import com.sun.source.util.JavacTask;
import com.sun.source.util.Plugin;
import com.sun.tools.javac.api.BasicJavacTask;
import com.sun.tools.javac.main.Arguments;
import com.sun.tools.javac.main.Option;
import com.sun.tools.javac.util.Options;

import java.io.File;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Enumeration;
import java.util.List;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;

/**
 * "Kaptish" is a javac compiler plugin that injects the module's compiled-Kotlin class names
 * into javac's annotation-processing phase, so Java annotation processors (Dagger, AutoValue,
 * ...) can see the module's Kotlin @Module/@Component/@AutoValue types without KAPT stubs.
 *
 * <p>This must be a javac {@link Plugin} (not an {@code AbstractProcessor}): the class names have
 * to be added to {@link Arguments#getClassNames()} at task {@code init} time, BEFORE javac
 * computes the initial set of root elements for annotation processing. An annotation processor's
 * {@code init} runs too late for that, which is why the previous processor-based implementation
 * failed to make Kotlin @Module companions visible to Dagger.
 *
 * <p>The jar(s) holding the module's compiled Kotlin classes are passed as plugin arguments (the
 * build wires them via {@code -Xplugin:Kaptish <abiJarPath>}). Only outer classes are injected;
 * processors reach nested types (e.g. a Kotlin {@code companion object}) via enclosed elements.
 */
public class KotlinClassInjectorPlugin implements Plugin {

  @Override
  public String getName() {
    return "Kaptish";
  }

  @Override
  public void init(JavacTask task, String... args) {
    if (!(task instanceof BasicJavacTask)) {
      return;
    }
    BasicJavacTask basicTask = (BasicJavacTask) task;
    Options options = Options.instance(basicTask.getContext());

    // Respect -proc:none (no annotation processing requested).
    if ("none".equals(options.get(Option.PROC))) {
      return;
    }

    // The build passes the module's compiled-Kotlin ABI jar via -XDkaptishSelfjar=<path>.
    // A -XD option is used (rather than a -Xplugin argument) because Bazel's JavaBuilder
    // tokenizes javacopts on whitespace, which would split a "-Xplugin:Kaptish <path>" value.
    List<String> jarPaths = new ArrayList<>();
    String selfJar = options.get("kaptishSelfjar");
    if (selfJar != null && !selfJar.isEmpty()) {
      for (String p : selfJar.split(File.pathSeparator)) {
        if (!p.isEmpty()) {
          jarPaths.add(p);
        }
      }
    }
    // Also accept any explicit -Xplugin arguments (jar paths) for flexibility.
    for (String p : args) {
      if (p != null && !p.isEmpty()) {
        jarPaths.add(p);
      }
    }

    List<String> classes = new ArrayList<>();
    for (String entry : jarPaths) {
      if (new File(entry).exists()) {
        classes.addAll(getClassesFromJar(entry));
      }
    }

    if (!classes.isEmpty()) {
      Arguments.instance(basicTask.getContext()).getClassNames().addAll(classes);
    }
  }

  /** Extract top-level (non-inner) class names from a jar. */
  private Collection<String> getClassesFromJar(String path) {
    List<String> classes = new ArrayList<>();
    try (JarFile jar = new JarFile(path)) {
      Enumeration<JarEntry> entries = jar.entries();
      while (entries.hasMoreElements()) {
        String name = entries.nextElement().getName();
        if (!name.endsWith(".class")) {
          continue;
        }
        String className = name.substring(0, name.length() - ".class".length()).replace("/", ".");
        String simpleName = className.substring(className.lastIndexOf(".") + 1);
        // Skip inner/synthetic classes (processed with their enclosing class) and infos.
        if (simpleName.contains("$")) {
          continue;
        }
        if (className.endsWith("module-info") || className.endsWith("package-info")) {
          continue;
        }
        classes.add(className);
      }
    } catch (Exception e) {
      // If the jar can't be read, inject nothing and let javac proceed normally.
    }
    return classes;
  }
}
