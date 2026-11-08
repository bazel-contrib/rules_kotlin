// Copyright 2026 The Bazel Authors. All rights reserved.
// SPDX-License-Identifier: Apache-2.0
package io.bazel.kotlin.coverage;

import static org.junit.Assert.assertEquals;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.TemporaryFolder;

public class KoverLcovTest {
  @Rule public TemporaryFolder tmp = new TemporaryFolder();

  private Path write(String name, String text) throws Exception {
    Path file = tmp.getRoot().toPath().resolve(name);
    Files.write(file, text.getBytes(StandardCharsets.UTF_8));
    return file;
  }

  @Test
  public void mapsSourcesToManifestExecPaths() throws Exception {
    Path manifest = write("manifest",
        "src/demo/first/Same.kt\nbazel-out/cfg/bin/gen/demo/second/Same.kt\nTop.kt\nsrc/flat/Other.kt\n");
    Path xml = write("coverage.xml", "<report>"
        + "<package name=\"demo/first\"><sourcefile name=\"Same.kt\">"
        + "<line nr=\"7\" mi=\"0\" ci=\"6\"/><line nr=\"8\" mi=\"0\" ci=\"0\"/></sourcefile></package>"
        + "<package name=\"demo/second\"><sourcefile name=\"Same.kt\">"
        + "<line nr=\"9\" mi=\"4\" ci=\"0\"/></sourcefile></package>"
        + "<package name=\"\"><sourcefile name=\"Top.kt\"><line nr=\"1\" mi=\"0\" ci=\"1\"/></sourcefile></package>"
        // Not in the manifest (uninstrumented dependency or package/directory mismatch): dropped.
        + "<package name=\"org/junit\"><sourcefile name=\"Assert.java\"><line nr=\"1\" mi=\"1\" ci=\"0\"/></sourcefile></package>"
        + "<package name=\"com/flat\"><sourcefile name=\"Other.kt\"><line nr=\"1\" mi=\"1\" ci=\"0\"/></sourcefile></package>"
        + "</report>");
    Path output = tmp.getRoot().toPath().resolve("kover.dat");
    KoverLcov.main(new String[] {xml.toString(), manifest.toString(), output.toString()});
    assertEquals(
        "SF:src/demo/first/Same.kt\nDA:7,1\nend_of_record\n"
            + "SF:bazel-out/cfg/bin/gen/demo/second/Same.kt\nDA:9,0\nend_of_record\n"
            + "SF:Top.kt\nDA:1,1\nend_of_record\n",
        new String(Files.readAllBytes(output), StandardCharsets.UTF_8));
  }
}
