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
package io.bazel.kotlin.builder;

import com.google.auto.value.AutoValue;
import com.google.common.base.Preconditions;
import com.google.common.collect.ImmutableList;
import io.bazel.kotlin.builder.utils.BazelRunFiles;

import javax.annotation.Nullable;
import java.io.File;
import java.util.List;
import java.util.Optional;
import java.util.Properties;
import java.util.Set;
import java.util.stream.Collectors;
import java.util.stream.Stream;

public final class Deps {
    @SuppressWarnings({"WeakerAccess", "unused"})
    @AutoValue
    public abstract static class Dep {
        public static Builder builder() {
            return new AutoValue_Deps_Dep.Builder().runtimeDeps(ImmutableList.of());
        }

        /**
         * Collect all of the compile jars of all the dependencies.
         */
        public static Stream<String> classpathOf(Dep... dependencies) {
            return Stream.of(dependencies).flatMap(it -> it.compileJars().stream());
        }

        /**
         * Import a single dep. Similar to a `kt_jvm_import` or a `kt_js_import`.
         */
        public static Dep importJar(String label, File compileJar) {
            return Dep.builder()
                    .label(label)
                    .compileJars(
                            ImmutableList.of(compileJar.getAbsolutePath()))
                    .build();
        }

        /**
         * Reads dependency path from jvm_args for a given label, provided that the label has been added
         * as a jvm property.
         * <p>
         * See src/test/kotlin/io/bazel/kotlin/defs.bzl for an example of proper label and runfile
         * passing.
         *
         * @param label The label of the resource expected to be included
         * @return Dep representing the resource
         * @throws IllegalArgumentException if the label does not exist.
         */
        public static Dep fromLabel(String label) {
            // jvm properties do not allow slashes or :.
            String key = label.replaceAll("/", ".").replaceAll(":", ".");
            Properties properties = System.getProperties();
            Preconditions.checkArgument(properties.containsKey(key),
                    String.format("Unable to find %s in properties:\n%s", key,
                            properties.keySet()
                                    .stream()
                                    .map(Object::toString)
                                    .collect(Collectors.joining("\n"))));
            return Dep.builder()
                    .label(label)
                    .compileJars(
                            ImmutableList.of(
                                    BazelRunFiles.resolveVerifiedFromProperty(key).getPath()))
                    .build();
        }

        public abstract String label();

        public abstract String moduleName();

        public abstract List<String> runtimeDeps();

        public abstract List<String> compileJars();

        @Nullable
        public abstract String jdeps();

        public final String singleCompileJar() {
            Preconditions.checkState(compileJars().size() == 1);
            return compileJars().get(0);
        }

        @SuppressWarnings("UnusedReturnValue")
        @AutoValue.Builder
        public abstract static class Builder {
            public abstract Builder compileJars(List<String> compileJars);

            public abstract Builder label(String label);

            public abstract Builder runtimeDeps(List<String> runtimeDeps);

            public abstract Builder moduleName(String moduleName);

            abstract String label();

            abstract Optional<String> moduleName();

            abstract Dep autoBuild();

            public abstract Builder jdeps(String jdeps);

            public Dep build() {
                if (!moduleName().isPresent()) {
                    moduleName(label());
                }
                return autoBuild();
            }
        }
    }

    @AutoValue
    public abstract static class AnnotationProcessor {
        public static Builder builder() {
            return new AutoValue_Deps_AnnotationProcessor.Builder();
        }

        abstract String processClass();

        abstract Set<String> processorPath();

        @AutoValue.Builder
        public abstract static class Builder {
            public abstract Builder processClass(String processClass);

            public abstract Builder processorPath(Set<String> processorPath);

            public abstract AnnotationProcessor build();
        }
    }
}
