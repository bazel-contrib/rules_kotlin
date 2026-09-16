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

package io.bazel.kotlin.builder.utils

import java.nio.charset.StandardCharsets
import java.security.MessageDigest

/** Fingerprints jar paths using Bazel-computed input digests in classpath order */
fun fingerprintOf(
  classpath: List<String>,
  inputDigests: Map<String, String>,
): String {
  if (inputDigests.isEmpty()) {
    return ""
  }
  val digest = MessageDigest.getInstance("SHA-256")
  for (path in classpath) {
    val entry = inputDigests[path]
    check(!entry.isNullOrEmpty()) { "no request digest for the classpath entry $path" }
    digest.update(path.toByteArray(StandardCharsets.UTF_8))
    digest.update(0.toByte())
    digest.update(entry.toByteArray(StandardCharsets.UTF_8))
    digest.update(0.toByte())
  }
  return digest.digest().joinToString("") { "%02x".format(it) }
}
