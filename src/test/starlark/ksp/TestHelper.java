package io.bazel.kotlin.test.ksp;

/** Simple Java class to trigger javac in mixed-language builds. */
public class TestHelper {
    public static String greet(String name) {
        return "Hello, " + name;
    }
}
