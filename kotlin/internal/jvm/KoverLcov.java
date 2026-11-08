// Copyright 2026 The Bazel Authors. All rights reserved.
// SPDX-License-Identifier: Apache-2.0
package io.bazel.kotlin.coverage;

import java.io.BufferedWriter;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import javax.xml.stream.XMLInputFactory;
import javax.xml.stream.XMLStreamConstants;
import javax.xml.stream.XMLStreamReader;

/** Converts Kover's per-source line counters to an LCOV fragment for Bazel's stock merger. */
public final class KoverLcov {
  public static void main(String[] args) throws Exception {
    Map<String, String> sources = new HashMap<>();
    List<String> paths = Files.readAllLines(Paths.get(args[1]));
    Set<String> manifest = new HashSet<>(Files.readAllLines(Paths.get(args[2])));
    for (int i = 0; i < paths.size(); i += 2) {
      String execPath = paths.get(i);
      if (!manifest.contains(execPath) || !(execPath.endsWith(".kt") || execPath.endsWith(".java"))) {
        continue;
      }
      Path runfile = Paths.get(paths.get(i + 1));
      String key = sourcePackage(runfile) + "/" + runfile.getFileName();
      String previous = sources.putIfAbsent(key, execPath);
      if (previous != null && !previous.equals(execPath)) {
        throw new IllegalArgumentException("Ambiguous Kover source " + key + ": " + previous + " and " + execPath);
      }
    }

    XMLInputFactory factory = XMLInputFactory.newFactory();
    factory.setProperty(XMLInputFactory.SUPPORT_DTD, false);
    factory.setProperty(XMLInputFactory.IS_SUPPORTING_EXTERNAL_ENTITIES, false);
    try (InputStream input = Files.newInputStream(Paths.get(args[0]));
        BufferedWriter output = Files.newBufferedWriter(Paths.get(args[3]))) {
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
              source = sources.get(pkg + "/" + xml.getAttributeValue(null, "name"));
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
        } else if (event == XMLStreamConstants.END_ELEMENT && xml.getLocalName().equals("sourcefile")) {
          if (source != null) {
            output.write("end_of_record\n");
          }
          source = null;
        }
      }
      xml.close();
    }
  }

  // Tokenize the package directive, skipping comments, annotations' string values and Kotlin raw strings.
  private static final Pattern TOKEN = Pattern.compile(
      "//[^\r\n]*|/\\*|\"\"\"(?s:.*?)\"\"\"|\"(?:[^\"\\\\]++|\\\\.)*+\"|'(?:[^'\\\\]++|\\\\.)*+'|"
          + "`[^`\r\n]*`|\\p{javaJavaIdentifierStart}\\p{javaJavaIdentifierPart}*|\\S");
  private static final Pattern COMMENT_MARKER = Pattern.compile("/\\*|\\*/");

  private static String sourcePackage(Path file) throws Exception {
    String text = new String(Files.readAllBytes(file), StandardCharsets.UTF_8);
    Matcher tokens = TOKEN.matcher(text);
    boolean nestedComments = file.toString().endsWith(".kt");
    String token;
    while (!(token = nextToken(tokens, text, nestedComments)).isEmpty()) {
      if (token.equals("import")) {
        return "";
      }
      if (token.equals("package")) {
        StringBuilder pkg = new StringBuilder();
        do {
          token = nextToken(tokens, text, nestedComments);
          if (token.startsWith("`") && token.endsWith("`") && token.length() > 2) {
            token = token.substring(1, token.length() - 1);
          } else if (token.isEmpty() || !Character.isJavaIdentifierStart(token.codePointAt(0))) {
            throw new IllegalArgumentException("Cannot read package declaration in " + file);
          }
          if (pkg.length() > 0) {
            pkg.append('/');
          }
          pkg.append(token);
        } while (nextToken(tokens, text, nestedComments).equals("."));
        return pkg.toString();
      }
    }
    return "";
  }

  private static String nextToken(Matcher tokens, String text, boolean nestedComments) {
    while (tokens.find()) {
      String token = tokens.group();
      if (token.startsWith("//")) {
        continue;
      }
      if (!token.equals("/*")) {
        return token;
      }
      // Kotlin block comments may nest.
      Matcher markers = COMMENT_MARKER.matcher(text).region(tokens.end(), text.length());
      int depth = 1;
      while (depth > 0) {
        if (!markers.find()) {
          throw new IllegalArgumentException("Unclosed source comment");
        }
        if (markers.group().equals("*/")) {
          depth--;
        } else if (nestedComments) {
          depth++;
        }
      }
      tokens.region(markers.end(), text.length());
    }
    return "";
  }
}
