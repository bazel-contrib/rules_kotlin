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
package io.bazel.kotlin.builder.utils.jars

import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.StandardCopyOption
import java.util.jar.JarFile

open class JarExtractor protected constructor(
  protected var destDir: Path,
) {
  /**
   * @param isDirectory is the target a directory.
   * @param target path the operation will apply to.
   * @return weather the operation should be applied or not.
   */
  internal open fun preWrite(
    isDirectory: Boolean,
    target: Path,
  ): Boolean = true

  protected fun extract(jarFile: Path) {
    JarFile(jarFile.toFile()).use { jar ->
      jar.entries().also { entries ->
        while (entries.hasMoreElements()) {
          (entries.nextElement() as java.util.jar.JarEntry).also { entry ->
            destDir.resolve(entry.name).also { target ->
              if (preWrite(entry.isDirectory, target)) {
                when {
                  entry.isDirectory -> {
                    Files.createDirectories(target)
                  }

                  else -> {
                    jar.getInputStream(entry).use {
                      Files.createDirectories(target.parent)
                      Files.copy(it, target, StandardCopyOption.REPLACE_EXISTING)
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
