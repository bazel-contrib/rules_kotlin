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

package io.bazel.kotlin.builder.tasks.jvm

import io.bazel.kotlin.builder.toolchain.KotlinToolchain
import java.io.ByteArrayOutputStream
import java.io.ObjectOutputStream
import java.nio.file.FileSystem
import java.nio.file.FileSystems
import java.nio.file.Path
import java.util.Base64

/**
 * CompilationArgs collects the arguments for executing the Kotlin compiler.
 */
class CompilationArgs(
  val args: MutableList<String> = mutableListOf(),
  private val dfs: FileSystem = FileSystems.getDefault(),
) {
  class StringConditional(
    val value: String,
    val parent: CompilationArgs,
  ) {
    fun notEmpty(conditionalArgs: CompilationArgs.(it: String) -> Unit): CompilationArgs {
      if (value.isNotEmpty()) {
        parent.conditionalArgs(value)
      }
      return parent
    }
  }

  interface SetFlag {
    fun flag(
      name: String,
      value: String,
    ): SetFlag
  }

  fun plugin(
    p: KotlinToolchain.CompilerPlugin,
    flagArgs: SetFlag.() -> Unit,
  ): CompilationArgs {
    value("-Xplugin=${p.jarPath}")
    object : SetFlag {
      override fun flag(
        name: String,
        value: String,
      ): SetFlag {
        args.add("-P")
        args.add("plugin:${p.id}:$name=$value")
        return this
      }
    }.flagArgs()
    return this
  }

  fun given(value: String): StringConditional = StringConditional(value, this)

  operator fun plus(other: CompilationArgs): CompilationArgs =
    CompilationArgs(
      (args.asSequence() + other.args.asSequence()).toMutableList(),
    )

  fun absolutePaths(
    paths: Collection<String>,
    toArgs: (Sequence<Path>) -> String,
  ): CompilationArgs {
    if (paths.isEmpty()) {
      return this
    }
    return value(
      toArgs(
        paths
          .asSequence()
          .map { dfs.getPath(it) }
          .map(Path::toAbsolutePath),
      ),
    )
  }

  fun paths(
    paths: Collection<String>,
    toArgs: (Sequence<Path>) -> String,
  ): CompilationArgs {
    if (paths.isEmpty()) {
      return this
    }
    return value(
      toArgs(
        paths
          .asSequence()
          .map { dfs.getPath(it) },
      ),
    )
  }

  fun value(value: String): CompilationArgs {
    args.add(value)
    return this
  }

  fun append(compilationArgs: CompilationArgs): CompilationArgs {
    args.addAll(compilationArgs.args)
    return this
  }

  fun flag(value: String): CompilationArgs {
    args.add(value)
    return this
  }

  fun flag(
    key: String,
    value: () -> String,
  ): CompilationArgs {
    args.add(key)
    args.add(value())
    return this
  }

  fun flag(
    flag: String,
    value: String,
  ): CompilationArgs {
    args.add(flag)
    args.add(value)
    return this
  }

  fun values(values: Collection<String>): CompilationArgs {
    args.addAll(values)
    return this
  }

  fun xFlag(
    flag: String,
    value: String,
  ): CompilationArgs {
    args.add("-X$flag=$value")
    return this
  }

  fun repeatFlag(
    flag: String,
    vararg flagValues: Pair<String, List<String>>,
    transform: (option: String, value: String) -> String,
  ): CompilationArgs {
    flagValues.forEach { (option, optionValues) ->
      optionValues.forEach {
        flag(flag, transform(option, it))
      }
    }
    return this
  }

  fun list(): List<String> = args.toList()

  fun base64Encode(
    flag: String,
    vararg values: Pair<String, List<String>>,
    transform: (String) -> String = { it },
  ): CompilationArgs {
    val os = ByteArrayOutputStream()
    val oos = ObjectOutputStream(os)

    oos.writeInt(values.size)
    for ((k, vs) in values) {
      oos.writeUTF(k)

      if (vs.size == 1) {
        oos.writeUTF(vs[0])
      } else {
        oos.writeInt(vs.size)
        for (v in vs) {
          oos.writeUTF(v)
        }
      }
    }

    oos.flush()
    flag(flag, transform(Base64.getEncoder().encodeToString(os.toByteArray())))
    return this
  }
}
