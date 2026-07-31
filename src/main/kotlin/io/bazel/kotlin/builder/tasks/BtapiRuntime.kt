/*
 * Copyright 2026 The Bazel Authors. All rights reserved.
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
package io.bazel.kotlin.builder.tasks

import io.bazel.kotlin.model.KotlinToolchainInfo

/**
 * The complete per-request Build Tools API runtime configuration: the compiler classloader jars
 * (--btapi_impl_classpath, in load order) plus the internal compiler plugin classpaths matching
 * that runtime's dialect (--internal_* worker flags).
 */
data class BtapiRuntime(
  val apiImplClasspath: List<String>,
  val jvmAbiGenClasspath: List<String>,
  val skipCodeGenClasspath: List<String>,
  val kaptClasspath: List<String>,
  val jdepsGenClasspath: List<String>,
)

/** The typed view of the task's toolchain-supplied Build Tools API runtime proto. */
fun KotlinToolchainInfo.BtapiRuntime.toRuntime(): BtapiRuntime =
  BtapiRuntime(
    apiImplClasspath = apiImplClasspathList,
    jvmAbiGenClasspath = jvmAbiGenClasspathList,
    skipCodeGenClasspath = skipCodeGenClasspathList,
    kaptClasspath = kaptClasspathList,
    jdepsGenClasspath = jdepsGenClasspathList,
  )
