load("@bazel_skylib//lib:dicts.bzl", "dicts")
load(
    "//kotlin/internal:defs.bzl",
    _TOOLCHAIN_TYPE = "TOOLCHAIN_TYPE",
)

# TODO unexport this once init builder args can take care of associates.
def _derive_module_name(ctx):
    """Gets the `module_name` attribute if it's set in the ctx, otherwise derive a unique module name using the elements
    found in the label."""
    module_name = getattr(ctx.attr, "module_name", "")
    if module_name == "":
        package = ctx.label.package.lstrip("/").replace("/", "_")
        name = ctx.label.name.replace("/", "_")

        # Only add separator if package is not empty to avoid leading dash
        if package:
            module_name = package + "-" + name
        else:
            module_name = name
    return module_name

def _init_builder_args(ctx, rule_kind, module_name, kotlinc_options = None):
    """Initialize an arg object for a task that will be executed by the Kotlin Builder."""
    toolchain = ctx.toolchains[_TOOLCHAIN_TYPE]

    args = ctx.actions.args()
    args.set_param_file_format("multiline")
    args.use_param_file("--flagfile=%s", use_always = True)

    args.add("--target_label", ctx.label)
    args.add("--rule_kind", rule_kind)
    args.add("--kotlin_module_name", module_name)

    kotlin_jvm_target = kotlinc_options.jvm_target if (kotlinc_options and kotlinc_options.jvm_target) else toolchain.jvm_target
    args.add("--kotlin_jvm_target", kotlin_jvm_target)
    args.add("--kotlin_api_version", toolchain.api_version)
    args.add("--kotlin_language_version", toolchain.language_version)

    debug = toolchain.debug
    for tag in ctx.attr.tags:
        if tag == "trace":
            debug = debug + [tag]
        if tag == "timings":
            debug = debug + [tag]
    args.add_all("--kotlin_debug_tags", debug, omit_if_empty = False)

    return args

def _javac_jvm_target_flags(jvm_target):
    """Derive javac `-source`/`-target` flags from a kotlinc `jvm_target`.
    """
    stripped = jvm_target.strip()
    dot = stripped.rfind(".")
    target_version = stripped if dot < 0 else stripped[dot + 1:]
    if not target_version.isdigit():
        fail("kotlinc jvm_target '{}' is not a valid JVM target version (expected a number like '8', '11', '17', or the legacy '1.8' form)".format(jvm_target))
    return ["-source", target_version, "-target", target_version]

utils = struct(
    add_dicts = dicts.add,
    init_args = _init_builder_args,
    derive_module_name = _derive_module_name,
    javac_jvm_target_flags = _javac_jvm_target_flags,
)
