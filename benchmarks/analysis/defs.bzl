"""Analysis-only scale fixtures; the fake jars are never executed."""

load("//kotlin:jvm.bzl", "kt_jvm_import", "kt_jvm_library")

def analysis_graphs():
    """Generate shared-classpath and layered Kotlin dependency graphs."""
    native.genrule(
        name = "jars",
        outs = ["jar_%d.jar" % i for i in range(1000)],
        cmd = "touch $(OUTS)",
        tags = ["manual"],
    )
    for i in range(1000):
        kt_jvm_import(name = "import_%d" % i, jars = ["jar_%d.jar" % i], tags = ["manual"])
    kt_jvm_library(
        name = "shared",
        exports = [":import_%d" % i for i in range(1000)],
        tags = ["manual"],
    )
    for i in range(600):
        kt_jvm_library(name = "wide_%d" % i, srcs = ["Bench.kt"], deps = [":shared"], tags = ["manual"])
    native.filegroup(name = "wide", srcs = [":wide_%d" % i for i in range(600)], tags = ["manual"])
    for level in range(100):
        for column in range(12):
            deps = [] if level == 0 else [":layer_%d_%d" % (level - 1, c) for c in [column, (column + 1) % 12]]
            kt_jvm_library(name = "layer_%d_%d" % (level, column), srcs = ["Bench.kt"], deps = deps, tags = ["manual"])
    native.filegroup(name = "layered", srcs = [":layer_99_%d" % i for i in range(12)], tags = ["manual"])

    for i in range(300):
        kt_jvm_library(
            name = "fanin_%d" % i,
            srcs = ["Bench.kt"],
            deps = [":import_%d" % j for j in range(1000)],
            tags = ["manual"],
        )
    native.filegroup(name = "fanin", srcs = [":fanin_%d" % i for i in range(300)], tags = ["manual"])
