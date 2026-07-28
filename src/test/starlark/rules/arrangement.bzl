load("//kotlin:jvm.bzl", "kt_jvm_import", "kt_jvm_library")

def arrange(test, transitive_dep = None):
    dependency_a_trans_dep_jar = transitive_dep
    if dependency_a_trans_dep_jar == None:
        dependency_a_trans_dep_jar = test.artifact(
            name = "dependency_a_trans_dep.abi.jar",
        )
        dependency_a_trans_dep = test.have(
            kt_jvm_import,
            name = "dependency_a_dep_jar_import",
            jars = [
                dependency_a_trans_dep_jar,
            ],
        )
    else:
        dependency_a_trans_dep = dependency_a_trans_dep_jar

    dependency_a = test.have(
        kt_jvm_library,
        name = "dependency_a",
        srcs = [
            test.artifact(
                name = "dependency_a.kt",
            ),
        ],
        deps = [
            dependency_a_trans_dep,
        ],
    )

    main_target_library = test.got(
        kt_jvm_library,
        name = "main_target_library",
        srcs = [
            test.artifact(
                name = "main_target_library.kt",
            ),
        ],
        deps = [
            dependency_a,
        ],
    )

    return (dependency_a_trans_dep_jar, dependency_a, main_target_library)
