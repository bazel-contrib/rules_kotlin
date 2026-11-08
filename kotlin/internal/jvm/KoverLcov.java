// Copyright 2026 The Bazel Authors. All rights reserved.
// SPDX-License-Identifier: Apache-2.0
package io.bazel.kotlin.coverage;

import java.io.BufferedWriter;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.List;
import javax.xml.stream.XMLInputFactory;
import javax.xml.stream.XMLStreamConstants;
import javax.xml.stream.XMLStreamReader;

/**
 * Converts a Kover XML report to an LCOV fragment for Bazel's coverage merger.
 *
 * <p>Usage: {@code KoverLcov <kover.xml> <coverage manifest> <output.dat>}
 *
 * <p>Source files are matched to the exec paths in Bazel's coverage manifest by
 * {@code package/File.kt} suffix, the same rule Bazel's JaCoCo LCOV formatter uses.
 */
public final class KoverLcov {
  public static void main(String[] args) throws Exception {
    List<String> manifest = Files.readAllLines(Paths.get(args[1]));
    XMLInputFactory factory = XMLInputFactory.newFactory();
    factory.setProperty(XMLInputFactory.SUPPORT_DTD, false);
    factory.setProperty(XMLInputFactory.IS_SUPPORTING_EXTERNAL_ENTITIES, false);
    try (InputStream input = Files.newInputStream(Paths.get(args[0]));
        BufferedWriter output = Files.newBufferedWriter(Paths.get(args[2]))) {
      XMLStreamReader xml = factory.createXMLStreamReader(input);
      String pkg = "";
      String source = null;
      while (xml.hasNext()) {
        int event = xml.next();
        if (event == XMLStreamConstants.START_ELEMENT) {
          switch (xml.getLocalName()) {
            case "package":
              pkg = xml.getAttributeValue(null, "name");
              break;
            case "sourcefile":
              String name = xml.getAttributeValue(null, "name");
              source = execPath(manifest, pkg.isEmpty() ? name : pkg + "/" + name);
              if (source != null) {
                output.write("SF:" + source + "\n");
              }
              break;
            case "line":
              if (source != null) {
                int covered = Integer.parseInt(xml.getAttributeValue(null, "ci"));
                int missed = Integer.parseInt(xml.getAttributeValue(null, "mi"));
                if (covered > 0 || missed > 0) {
                  output.write("DA:" + xml.getAttributeValue(null, "nr") + "," + (covered > 0 ? 1 : 0) + "\n");
                }
              }
              break;
            default:
              break;
          }
        } else if (event == XMLStreamConstants.END_ELEMENT
            && xml.getLocalName().equals("sourcefile")
            && source != null) {
          output.write("end_of_record\n");
          source = null;
        }
      }
      xml.close();
    }
  }

  // Sources whose directory doesn't end in their package path are dropped, as with Bazel's JaCoCo
  // runner. Supporting them would need the builder to emit an explicit source-to-package map.
  private static String execPath(List<String> manifest, String sourcePath) {
    for (String execPath : manifest) {
      if (execPath.equals(sourcePath) || execPath.endsWith("/" + sourcePath)) {
        return execPath;
      }
    }
    return null;
  }
}
