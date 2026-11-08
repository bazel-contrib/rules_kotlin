// Copyright 2026 The Bazel Authors. All rights reserved.
// SPDX-License-Identifier: Apache-2.0
package io.bazel.kotlin.coverage;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertThrows;

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
    Files.createDirectories(file.getParent());
    Files.write(file, text.getBytes(StandardCharsets.UTF_8));
    return file;
  }

  private String convert(String secondPackage) throws Exception {
    Path a = write("left/Same.kt", "/* /* inner */ package wrong\n*/\npackage demo.first\n");
    Path b = write("right/Same.kt", "@file:Suppress(\"package fake\")\npackage " + secondPackage + "\n");
    String original = "src/left/Same.kt";
    String generated = "bazel-out/config/bin/right/Same.kt";
    Path manifest = write("manifest", original + "\n" + generated + "\n");
    Path map = write("map", original + "\n" + a + "\n" + generated + "\n" + b + "\n"
        + "excluded/Same.kt\nmissing-runfile\n");
    Path xml = write("coverage.xml", "<report><package name=\"demo/first\"><sourcefile name=\"Same.kt\">"
        + "<line nr=\"7\" mi=\"0\" ci=\"6\"/></sourcefile></package>"
        + "<package name=\"demo/second\"><sourcefile name=\"Same.kt\">"
        + "<line nr=\"9\" mi=\"4\" ci=\"0\"/></sourcefile></package></report>");
    Path output = tmp.getRoot().toPath().resolve("kover.dat");
    KoverLcov.main(new String[] {xml.toString(), map.toString(), manifest.toString(), output.toString()});
    return new String(Files.readAllBytes(output), StandardCharsets.UTF_8);
  }

  @Test
  public void usesExactManifestPathsAndBinaryLineCounts() throws Exception {
    assertEquals("SF:src/left/Same.kt\nDA:7,1\nend_of_record\n"
        + "SF:bazel-out/config/bin/right/Same.kt\nDA:9,0\nend_of_record\n",
        convert("demo.second"));
  }

  @Test
  public void rejectsAmbiguousSourceIdentity() {
    assertThrows(IllegalArgumentException.class, () -> convert("demo.first"));
  }
}
