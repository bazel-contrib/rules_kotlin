"""Dep-hygiene gate: the kt_jvm_library load graph must exclude @rules_android."""

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

    # Probe kt_jvm_library in a package that doesn't load @rules_android; "manual" excludes it from wildcard builds.
    kt_jvm_library(
        name = probe,
        tags = ["manual"],
    )

    # Captures buildfiles(deps(probe)), the transitive BUILD/.bzl load graph, as a build artifact.
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
            # Guard against a vacuous pass by confirming the graph contains the kt_jvm_library impl.bzl.
            'if ! grep -q "internal/jvm:impl.bzl" "$graph"; then',
            '  echo "FAIL: load graph does not contain the kt_jvm_library definition (kotlin/internal/jvm/impl.bzl); genquery captured the wrong/empty graph" >&2',
            "  exit 1",
            "fi",
            # Matches @rules_android// or @@rules_android+// but not rules_java's android_lint.bzl.
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
