# Copyright 2022 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

load("//src/main/starlark/core/options:convert.bzl", "convert")
load("//src/main/starlark/core/options:derive.bzl", "derive")
load(
    "//src/main/starlark/core/repositories/kotlin:capabilities_2.3.bzl",
    _KOTLIN_OPTS = "KOTLIN_OPTS",
)

_ALLOWED_SUPPRESS_LEVELS = [
    "error",
    "warning",
    "disabled",
]

_ALLOWED_NULLABILITY_MODES = [
    "ignore",
    "warn",
    "strict",
]

def _map_warning_level(values):
    if not values:
        return None

    args = []
    for k, v in values.items():
        if v not in _ALLOWED_SUPPRESS_LEVELS:
            fail("Error: Suppress key '{}' has an invalid value of '{}'".format(k, v))
        args.append("-Xwarning-level={}:{}".format(k, v))
    return args

def _map_nullability_annotations(values):
    if not values:
        return None

    args = []
    for annotation, mode in values.items():
        if mode not in _ALLOWED_NULLABILITY_MODES:
            fail("Error: Nullability annotation '{}' has an invalid mode '{}'. Must be one of: {}".format(
                annotation,
                mode,
                _ALLOWED_NULLABILITY_MODES,
            ))
        args.append("-Xnullability-annotations={}:{}".format(annotation, mode))
    return args

def _map_optin_class_to_flag(values):
    return ["-opt-in=%s" % v for v in values]

def _map_backend_threads_to_flag(n):
    if n == 1:
        return None
    return ["-Xbackend-threads=%d" % n]

def _map_jvm_target_to_flag(version):
    if not version:
        return None
    return ["-jvm-target=%s" % version]

def _map_jdk_release_to_flag(version):
    if not version:
        return None
    return ["-Xjdk-release=%s" % version]

_KOPTS_ALL = {
    "include_stdlibs": struct(
        args = dict(
            default = "all",
            doc = "Don't automatically include the Kotlin standard libraries into the classpath (stdlib and reflect).",
            values = ["all", "stdlib", "none"],
        ),
        type = attr.string,
        value_to_flag = {
            "all": None,
            "none": ["-no-stdlib"],
            "stdlib": ["-no-reflect"],
        },
    ),
    "java_parameters": struct(
        args = dict(
            default = False,
            doc = "Generate metadata for Java 1.8+ reflection on method parameters.",
        ),
        type = attr.bool,
        value_to_flag = {
            True: ["-java-parameters"],
        },
    ),
    "jvm_default": struct(
        flag = "-jvm-default",
        args = dict(
            default = "off",
            doc = """Specifies how to generate JVM default methods for interface declarations with bodies.
This is the stable replacement for x_jvm_default (-Xjvm-default). Available from Kotlin 2.2.
Options:
- 'off': Don't pass the flag (uses compiler default, which is 'enable' in Kotlin 2.2+).
- 'enable': Generate default methods and DefaultImpls for compatibility.
- 'no-compatibility': Generate default methods without DefaultImpls classes.
- 'disable': Do not generate JVM default methods (was the default up to Kotlin 2.1).""",
            values = ["off", "enable", "no-compatibility", "disable"],
        ),
        type = attr.string,
        value_to_flag = {
            "disable": ["-jvm-default=disable"],
            "enable": ["-jvm-default=enable"],
            "no-compatibility": ["-jvm-default=no-compatibility"],
            "off": None,
        },
    ),
    "jvm_target": struct(
        args = dict(
            default = "",
            doc = "The target version of the generated JVM bytecode",
            values = ["1.6", "1.8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "25"],
        ),
        type = attr.string,
        value_to_flag = None,
        map_value_to_flag = _map_jvm_target_to_flag,
    ),
    "warn": struct(
        args = dict(
            default = "report",
            doc = "Control warning behaviour.",
            values = ["off", "report", "error"],
        ),
        type = attr.string,
        value_to_flag = {
            "error": ["-Werror"],
            "off": ["-nowarn"],
            "report": None,
        },
    ),
    "x_allow_result_return_type": struct(
        flag = "-Xallow-result-return-type",
        args = dict(
            default = False,
            doc = "Enable kotlin.Result as a return type",
        ),
        type = attr.bool,
        value_to_flag = {
            True: ["-Xallow-result-return-type"],
        },
    ),
    "x_annotation_default_target": struct(
        args = dict(
            default = "off",
            doc = """Change the default annotation targets for constructor properties:
-Xannotation-default-target=first-only: use the first of the following allowed targets: '@param:', '@property:', '@field:';
-Xannotation-default-target=first-only-warn: same as first-only, and raise warnings when both '@param:' and either '@property:' or '@field:' are allowed;
-Xannotation-default-target=param-property: use '@param:' target if applicable, and also use the first of either '@property:' or '@field:';
default: 'first-only-warn' in language version 2.2+, 'first-only' in version 2.1 and before.""",
            values = ["off", "first-only", "first-only-warn", "param-property"],
        ),
        type = attr.string,
        value_to_flag = {
            "first-only": ["-Xannotation-default-target=first-only"],
            "first-only-warn": ["-Xannotation-default-target=first-only-warn"],
            "off": None,
            "param-property": ["-Xannotation-default-target=param-property"],
        },
    ),
    "x_assertions": struct(
        args = dict(
            default = "",
            doc = "Configures how assertions are handled. The 'jvm' option enables assertions in JVM code.",
            values = ["jvm"],
        ),
        type = attr.string,
        value_to_flag = {
            "default": None,
            "jvm": ["-Xassertions=jvm"],
        },
        map_value_to_flag = None,
    ),
    "x_backend_threads": struct(
        # 1.6.20, 1.7
        flag = "-Xbackend-threads",
        args = dict(
            default = 1,
            doc = "When using the IR backend, run lowerings by file in N parallel threads. 0 means use a thread per processor core. Default value is 1.",
        ),
        type = attr.int,
        value_to_flag = None,
        map_value_to_flag = _map_backend_threads_to_flag,
    ),
    "x_consistent_data_class_copy_visibility": struct(
        args = dict(
            default = False,
            doc = "The effect of this compiler flag is the same as applying @ConsistentCopyVisibility annotation to all data classes in the module. See https://youtrack.jetbrains.com/issue/KT-11914",
        ),
        type = attr.bool,
        value_to_flag = {
            True: ["-Xconsistent-data-class-copy-visibility"],
        },
    ),
    "x_context_parameters": struct(
        flag = "-Xcontext-parameters",
        args = dict(
            default = False,
            doc = "Enable experimental context parameters (Kotlin 2.2+).",
        ),
        type = attr.bool,
        value_to_flag = {
            True: ["-Xcontext-parameters"],
        },
    ),
    "x_context_receivers": struct(
        flag = "-Xcontext-receivers",
        args = dict(
            default = False,
            doc = "Enable experimental context receivers.",
        ),
        type = attr.bool,
        value_to_flag = {
            True: ["-Xcontext-receivers"],
        },
    ),
    "x_emit_jvm_type_annotations": struct(
        flag = "-Xemit-jvm-type-annotations",
        args = dict(
            default = False,
            doc = "Basic support for type annotations in JVM bytecode.",
        ),
        type = attr.bool,
        value_to_flag = {
            True: ["-Xemit-jvm-type-annotations"],
        },
    ),
    "x_enable_incremental_compilation": struct(
        args = dict(
            default = False,
            doc = "Enable incremental compilation",
        ),
        type = attr.bool,
        value_to_flag = {
            True: ["-Xenable-incremental-compilation"],
        },
    ),
    "x_explicit_api_mode": struct(
        flag = "-Xexplicit-api",
        args = dict(
            default = "off",
            doc = "Enable explicit API mode for Kotlin libraries.",
            values = ["off", "warning", "strict"],
        ),
        type = attr.string,
        value_to_flag = {
            "off": None,
            "strict": ["-Xexplicit-api=strict"],
            "warning": ["-Xexplicit-api=warning"],
        },
    ),
    "x_inline_classes": struct(
        flag = "-Xinline-classes",
        args = dict(
            default = False,
            doc = "Enable experimental inline classes",
        ),
        type = attr.bool,
        value_to_flag = {
            True: ["-Xinline-classes"],
        },
    ),
    "x_jdk_release": struct(
        args = dict(
            default = "",
            doc = """Compile against the specified JDK API version, similarly to javac's '-release'. This requires JDK 9 or newer.
                     The supported versions depend on the JDK used; for JDK 25+, the supported versions are 1.8 and 9-25.
                     This also sets the value of '-jvm-target' to be equal to the selected JDK version.""",
            values = ["1.6", "1.8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "25"],
        ),
        type = attr.string,
        value_to_flag = None,
        map_value_to_flag = _map_jdk_release_to_flag,
    ),
    "x_jspecify_annotations": struct(
        args = dict(
            default = "",
            doc = "Controls how JSpecify annotations are treated. Options are 'default', 'ignore', 'warn', and 'strict'.",
            values = ["default", "ignore", "warn", "strict"],
        ),
        type = attr.string,
        value_to_flag = {
            "default": None,
            "ignore": ["-Xjspecify-annotations=ignore"],
            "strict": ["-Xjspecify-annotations=strict"],
            "warn": ["-Xjspecify-annotations=warn"],
        },
        map_value_to_flag = None,
    ),
    "x_jsr_305": struct(
        args = dict(
            default = "",
            doc = "Specifies how to handle JSR-305 annotations in Kotlin code. Options are 'default', 'ignore', 'warn', and 'strict'.",
            values = ["default", "ignore", "warn", "strict"],
        ),
        type = attr.string,
        value_to_flag = {
            "default": None,
            "ignore": ["-Xjsr305=ignore"],
            "strict": ["-Xjsr305=strict"],
            "warn": ["-Xjsr305=warn"],
        },
        map_value_to_flag = None,
    ),
    "x_jvm_default": struct(
        flag = "-Xjvm-default",
        args = dict(
            default = "off",
            doc = """DEPRECATED: Use jvm_default instead for Kotlin 2.2+.
Specifies that a JVM default method should be generated for non-abstract Kotlin interface member.
Migration to jvm_default:
- x_jvm_default=all -> jvm_default=no-compatibility
- x_jvm_default=all-compatibility -> jvm_default=enable
- x_jvm_default=disable -> jvm_default=disable""",
            values = ["off", "enable", "disable", "compatibility", "all-compatibility", "all"],
        ),
        type = attr.string,
        value_to_flag = {
            "all": ["-Xjvm-default=all"],
            "all-compatibility": ["-Xjvm-default=all-compatibility"],
            "compatibility": ["-Xjvm-default=compatibility"],
            "disable": ["-Xjvm-default=disable"],
            "enable": ["-Xjvm-default=enable"],
            "off": None,
        },
    ),
    "x_lambdas": struct(
        flag = "-Xlambdas",
        args = dict(
            default = "class",
            doc = """Change codegen behavior of lambdas. Defaults to "class" (anonymous inner classes), which differs from Kotlin 2.x/Gradle default of "indy" (invokedynamic). Set to "indy" for Gradle-compatible bytecode.""",
            values = ["class", "indy"],
        ),
        type = attr.string,
        value_to_flag = {
            "class": ["-Xlambdas=class"],
            "indy": ["-Xlambdas=indy"],
        },
    ),
    "x_multi_platform": struct(
        flag = "-Xmulti-platform",
        args = dict(
            default = False,
            doc = "Enable experimental language support for multi-platform projects",
        ),
        type = attr.bool,
        value_to_flag = {
            True: ["-Xmulti-platform"],
        },
    ),
    "x_no_call_assertions": struct(
        flag = "-Xno-call-assertions",
        args = dict(
            default = False,
            doc = "Don't generate not-null assertions for arguments of platform types",
        ),
        type = attr.bool,
        value_to_flag = {
            True: ["-Xno-call-assertions"],
        },
    ),
    "x_no_optimize": struct(
        flag = "-Xno-optimize",
        args = dict(
            default = False,
            doc = "Disable optimizations",
        ),
        type = attr.bool,
        value_to_flag = {
            True: ["-Xno-optimize"],
        },
    ),
    "x_no_optimized_callable_references": struct(
        flag = "-Xno-optimized-callable-references",
        args = dict(
            default = False,
            doc = "Do not use optimized callable reference superclasses. Available from 1.4.",
        ),
        type = attr.bool,
        value_to_flag = {
            True: ["-Xno-optimized-callable-references"],
        },
    ),
    "x_no_param_assertions": struct(
        flag = "-Xno-param-assertions",
        args = dict(
            default = False,
            doc = "Don't generate not-null assertions on parameters of methods accessible from Java",
        ),
        type = attr.bool,
        value_to_flag = {
            True: ["-Xno-param-assertions"],
        },
    ),
    "x_no_receiver_assertions": struct(
        flag = "-Xno-receiver-assertions",
        args = dict(
            default = False,
            doc = "Don't generate not-null assertion for extension receiver arguments of platform types",
        ),
        type = attr.bool,
        value_to_flag = {
            True: ["-Xno-receiver-assertions"],
        },
    ),
    "x_no_source_debug_extension": struct(
        args = dict(
            default = False,
            doc = "Do not generate @kotlin.jvm.internal.SourceDebugExtension annotation on a class with the copy of SMAP",
        ),
        type = attr.bool,
        value_to_flag = {
            True: ["-Xno-source-debug-extension"],
        },
    ),
    "x_nullability_annotations": struct(
        args = dict(
            default = {},
            doc = "Configure how Kotlin treats nullability annotations on Java types, per annotation class. " +
                  "Map the fully-qualified annotation class name (prefixed with '@') to a mode: " +
                  "'ignore', 'warn', or 'strict'. " +
                  "Ex: {'@jakarta.annotation.Nullable': 'strict', '@jakarta.annotation.Nonnull': 'strict'}. " +
                  "Use x_jsr305 for javax.annotation (JSR-305) and x_jspecify_annotations for org.jspecify.",
        ),
        type = attr.string_dict,
        value_to_flag = None,
        map_value_to_flag = _map_nullability_annotations,
    ),
    "x_optin": struct(
        args = dict(
            default = [],
            doc = "Define APIs to opt-in to.",
        ),
        type = attr.string_list,
        value_to_flag = None,
        map_value_to_flag = _map_optin_class_to_flag,
    ),
    "x_report_perf": struct(
        flag = "-Xreport-perf",
        args = dict(
            default = False,
            doc = "Report detailed performance statistics",
        ),
        type = attr.bool,
        value_to_flag = {
            True: ["-Xreport-perf"],
        },
    ),
    "x_sam_conversions": struct(
        flag = "-Xsam-conversions",
        args = dict(
            default = "class",
            doc = """Change codegen behavior of SAM/functional interfaces. Defaults to "class" (anonymous inner classes), which differs from Kotlin 2.x/Gradle default of "indy" (invokedynamic). Set to "indy" for Gradle-compatible bytecode.""",
            values = ["class", "indy"],
        ),
        type = attr.string,
        value_to_flag = {
            "class": ["-Xsam-conversions=class"],
            "indy": ["-Xsam-conversions=indy"],
        },
    ),
    "x_skip_prerelease_check": struct(
        flag = "-Xskip-prerelease-check",
        args = dict(
            default = False,
            doc = "Suppress errors thrown when using pre-release classes.",
        ),
        type = attr.bool,
        value_to_flag = {
            True: ["-Xskip-prerelease-check"],
        },
    ),
    "x_suppress_version_warnings": struct(
        flag = "-Xsuppress-version-warnings",
        args = dict(
            default = False,
            doc = "Suppress warnings about outdated, inconsistent, or experimental language or API versions.",
        ),
        type = attr.bool,
        value_to_flag = {
            True: ["-Xsuppress-version-warnings"],
        },
    ),
    "x_suppress_warning": struct(
        args = dict(
            default = [],
            doc = "Suppress specific warnings globally",
        ),
        type = attr.string_list,
        value_to_flag = {
            derive.info: derive.repeated_values_for("-Xsuppress-warning="),
        },
    ),
    "x_type_enhancement_improvements_strict_mode": struct(
        args = dict(
            default = False,
            doc = "Enables strict mode for type enhancement improvements, enforcing stricter type checking and enhancements.",
        ),
        type = attr.bool,
        value_to_flag = {
            True: ["-Xtype-enhancement-improvements-strict-mode"],
        },
    ),
    "x_use_fir": struct(
        # 1.6
        flag = "-Xuse-fir",
        args = dict(
            default = False,
            doc = "Compile using the experimental Kotlin Front-end IR. Available from 1.6.",
        ),
        type = attr.bool,
        value_to_flag = {
            True: ["-Xuse-fir"],
        },
    ),
    "x_use_fir_lt": struct(
        args = dict(
            default = False,
            doc = "Compile using LightTree parser with Front-end IR. Warning: this feature is far from being production-ready",
        ),
        type = attr.bool,
        value_to_flag = {
            True: ["-Xuse-fir-lt"],
        },
    ),
    "x_use_k2": struct(
        # 1.7
        flag = "-Xuse-k2",
        args = dict(
            default = False,
            doc = "Compile using experimental K2. K2 is a new compiler pipeline, no compatibility guarantees are yet provided",
        ),
        type = attr.bool,
        value_to_flag = {
            True: ["-Xuse-k2"],
        },
    ),
    "x_warning_level": struct(
        args = dict(
            default = {},
            doc = "Suppress specific warnings globally. Ex: 'OPTION': '(error|warning|disabled)'",
        ),
        type = attr.string_dict,
        value_to_flag = None,
        map_value_to_flag = _map_warning_level,
    ),
}

def _merge(key, rule_defined):
    """Merges rule option with compiler option."""
    if key not in _KOTLIN_OPTS:
        # No flag associated with option.
        return rule_defined
    generated = _KOTLIN_OPTS[key]
    merged = {k: getattr(k, rule_defined) for k in dir(rule_defined)}
    merged["doc"] = generated.doc
    merged["default"] = generated.default
    return struct(**merged)

def _no_merge(_, definition):
    return definition

_maybe_merge_definition = _merge if hasattr(_KOTLIN_OPTS, "get") else _no_merge

# Filters out options that are not available in current compiler release
_KOPTS = {
    attr: _maybe_merge_definition(attr, defn)
    for (attr, defn) in _KOPTS_ALL.items()
    if not hasattr(defn, "flag") or defn.flag in _KOTLIN_OPTS
}

KotlincOptions = provider(
    fields = {
        name: o.args["doc"]
        for name, o in _KOPTS.items()
    },
)

def _kotlinc_options_impl(ctx):
    return [KotlincOptions(**{n: getattr(ctx.attr, n, None) for n in _KOPTS})]

kt_kotlinc_options = rule(
    implementation = _kotlinc_options_impl,
    doc = "Define kotlin compiler options.",
    provides = [KotlincOptions],
    attrs = {n: o.type(**o.args) for n, o in _KOPTS.items()},
)

def kotlinc_options_to_flags(kotlinc_options):
    """Translate KotlincOptions to worker flags

    Args:
        kotlinc_options maybe containing KotlincOptions
    Returns:
        list of flags to add to the command line.
    """
    return convert.javac_options_to_flags(_KOPTS, kotlinc_options)
