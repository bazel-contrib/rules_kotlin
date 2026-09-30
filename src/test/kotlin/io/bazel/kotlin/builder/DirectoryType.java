package io.bazel.kotlin.builder;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.EnumSet;

public enum DirectoryType {
    SOURCES("sources", Paths.get("sources")),
    CLASSES("compiled classes", Paths.get("classes")),
    JAVA_CLASSES("compiled classes", Paths.get("java_classes")),
    ABI_CLASSES("compiled classes", Paths.get("abi_classes")),
    GENERATED_CLASSES("generated classes", Paths.get("generated_classes")),
    TEMP("temp directory", Paths.get("temp")),
    SOURCE_GEN("generated sources directory", Paths.get("generated_sources")),
    JAVA_SOURCE_GEN("generated sources directory", Paths.get("generated_java_sources")),
    INCREMENTAL_DATA("generated kotlin stubs class directory", Paths.get("temp", "incrementalData")),
    COVERAGE_METADATA("generated kotlin stubs class directory", Paths.get("temp", "coverage-metadata"));

    final String name;
    final Path relativePath;

    DirectoryType(String name, Path relativePath) {
        this.name = name;
        this.relativePath = relativePath;
    }

    static void createAll(Path root, EnumSet<DirectoryType> types) {
        for (DirectoryType instanceType : types) {
            try {
                Files.createDirectory(instanceType.resolve(root));
            } catch (IOException e) {
                throw new UncheckedIOException(instanceType.name, e);
            }
        }
    }

    Path resolve(Path root) {
        return root.resolve(relativePath);
    }
}
