"""Dep-hygiene gate: the kt_jvm_library load graph must exclude @rules_android.

Locks design criterion 5 (rejected option A): pure `kt_jvm_*` users must NOT
transitively load `@rules_android` at analysis time. The vendored pipeline runner
(//src/main/starlark/core/pipeline:pipeline.bzl) exists precisely so that the JVM
rule shells never pull `@rules_android//rules:processing_pipeline.bzl` into the
pure-JVM load graph.

Mechanism: a plain `kt_jvm_library` probe lives in THIS package, whose BUILD file
does NOT load `@rules_android` (unlike the fixtures package, which co-locates an
android target and therefore contaminates its own buildfiles graph). A `genquery`
captures `buildfiles(deps(<probe>))` -- the transitive BUILD/.bzl load graph of the
kt_jvm_library rule definition -- as a build artifact, and an `sh_test` asserts the
literal `rules_android` never appears in it. If a future edit reintroduces an
`@rules_android` load into the kt_jvm_library definition, this test goes red.

Note: the substring is `rules_android` (not `android`) so the benign
`@rules_java//...:android_lint.bzl` from rules_java is NOT a false positive.
"""

load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@rules_shell//shell:sh_test.bzl", "sh_test")
load("//kotlin:jvm.bzl", "kt_jvm_library")

def dep_hygiene_test_suite(name):
    """Wire the kt_jvm_library @rules_android dep-hygiene gate.

    Args:
      name: the sh_test target name (the gate). Supporting probe/genquery/script
        targets are derived with `name`-prefixed suffixes.
    """
    probe = name + "_probe"

    # Pure kt_jvm_library in a package that does NOT load @rules_android, so its
    # buildfiles graph reflects ONLY the kt_jvm_library rule definition. Export-only
    # (no srcs) keeps it analysis-cheap; "manual" keeps it out of the wildcard run.
    kt_jvm_library(
        name = probe,
        tags = ["manual"],
    )

    # buildfiles(deps(probe)) = the transitive BUILD + .bzl load graph of the
    # kt_jvm_library definition, captured as a build artifact (no recursive bazel).
    native.genquery(
        name = name + "_loadgraph",
        expression = "buildfiles(deps(//%s:%s))" % (native.package_name(), probe),
        scope = ["//%s:%s" % (native.package_name(), probe)],
    )

    write_file(
        name = name + "_assert_script",
        out = name + "_assert_no_rules_android.sh",
        content = [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            'graph="$1"',
            # Guard against a vacuous pass: the captured graph must actually be the
            # kt_jvm_library load graph, i.e. contain the rule-defining impl.bzl. If it
            # is empty or points at the wrong target the grep below would pass for the
            # wrong reason.
            'if ! grep -q "internal/jvm:impl.bzl" "$graph"; then',
            '  echo "FAIL: load graph does not contain the kt_jvm_library definition (kotlin/internal/jvm/impl.bzl); genquery captured the wrong/empty graph" >&2',
            "  exit 1",
            "fi",
            # Match the canonical repo token in either @rules_android// or
            # @@rules_android+// form; rules_java's android_lint.bzl does NOT match.
            'if grep -q "rules_android" "$graph"; then',
            '  echo "FAIL: @rules_android present in the kt_jvm_library load graph:" >&2',
            '  grep "rules_android" "$graph" >&2',
            "  exit 1",
            "fi",
            'echo "OK: no @rules_android in kt_jvm_library load graph ($(grep -c . "$graph") buildfiles)"',
            "",
        ],
        is_executable = True,
    )

    sh_test(
        name = name,
        srcs = [name + "_assert_script"],
        args = ["$(location :%s_loadgraph)" % name],
        data = [":" + name + "_loadgraph"],
    )
