package io.bazel.kotlin.builder.toolchain

import java.nio.file.Path

data class ToolchainSpec(
  val btapiClasspath: List<Path>,
  val jdepsJar: Path,
  val abiGenJar: Path,
  val skipCodeGenJar: Path,
  val kaptJar: Path,
)
