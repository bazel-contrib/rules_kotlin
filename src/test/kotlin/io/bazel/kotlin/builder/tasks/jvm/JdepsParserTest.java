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
package io.bazel.kotlin.builder.tasks.jvm;

import static com.google.common.truth.Truth.assertThat;

import com.google.devtools.build.lib.view.proto.Deps;
import com.google.devtools.build.lib.view.proto.Deps.Dependency.Kind;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

import java.io.File;
import java.nio.file.Paths;
import java.util.List;
import java.util.function.Predicate;
import java.util.stream.Collectors;
import java.util.stream.Stream;

@SuppressWarnings({"KotlinInternalInJava", "SpellCheckingInspection"})
@RunWith(JUnit4.class)
public class JdepsParserTest {
  private static final List<String> JDEPS_OUTPUT_FIXTURE =
          toPlatformPaths(
                  "example-tests.jar -> bazel-out/darwin-fastbuild/bin/external/maven/v1/https/repo1.maven.org/maven2/io/ktor/ktor-server-test-host/1.3.1/ktor-server-test-host-1.3.1.jar",
                  "example-tests.jar -> bazel-out/darwin-fastbuild/bin/external/maven/v1/https/repo1.maven.org/maven2/javax/inject/javax.inject/1/processed_javax.inject-1.jar",
                  "example-tests.jar -> /Library/Java/JavaVirtualMachines/jdk1.8.0_152.jdk/Contents/Home/jre/lib/rt.jar",
                  "example-tests.jar -> bazel-out/darwin-fastbuild/bin/root/example/main/example-lib.jar",
                  "example-lib.jar -> bazel-out/darwin-fastbuild/bin/external/maven/v1/https/repo1.maven.org/maven2/javax/inject/javax.inject/1/processed_javax.inject-1.jar",
                  "example-lib.jar -> bazel-out/darwin-fastbuild/bin/external/maven/v1/https/repo1.maven.org/maven2/org/jetbrains/kotlin/kotlin-stdlib-jdk7/1.3.71/kotlin-stdlib-jdk7-1.3.71.jar",
                  "ktor-server-test-host-1.3.1.jar -> bazel-out/darwin-fastbuild/bin/external/maven/v1/https/repo1.maven.org/maven2/io/ktor/ktor-server-host-common/1.3.1/ktor-server-host-common-1.3.1.jar",
                  "ktor-server-test-host-1.3.1.jar -> /Library/Java/JavaVirtualMachines/jdk1.8.0_152.jdk/Contents/Home/jre/lib/rt.jar",
                  "ktor-server-host-common-1.3.1.jar -> /Library/Java/JavaVirtualMachines/jdk1.8.0_152.jdk/Contents/Home/jre/lib/rt.jar",
                  "rt.jar -> /Library/Java/JavaVirtualMachines/jdk1.8.0_152.jdk/Contents/Home/jre/lib/jce.jar",
                  "jce.jar -> /Library/Java/JavaVirtualMachines/jdk1.8.0_152.jdk/Contents/Home/jre/lib/rt.jar"
          );

  private static final List<String> CLASSPATH =
          toPlatformPaths(
                  "bazel-out/darwin-fastbuild/bin/root/example/main/example-lib.jar",
                  "bazel-out/darwin-fastbuild/bin/external/maven/v1/https/repo1.maven.org/maven2/javax/inject/javax.inject/1/processed_javax.inject-1.jar",
                  "bazel-out/darwin-fastbuild/bin/external/maven/v1/https/repo1.maven.org/maven2/io/ktor/ktor-server-host-common/1.3.1/ktor-server-host-common-1.3.1.jar",
                  "bazel-out/darwin-fastbuild/bin/external/maven/v1/https/repo1.maven.org/maven2/io/ktor/ktor-server-test-host/1.3.1/ktor-server-test-host-1.3.1.jar",
                  "bazel-out/darwin-fastbuild/bin/external/maven/v1/https/repo1.maven.org/maven2/javax/inject/javax.inject/1/javax.inject-1.jar",
                  "bazel-out/darwin-fastbuild/bin/external/maven/v1/https/repo1.maven.org/maven2/org/jetbrains/kotlin/kotlin-stdlib-common/1.3.72/kotlin-stdlib-common-1.3.72.jar",
                  "bazel-out/darwin-fastbuild/bin/external/maven/v1/https/repo1.maven.org/maven2/org/jetbrains/kotlin/kotlin-stdlib-jdk7/1.3.71/kotlin-stdlib-jdk7-1.3.71.jar",
                  "bazel-out/darwin-fastbuild/bin/external/maven/v1/https/repo1.maven.org/maven2/org/jetbrains/kotlin/kotlin-stdlib-jdk8/1.3.61/kotlin-stdlib-jdk8-1.3.61.jar",
                  "external/rules_kotlin_maven/lib/annotations-13.0.jar",
                  "external/rules_kotlin_maven/lib/kotlin-reflect.jar",
                  "external/rules_kotlin_maven/lib/kotlin-stdlib-jdk7.jar",
                  "external/rules_kotlin_maven/lib/kotlin-stdlib-jdk8.jar",
                  "external/rules_kotlin_maven/lib/kotlin-stdlib.jar",
                  "external/rules_kotlin_maven/lib/kotlin-test.jar"
          );

  private static final String LABEL = "//cloud/qa/integrationtests/pkg/alt";
  private static final String CLASS_JAR = toPlatformPath("bazel-bin/something/example-tests.jar");

  private static final Predicate<String> IS_KOTLIN_IMPLICIT =
          JdepsParser.Companion.pathSuffixMatchingPredicate(
                  Paths.get("external", "rules_kotlin_maven", "lib"),
                  "kotlin-stdlib.jar",
                  "kotlin-stdlib-jdk7.jar",
                  "kotlin-stdlib-jdk8.jar");

  private static List<String> toPlatformPaths(String... lines) {
    return Stream.of(lines).map(JdepsParserTest::toPlatformPath).collect(Collectors.toList());
  }

  // on windows translate absolute paths to c:\ . Also swap the seperators from "/" to "\".
  private static String toPlatformPath(String it) {
    return File.separatorChar != '/' ? it.replace(" /", "c:\\").replace("/", File.separator) : it;
  }

  private static List<String> depKinds(Deps.Dependencies result, Kind kind) {
    return result
            .getDependencyList()
            .stream()
            .filter(x -> x.getKind() == kind)
            .map(x -> x.getPath())
            .collect(Collectors.toList());
  }

  @Test
  public void parseJdepsResult() {
    Deps.Dependencies result =
            JdepsParser.Companion.parse(LABEL, CLASS_JAR, CLASSPATH,
                JDEPS_OUTPUT_FIXTURE, IS_KOTLIN_IMPLICIT);

    assertThat(result.getRuleLabel()).isEqualTo(LABEL);

    assertThat(result
            .getDependencyList()
            .stream()
            .map(Deps.Dependency::getPath)
            .collect(Collectors.toSet()))
            .containsExactlyElementsIn(CLASSPATH);

    assertThat(depKinds(result, Kind.UNUSED))
        .containsExactly(
          toPlatformPath("bazel-out/darwin-fastbuild/bin/external/maven/v1/https/repo1.maven.org/maven2/org/jetbrains/kotlin/kotlin-stdlib-jdk8/1.3.61/kotlin-stdlib-jdk8-1.3.61.jar"),
          toPlatformPath("external/rules_kotlin_maven/lib/annotations-13.0.jar"),
          toPlatformPath("bazel-out/darwin-fastbuild/bin/external/maven/v1/https/repo1.maven.org/maven2/javax/inject/javax.inject/1/javax.inject-1.jar"),
          toPlatformPath("external/rules_kotlin_maven/lib/kotlin-reflect.jar"),
          toPlatformPath("bazel-out/darwin-fastbuild/bin/external/maven/v1/https/repo1.maven.org/maven2/org/jetbrains/kotlin/kotlin-stdlib-common/1.3.72/kotlin-stdlib-common-1.3.72.jar"),
          toPlatformPath("external/rules_kotlin_maven/lib/kotlin-test.jar")
        );

    assertThat(depKinds(result, Kind.EXPLICIT))
        .containsExactly(
          toPlatformPath("bazel-out/darwin-fastbuild/bin/external/maven/v1/https/repo1.maven.org/maven2/io/ktor/ktor-server-test-host/1.3.1/ktor-server-test-host-1.3.1.jar"),
          toPlatformPath("bazel-out/darwin-fastbuild/bin/root/example/main/example-lib.jar"),
          toPlatformPath("bazel-out/darwin-fastbuild/bin/external/maven/v1/https/repo1.maven.org/maven2/javax/inject/javax.inject/1/processed_javax.inject-1.jar")
        );

    assertThat(depKinds(result, Kind.IMPLICIT))
        .containsExactly(
          toPlatformPath("bazel-out/darwin-fastbuild/bin/external/maven/v1/https/repo1.maven.org/maven2/io/ktor/ktor-server-host-common/1.3.1/ktor-server-host-common-1.3.1.jar"),
          toPlatformPath("bazel-out/darwin-fastbuild/bin/external/maven/v1/https/repo1.maven.org/maven2/org/jetbrains/kotlin/kotlin-stdlib-jdk7/1.3.71/kotlin-stdlib-jdk7-1.3.71.jar"),
          toPlatformPath("external/rules_kotlin_maven/lib/kotlin-stdlib.jar"),
          toPlatformPath("external/rules_kotlin_maven/lib/kotlin-stdlib-jdk7.jar"),
          toPlatformPath("external/rules_kotlin_maven/lib/kotlin-stdlib-jdk8.jar")
        );
  }
}
