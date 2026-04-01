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
package io.bazel.kotlin.builder.tasks.jvm.btapi

import com.google.devtools.build.lib.view.proto.Deps
import io.bazel.kotlin.model.JvmCompilationTask
import java.io.BufferedInputStream
import java.nio.file.Files
import java.nio.file.Paths

object BtapiClasspathResolver {
  fun computeClasspath(task: JvmCompilationTask): List<String> {
    val baseClasspath =
      when (task.info.reducedClasspathMode) {
        "KOTLINBUILDER_REDUCED" -> computeReducedClasspath(task)
        else -> task.inputs.classpathList
      }

    return prioritizeFriendPaths(baseClasspath, task.info.friendPathsList) +
      task.directories.generatedClasses
  }

  private fun computeReducedClasspath(task: JvmCompilationTask): List<String> {
    val transitiveDepsForCompile = linkedSetOf<String>()
    task.inputs.depsArtifactsList.forEach { jdepsPath ->
      BufferedInputStream(Files.newInputStream(Paths.get(jdepsPath))).use {
        val deps = Deps.Dependencies.parseFrom(it)
        deps.dependencyList.forEach { dep ->
          if (dep.kind == Deps.Dependency.Kind.EXPLICIT) {
            transitiveDepsForCompile.add(dep.path)
          }
        }
      }
    }
    return task.inputs.directDependenciesList + transitiveDepsForCompile
  }

  fun prioritizeFriendPaths(
    classpath: List<String>,
    friendPaths: List<String>,
  ): List<String> {
    val friendPathsSet = friendPaths.toSet()
    val classpathWithoutFriends = classpath.filter { it !in friendPathsSet }
    return friendPaths + classpathWithoutFriends
  }
}
