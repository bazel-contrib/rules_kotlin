"""Unit tests for `utils.javac_jvm_target_flags` (kotlinc jvm_target -> javac platform flags)."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//kotlin/internal/utils:utils.bzl", "utils")

def _normalization_test_impl(ctx):
    env = unittest.begin(ctx)

    # '1.8'-style targets normalize to '8'; '1.6' -> '6'.
    asserts.equals(env, ["-source", "8", "-target", "8"], utils.javac_jvm_target_flags("1.8"))
    asserts.equals(env, ["-source", "6", "-target", "6"], utils.javac_jvm_target_flags("1.6"))

    # Already-bare numeric targets pass through unchanged.
    asserts.equals(env, ["-source", "8", "-target", "8"], utils.javac_jvm_target_flags("8"))
    asserts.equals(env, ["-source", "11", "-target", "11"], utils.javac_jvm_target_flags("11"))
    asserts.equals(env, ["-source", "17", "-target", "17"], utils.javac_jvm_target_flags("17"))

    return unittest.end(env)

normalization_test = unittest.make(_normalization_test_impl)

def _release_selection_test_impl(ctx):
    env = unittest.begin(ctx)

    # With a compiler version (Build Tools API path): a JDK 9+ compiler differing from the
    # target -> genuine cross-compilation via --release.
    asserts.equals(env, ["--release", "8"], utils.javac_jvm_target_flags("1.8", 17))
    asserts.equals(env, ["--release", "8"], utils.javac_jvm_target_flags("8", 17))
    asserts.equals(env, ["--release", "6"], utils.javac_jvm_target_flags("1.6", 21))
    asserts.equals(env, ["--release", "17"], utils.javac_jvm_target_flags("17", 21))

    # Compiler == target -> -source/-target (no cross-compilation).
    asserts.equals(env, ["-source", "11", "-target", "11"], utils.javac_jvm_target_flags("11", 11))
    asserts.equals(env, ["-source", "17", "-target", "17"], utils.javac_jvm_target_flags("17", 17))

    # Pre-9 running compiler -> -source/-target even when the target differs.
    asserts.equals(env, ["-source", "8", "-target", "8"], utils.javac_jvm_target_flags("1.8", 8))

    return unittest.end(env)

release_selection_test = unittest.make(_release_selection_test_impl)

def javac_jvm_target_test_suite(name):
    unittest.suite(
        name,
        normalization_test,
        release_selection_test,
    )
