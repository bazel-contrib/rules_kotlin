load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("//kotlin:jvm.bzl", "kt_jvm_library")
load("//src/main/starlark/core/compile:common.bzl", "KtJvmInfo")
load("//src/main/starlark/core/compile:rules.bzl", "core_kt_jvm_binary", "core_kt_jvm_library")
load("//src/main/starlark/core/compile/cli:toolchain.bzl", "COMPILE_MNEMONIC")
load("//src/test/starlark:case.bzl", "Want", "suite")

#load("//src/test/starlark:truth.bzl", "fail_messages_in", "flags_and_values_of")
load(":subjects.bzl", "java_info_subject_factory")

def _maybe_get_class_jar(o):
    return getattr(o, "class_jar", None)

def _outputs(env, got):
    got_target = env.expect.that_target(got)

    # assert java outputs
    got_target.has_provider(JavaInfo)
    got_java_info = got_target.provider(JavaInfo, java_info_subject_factory)
    got_java_info.java_outputs().transform(
        desc = "class_jar",
        map_each = _maybe_get_class_jar,
    ).contains(env.ctx.file.class_jar)

    want_compile_jars = {
        j: True
        for d in env.ctx.attr.transitive_compile_deps
        if JavaInfo in d
        for j in d[JavaInfo].compile_jars.to_list()
    }.keys()

    want_runtime_jars = [
        j
        for d in env.ctx.attr.transitive_runtime_deps
        if JavaInfo in d
        for j in d[JavaInfo].transitive_runtime_jars.to_list()
    ]

    got_java_info.transitive_compile_time_jars().contains_exactly([j.short_path for j in want_compile_jars])
    got_java_info.transitive_runtime_jars().contains_exactly([j.short_path for j in want_runtime_jars])
    got_java_info.source_jars().contains(env.ctx.file.source_jar)

    # ensure source jar is written
    got_target.action_generating(env.ctx.file.source_jar.short_path)

    inputs = []
    for i in env.ctx.attr.inputs:
        if JavaInfo in i:
            for jo in i[JavaInfo].java_outputs:
                inputs.append(jo.compile_jar)
        else:
            inputs.extend(i[DefaultInfo].files.to_list())

    # ensure compile action has the right inputs
    compile = got_target.action_named(env.ctx.attr.compile_mnemonic)
    compile.contains_at_least_inputs(inputs)

    got_target.runfiles().contains_at_least([
        "/".join((env.ctx.workspace_name, f.short_path))
        for r in env.ctx.attr.runfiles
        for f in r[DefaultInfo].files.to_list()
    ])

def _test_neverlink_deps(
        rule_under_test,
        compile_mnemonic,
        srcjar_ext = ".srcjar",
        additional_compile_libs = [],
        **kwargs):
    def _case(test):
        have = test.have(
            rule_under_test,
            name = "have",
            srcs = [test.artifact("hold.kt")],
            deps = [],
            neverlink = True,
            **kwargs
        )

        got_src = test.artifact("gave.kt")
        got = test.got(
            rule_under_test,
            name = "got",
            srcs = [got_src],
            deps = [have],
            **kwargs
        )
        test.claim(
            got = got,
            what = _outputs,
            wants = {
                "class_jar": Want(
                    attr = attr.label(allow_single_file = True),
                    value = got + ".jar",
                ),
                "compile_mnemonic": Want(
                    attr = attr.string(),
                    value = compile_mnemonic,
                ),
                "inputs": Want(
                    attr = attr.label_list(allow_empty = True, allow_files = True),
                    value = [got_src, have],
                ),
                "runfiles": Want(
                    attr = attr.label_list(allow_empty = True, allow_files = True),
                    value = [],
                ),
                "source_jar": Want(
                    attr = attr.label(allow_single_file = True),
                    value = got + srcjar_ext,
                ),
                "transitive_compile_deps": Want(
                    attr = attr.label_list(providers = [[JavaInfo], [KtJvmInfo]]),
                    value = [got, have] + additional_compile_libs,
                ),
                "transitive_runtime_deps": Want(
                    attr = attr.label_list(providers = [[JavaInfo], [KtJvmInfo]]),
                    value = [got],
                ),
            },
        )

    return _case

def _test_runfiles(
        rule_under_test,
        compile_mnemonic,
        srcjar_ext = ".srcjar",
        additional_compile_libs = [],
        **kwargs):
    def _case(test):
        transitive_data_file = test.artifact("transitive_data.file")
        transitive_data = test.have(
            rule_under_test,
            name = "transitive_data",
            srcs = [],
            deps = [],
            data = [transitive_data_file],
            **kwargs
        )
        data_file = test.artifact("data.file")
        data = test.have(
            rule_under_test,
            name = "data",
            srcs = [],
            runtime_deps = [transitive_data],
            data = [data_file],
            **kwargs
        )

        got = test.got(
            rule_under_test,
            name = "got",
            srcs = [
                test.artifact("gave.kt"),
            ],
            deps = [
                data,
            ],
            **kwargs
        )
        test.claim(
            got = got,
            what = _outputs,
            wants = {
                "class_jar": Want(
                    attr = attr.label(allow_single_file = True),
                    value = got + ".jar",
                ),
                "compile_mnemonic": Want(
                    attr = attr.string(),
                    value = compile_mnemonic,
                ),
                "inputs": Want(
                    attr = attr.label_list(allow_empty = True, allow_files = True),
                    value = [data],
                ),
                "runfiles": Want(
                    attr = attr.label_list(allow_empty = True, allow_files = True),
                    value = [
                        data_file,
                        transitive_data_file,
                    ],
                ),
                "source_jar": Want(
                    attr = attr.label(allow_single_file = True),
                    value = got + srcjar_ext,
                ),
                "transitive_compile_deps": Want(
                    attr = attr.label_list(providers = [[JavaInfo], [KtJvmInfo]]),
                    value = [data, got] + additional_compile_libs,
                ),
                "transitive_runtime_deps": Want(
                    attr = attr.label_list(providers = [[JavaInfo], [KtJvmInfo]]),
                    value = [got],
                ),
            },
        )

    return _case

def _test_deps(
        rule_under_test,
        compile_mnemonic,
        srcjar_ext = ".srcjar",
        additional_compile_libs = [],
        **kwargs):
    def _case(test):
        have_data = test.artifact("some.file")
        have = test.have(
            rule_under_test,
            name = "have",
            srcs = [
                test.artifact("hold.kt"),
            ],
            deps = [
            ],
            data = [
                have_data,
            ],
            **kwargs
        )

        got = test.got(
            rule_under_test,
            name = "got",
            srcs = [
                test.artifact("gave.kt"),
            ],
            deps = [
                have,
            ],
            **kwargs
        )
        test.claim(
            got = got,
            what = _outputs,
            wants = {
                "class_jar": Want(
                    attr = attr.label(allow_single_file = True),
                    value = got + ".jar",
                ),
                "compile_mnemonic": Want(
                    attr = attr.string(),
                    value = compile_mnemonic,
                ),
                "inputs": Want(
                    attr = attr.label_list(allow_empty = True, allow_files = True),
                    value = [have],
                ),
                "runfiles": Want(
                    attr = attr.label_list(allow_empty = True, allow_files = True),
                    value = [
                        have_data,
                    ],
                ),
                "source_jar": Want(
                    attr = attr.label(allow_single_file = True),
                    value = got + srcjar_ext,
                ),
                "transitive_compile_deps": Want(
                    attr = attr.label_list(providers = [[JavaInfo], [KtJvmInfo]]),
                    value = [have, got] + additional_compile_libs,
                ),
                "transitive_runtime_deps": Want(
                    attr = attr.label_list(providers = [[JavaInfo], [KtJvmInfo]]),
                    value = [got],
                ),
            },
        )

    return _case

def _test_no_deps(
        rule_under_test,
        compile_mnemonic,
        srcjar_ext = ".srcjar",
        additional_compile_libs = [],
        **kwargs):
    def _case(test):
        have_src = test.artifact("a.kt")
        have_data = test.artifact("some.data")
        got = test.got(
            rule_under_test,
            name = "got",
            srcs = [
                have_src,
            ],
            deps = [
            ],
            data = [
                have_data,
            ],
            **kwargs
        )
        test.claim(
            got = got,
            what = _outputs,
            wants = {
                "class_jar": Want(
                    attr = attr.label(allow_single_file = True),
                    value = got + ".jar",
                ),
                "compile_mnemonic": Want(
                    attr = attr.string(),
                    value = compile_mnemonic,
                ),
                "inputs": Want(
                    attr = attr.label_list(allow_empty = True, allow_files = True),
                    value = [have_src],
                ),
                "runfiles": Want(
                    attr = attr.label_list(allow_empty = True, allow_files = True),
                    value = [have_data],
                ),
                "source_jar": Want(
                    attr = attr.label(allow_single_file = True),
                    value = got + srcjar_ext,
                ),
                "transitive_compile_deps": Want(
                    attr = attr.label_list(providers = [[JavaInfo], [KtJvmInfo]]),
                    value = [got] + additional_compile_libs,
                ),
                "transitive_runtime_deps": Want(
                    attr = attr.label_list(providers = [[JavaInfo], [KtJvmInfo]]),
                    value = [got],
                ),
            },
        )

    return _case

def _test_exports(
        rule_under_test,
        compile_mnemonic,
        srcjar_ext = ".srcjar",
        additional_compile_libs = [],
        **kwargs):
    def _case(test):
        have_data = test.artifact("some.data")
        have_library = test.have(
            rule_under_test,
            name = "have_library",
            srcs = [
                test.artifact("library.kt"),
            ],
            data = [
                have_data,
            ],
            **kwargs
        )

        have_export = test.have(
            rule_under_test,
            name = "have_exports",
            exports = [
                have_library,
            ],
            **kwargs
        )

        have_src = test.artifact("a.kt")
        got = test.got(
            rule_under_test,
            name = "got",
            srcs = [
                have_src,
            ],
            deps = [
                have_export,
            ],
            data = [
            ],
            **kwargs
        )
        test.claim(
            got = got,
            what = _outputs,
            wants = {
                "class_jar": Want(
                    attr = attr.label(allow_single_file = True),
                    value = got + ".jar",
                ),
                "compile_mnemonic": Want(
                    attr = attr.string(),
                    value = compile_mnemonic,
                ),
                "inputs": Want(
                    attr = attr.label_list(allow_empty = True, allow_files = True),
                    value = [have_src, have_library],
                ),
                "runfiles": Want(
                    attr = attr.label_list(allow_empty = True, allow_files = True),
                    value = [have_data],
                ),
                "source_jar": Want(
                    attr = attr.label(allow_single_file = True),
                    value = got + srcjar_ext,
                ),
                "transitive_compile_deps": Want(
                    attr = attr.label_list(providers = [[JavaInfo], [KtJvmInfo]]),
                    value = [got, have_library, have_export] + additional_compile_libs,
                ),
                "transitive_runtime_deps": Want(
                    attr = attr.label_list(providers = [[JavaInfo], [KtJvmInfo]]),
                    value = [got],
                ),
            },
        )

    return _case

def test_core():
    binary = dict(
        rule_under_test = core_kt_jvm_binary,
        compile_mnemonic = COMPILE_MNEMONIC,
        main_class = "Foo",
    )
    library = dict(
        rule_under_test = core_kt_jvm_library,
        compile_mnemonic = COMPILE_MNEMONIC,
    )
    return dict(
        test_deps_core_kt_jvm_binary = _test_deps(**binary),
        test_neverlink_deps_core_kt_jvm_binary = _test_neverlink_deps(**binary),
        test_no_deps_core_kt_jvm_binary = _test_no_deps(**binary),
        test_deps_core_kt_jvm_library = _test_deps(**library),
        test_neverlink_deps_core_kt_jvm_library = _test_neverlink_deps(**library),
        test_no_deps_core_kt_jvm_library = _test_no_deps(**library),
        test_exports_core_kt_jvm_library = _test_exports(**library),
        test_runfiles_core = _test_runfiles(**library),
    )

def test_jvm():
    library = dict(
        rule_under_test = kt_jvm_library,
        srcjar_ext = "-sources.jar",
        compile_mnemonic = "KotlinCompile",
        additional_compile_libs = [
            "//kotlin/compiler:kotlin-stdlib",
            "//kotlin/compiler:annotations",
        ],
    )
    return dict(
        test_deps_kt_jvm_library = _test_deps(**library),
        test_neverlink_deps_kt_jvm_library = _test_neverlink_deps(**library),
        test_no_deps_kt_jvm_library = _test_no_deps(**library),
        test_exports_kt_jvm_library = _test_exports(**library),
        test_runfiles = _test_runfiles(**library),
    )

def test_suite(name):
    suite(
        name,
        **{
            n: v
            for (n, v) in test_jvm().items() + test_core().items()
        }
    )
