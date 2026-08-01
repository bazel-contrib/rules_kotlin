"""Tests for the way associates are declared to the kotlin builder."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:truth.bzl", "matching")
load("//kotlin:jvm.bzl", "kt_jvm_library")
load("//src/test/starlark:case.bzl", "suite")
load(":util.bzl", "basename_of", "values_for_flag_of")

# A toolchain with experimental_remove_private_classes_in_abi_jars enabled, which makes associates
# contribute their class jar - rather than their compile jar - to the classpath.
_REMOVE_PRIVATE_CLASSES_TOOLCHAIN = Label("//src/test/starlark/rules:remove_private_classes_toolchain")

def _arrange(test):
    associate = test.have(
        kt_jvm_library,
        name = "associate",
        srcs = [
            test.artifact(name = "associate.kt"),
        ],
    )

    main_target_library = test.got(
        kt_jvm_library,
        name = "main_target_library",
        srcs = [
            test.artifact(name = "main_target_library.kt"),
        ],
        associates = [
            associate,
        ],
    )

    return main_target_library

def _associate_jars_are_direct_dependencies_(env, target):
    """Every jar an associate puts on the classpath has to be a declared direct dependency.

    Associates cannot be listed in deps as well, so anything the associate contributes that is not
    declared here is reported by strict deps as a violation the user has no way of fixing.
    """
    action = env.expect.that_target(target).action_named("KotlinCompile")

    friend_paths = values_for_flag_of(action, "--kotlin_friend_paths").actual
    env.expect.that_collection(friend_paths).has_size(1)

    values_for_flag_of(action, "--direct_dependencies").contains_at_least(friend_paths)
    values_for_flag_of(action, "--classpath").contains_at_least(friend_paths)

def _test_associate_jars_are_direct_dependencies(test):
    analysis_test(
        name = test.name,
        impl = _associate_jars_are_direct_dependencies_,
        target = _arrange(test),
    )

def _associate_class_jar_is_direct_dependency_(env, target):
    """With private class removal on, the class jar of the associate is the one that has to be declared.

    Its compile jar no longer carries the internal symbols an associate is allowed to see, so
    associates.bzl swaps in the class jar. Declaring the compile jar instead leaves the class jar
    undeclared on the classpath.
    """
    _associate_jars_are_direct_dependencies_(env, target)

    action = env.expect.that_target(target).action_named("KotlinCompile")
    direct_dependencies = values_for_flag_of(action, "--direct_dependencies").transform(
        desc = "basenames",
        map_each = basename_of,
    )
    direct_dependencies.contains("%s_associate.jar" % env.ctx.attr.namespace)

    # The compile jar of the associate is the one that is missing the internal symbols, it is
    # replaced on the classpath by the class jar asserted above.
    values_for_flag_of(action, "--classpath").transform(
        desc = "basenames",
        map_each = basename_of,
    ).contains_none_of(["%s_associate.abi.jar" % env.ctx.attr.namespace])

    # The merger reads the owning label from the manifest of every jar the jdeps mention, whatever
    # the kind of the entry is. Both flavors of the associate jar have to be available to the
    # action: the class jar because it is the one on the classpath, and so the one the used entries
    # point at, and the compile jar because it stays in --direct_dependencies and therefore shows up
    # as an unused entry.
    jdeps_merge = env.expect.that_target(target).action_named("JdepsMerge")
    jdeps_merge.inputs().contains_at_least_predicates([
        matching.file_basename_equals("%s_associate.jar" % env.ctx.attr.namespace),
        matching.file_basename_equals("%s_associate.abi.jar" % env.ctx.attr.namespace),
    ])

def _test_associate_class_jar_is_direct_dependency_with_remove_private_classes(test):
    analysis_test(
        name = test.name,
        impl = _associate_class_jar_is_direct_dependency_,
        target = _arrange(test),
        config_settings = {
            "//command_line_option:extra_toolchains": [str(_REMOVE_PRIVATE_CLASSES_TOOLCHAIN)],
        },
        attr_values = {
            "namespace": test.name,
        },
        attrs = {
            "namespace": attr.string(),
        },
    )

def associates_tests(name):
    suite(
        name,
        direct_dependencies = _test_associate_jars_are_direct_dependencies,
        remove_private_classes = _test_associate_class_jar_is_direct_dependency_with_remove_private_classes,
    )
