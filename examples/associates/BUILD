load("@rules_kotlin//kotlin:core.bzl", "define_kt_toolchain")

# Associates have to keep working with abi jars that had their private (and internal) classes
# stripped, together with strict deps. An associate cannot be listed in deps, so anything it
# contributes to the classpath has to be declared as a direct dependency by the rules themselves.
define_kt_toolchain(
    name = "kotlin_toolchain",
    experimental_remove_private_classes_in_abi_jars = True,
    experimental_report_unused_deps = "error",
    experimental_strict_kotlin_deps = "error",
    experimental_use_abi_jars = True,
)
