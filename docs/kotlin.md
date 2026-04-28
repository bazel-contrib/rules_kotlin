<!-- Generated with Stardoc: http://skydoc.bazel.build -->



<a id="kt_javac_options"></a>

## kt_javac_options

<pre>
load("@rules_kotlin//kotlin:jvm.bzl", "kt_javac_options")

kt_javac_options(<a href="#kt_javac_options-name">name</a>, <a href="#kt_javac_options-add_exports">add_exports</a>, <a href="#kt_javac_options-release">release</a>, <a href="#kt_javac_options-warn">warn</a>, <a href="#kt_javac_options-x_ep_disable_all_checks">x_ep_disable_all_checks</a>, <a href="#kt_javac_options-x_explicit_api_mode">x_explicit_api_mode</a>,
                 <a href="#kt_javac_options-x_lint">x_lint</a>, <a href="#kt_javac_options-xd_suppress_notes">xd_suppress_notes</a>)
</pre>

Define java compiler options for `kt_jvm_*` rules with java sources.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="kt_javac_options-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="kt_javac_options-add_exports"></a>add_exports |  Export internal jdk apis   | List of strings | optional |  `[]`  |
| <a id="kt_javac_options-release"></a>release |  Compile for the specified Java SE release   | String | optional |  `"default"`  |
| <a id="kt_javac_options-warn"></a>warn |  Control warning behaviour.   | String | optional |  `"report"`  |
| <a id="kt_javac_options-x_ep_disable_all_checks"></a>x_ep_disable_all_checks |  See javac -XepDisableAllChecks documentation   | Boolean | optional |  `False`  |
| <a id="kt_javac_options-x_explicit_api_mode"></a>x_explicit_api_mode |  Enable explicit API mode for Kotlin libraries.   | String | optional |  `"off"`  |
| <a id="kt_javac_options-x_lint"></a>x_lint |  See javac -Xlint: documentation   | List of strings | optional |  `[]`  |
| <a id="kt_javac_options-xd_suppress_notes"></a>xd_suppress_notes |  See javac -XDsuppressNotes documentation   | Boolean | optional |  `False`  |


<a id="kt_jvm_binary"></a>

## kt_jvm_binary

<pre>
load("@rules_kotlin//kotlin:jvm.bzl", "kt_jvm_binary")

kt_jvm_binary(<a href="#kt_jvm_binary-name">name</a>, <a href="#kt_jvm_binary-deps">deps</a>, <a href="#kt_jvm_binary-srcs">srcs</a>, <a href="#kt_jvm_binary-data">data</a>, <a href="#kt_jvm_binary-resources">resources</a>, <a href="#kt_jvm_binary-associates">associates</a>, <a href="#kt_jvm_binary-env">env</a>, <a href="#kt_jvm_binary-env_inherit">env_inherit</a>, <a href="#kt_jvm_binary-java_stub_template">java_stub_template</a>,
              <a href="#kt_jvm_binary-javac_opts">javac_opts</a>, <a href="#kt_jvm_binary-jvm_flags">jvm_flags</a>, <a href="#kt_jvm_binary-kotlinc_opts">kotlinc_opts</a>, <a href="#kt_jvm_binary-main_class">main_class</a>, <a href="#kt_jvm_binary-module_name">module_name</a>, <a href="#kt_jvm_binary-plugins">plugins</a>, <a href="#kt_jvm_binary-resource_jars">resource_jars</a>,
              <a href="#kt_jvm_binary-resource_strip_prefix">resource_strip_prefix</a>, <a href="#kt_jvm_binary-runtime_deps">runtime_deps</a>)
</pre>

Builds a Java archive ("jar file"), plus a wrapper shell script with the same name as the rule. The wrapper
shell script uses a classpath that includes, among other things, a jar file for each library on which the binary
depends.

**Note:** This rule does not have all of the features found in [`java_binary`](https://docs.bazel.build/versions/master/be/java.html#java_binary).
It is appropriate for building workspace utilities. `java_binary` should be preferred for release artefacts.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="kt_jvm_binary-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="kt_jvm_binary-deps"></a>deps |  A list of dependencies of this rule.See general comments about `deps` at [Attributes common to all build rules](https://docs.bazel.build/versions/master/be/common-definitions.html#common-attributes).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="kt_jvm_binary-srcs"></a>srcs |  The list of source files that are processed to create the target, this can contain both Java and Kotlin files. Java analysis occurs first so Kotlin classes may depend on Java classes in the same compilation unit.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="kt_jvm_binary-data"></a>data |  The list of files needed by this rule at runtime. See general comments about `data` at [Attributes common to all build rules](https://docs.bazel.build/versions/master/be/common-definitions.html#common-attributes).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="kt_jvm_binary-resources"></a>resources |  A list of files that should be include in a Java jar.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="kt_jvm_binary-associates"></a>associates |  Kotlin deps who should be considered part of the same module/compilation-unit for the purposes of "internal" access. Such deps must all share the same module space and so a target cannot associate to two deps from two different modules.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="kt_jvm_binary-env"></a>env |  Environment variables to set when this binary is executed with `bazel run`. Note: for Starlark rules, values are used as-is (no automatic $(location) / make variable expansion).   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="kt_jvm_binary-env_inherit"></a>env_inherit |  Names of environment variables to inherit from the shell when executed with `bazel run`.   | List of strings | optional |  `[]`  |
| <a id="kt_jvm_binary-java_stub_template"></a>java_stub_template |  -   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `"@rules_kotlin//third_party:java_stub_template.txt"`  |
| <a id="kt_jvm_binary-javac_opts"></a>javac_opts |  Javac options to be used when compiling this target. These opts if provided will be used instead of the ones provided to the toolchain.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="kt_jvm_binary-jvm_flags"></a>jvm_flags |  A list of flags to embed in the wrapper script generated for running this binary. Note: does not yet support make variable substitution.   | List of strings | optional |  `[]`  |
| <a id="kt_jvm_binary-kotlinc_opts"></a>kotlinc_opts |  Kotlinc options to be used when compiling this target. These opts if provided will be used instead of the ones provided to the toolchain.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="kt_jvm_binary-main_class"></a>main_class |  Name of class with main() method to use as entry point.   | String | required |  |
| <a id="kt_jvm_binary-module_name"></a>module_name |  The name of the module, if not provided the module name is derived from the label. --e.g., `//some/package/path:label_name` is translated to `some_package_path-label_name`.   | String | optional |  `""`  |
| <a id="kt_jvm_binary-plugins"></a>plugins |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="kt_jvm_binary-resource_jars"></a>resource_jars |  Set of archives containing Java resources. If specified, the contents of these jars are merged into the output jar.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="kt_jvm_binary-resource_strip_prefix"></a>resource_strip_prefix |  The path prefix to strip from Java resources. Should be a label pointing to a directory. Files residing under common prefix such as `src/main/resources` or `src/test/resources` or `kotlin` will have stripping applied by convention if this is not specified.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="kt_jvm_binary-runtime_deps"></a>runtime_deps |  Libraries to make available to the final binary or test at runtime only. Like ordinary deps, these will appear on the runtime classpath, but unlike them, not on the compile-time classpath.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |


<a id="kt_jvm_import"></a>

## kt_jvm_import

<pre>
load("@rules_kotlin//kotlin:jvm.bzl", "kt_jvm_import")

kt_jvm_import(<a href="#kt_jvm_import-name">name</a>, <a href="#kt_jvm_import-deps">deps</a>, <a href="#kt_jvm_import-exported_compiler_plugins">exported_compiler_plugins</a>, <a href="#kt_jvm_import-exports">exports</a>, <a href="#kt_jvm_import-jar">jar</a>, <a href="#kt_jvm_import-jars">jars</a>, <a href="#kt_jvm_import-neverlink">neverlink</a>, <a href="#kt_jvm_import-runtime_deps">runtime_deps</a>,
              <a href="#kt_jvm_import-srcjar">srcjar</a>)
</pre>

Import Kotlin jars.

## examples

```bzl
# Old style usage -- reference file groups, do not used this.
kt_jvm_import(
    name = "kodein",
    jars = [
        "@com_github_salomonbrys_kodein_kodein//jar:file",
        "@com_github_salomonbrys_kodein_kodein_core//jar:file"
    ]
)

# This style will pull in the transitive runtime dependencies of the targets as well.
kt_jvm_import(
    name = "kodein",
    jars = [
        "@com_github_salomonbrys_kodein_kodein//jar",
        "@com_github_salomonbrys_kodein_kodein_core//jar"
    ]
)

# Import a single kotlin jar.
kt_jvm_import(
    name = "kotlin-stdlib",
    jars = ["lib/kotlin-stdlib.jar"],
    srcjar = "lib/kotlin-stdlib-sources.jar"
)
```

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="kt_jvm_import-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="kt_jvm_import-deps"></a>deps |  Compile and runtime dependencies   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="kt_jvm_import-exported_compiler_plugins"></a>exported_compiler_plugins |  Exported compiler plugins.<br><br>Compiler plugins listed here will be treated as if they were added in the plugins attribute of any targets that directly depend on this target. Like java_plugins' exported_plugins, this is not transitive   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="kt_jvm_import-exports"></a>exports |  Exported libraries.<br><br>Deps listed here will be made available to other rules, as if the parents explicitly depended on these deps. This is not true for regular (non-exported) deps.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="kt_jvm_import-jar"></a>jar |  The jar listed here is equivalent to an export attribute.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="kt_jvm_import-jars"></a>jars |  The jars listed here are equavalent to an export attribute. The label should be either to a single class jar, or one or more filegroup labels.  The filegroups, when resolved, must contain  only one jar containing classes, and (optionally) one peer file containing sources, named `<jarname>-sources.jar`.<br><br>DEPRECATED - please use `jar` and `srcjar` attributes.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="kt_jvm_import-neverlink"></a>neverlink |  If true only use this library for compilation and not at runtime.   | Boolean | optional |  `False`  |
| <a id="kt_jvm_import-runtime_deps"></a>runtime_deps |  Additional runtime deps.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="kt_jvm_import-srcjar"></a>srcjar |  The sources for the class jar.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `"@rules_kotlin//third_party:empty.jar"`  |


<a id="kt_jvm_library"></a>

## kt_jvm_library

<pre>
load("@rules_kotlin//kotlin:jvm.bzl", "kt_jvm_library")

kt_jvm_library(<a href="#kt_jvm_library-name">name</a>, <a href="#kt_jvm_library-deps">deps</a>, <a href="#kt_jvm_library-srcs">srcs</a>, <a href="#kt_jvm_library-data">data</a>, <a href="#kt_jvm_library-resources">resources</a>, <a href="#kt_jvm_library-associates">associates</a>, <a href="#kt_jvm_library-exported_compiler_plugins">exported_compiler_plugins</a>, <a href="#kt_jvm_library-exports">exports</a>,
               <a href="#kt_jvm_library-java_stub_template">java_stub_template</a>, <a href="#kt_jvm_library-javac_opts">javac_opts</a>, <a href="#kt_jvm_library-kotlinc_opts">kotlinc_opts</a>, <a href="#kt_jvm_library-module_name">module_name</a>, <a href="#kt_jvm_library-neverlink">neverlink</a>, <a href="#kt_jvm_library-plugins">plugins</a>,
               <a href="#kt_jvm_library-resource_jars">resource_jars</a>, <a href="#kt_jvm_library-resource_strip_prefix">resource_strip_prefix</a>, <a href="#kt_jvm_library-runtime_deps">runtime_deps</a>)
</pre>

This rule compiles and links Kotlin and Java sources into a .jar file.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="kt_jvm_library-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="kt_jvm_library-deps"></a>deps |  A list of dependencies of this rule.See general comments about `deps` at [Attributes common to all build rules](https://docs.bazel.build/versions/master/be/common-definitions.html#common-attributes).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="kt_jvm_library-srcs"></a>srcs |  The list of source files that are processed to create the target, this can contain both Java and Kotlin files. Java analysis occurs first so Kotlin classes may depend on Java classes in the same compilation unit.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="kt_jvm_library-data"></a>data |  The list of files needed by this rule at runtime. See general comments about `data` at [Attributes common to all build rules](https://docs.bazel.build/versions/master/be/common-definitions.html#common-attributes).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="kt_jvm_library-resources"></a>resources |  A list of files that should be include in a Java jar.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="kt_jvm_library-associates"></a>associates |  Kotlin deps who should be considered part of the same module/compilation-unit for the purposes of "internal" access. Such deps must all share the same module space and so a target cannot associate to two deps from two different modules.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="kt_jvm_library-exported_compiler_plugins"></a>exported_compiler_plugins |  Exported compiler plugins.<br><br>Compiler plugins listed here will be treated as if they were added in the plugins attribute of any targets that directly depend on this target. Like `java_plugin`s exported_plugins, this is not transitive   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="kt_jvm_library-exports"></a>exports |  Exported libraries.<br><br>Deps listed here will be made available to other rules, as if the parents explicitly depended on these deps. This is not true for regular (non-exported) deps.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="kt_jvm_library-java_stub_template"></a>java_stub_template |  -   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `"@rules_kotlin//third_party:java_stub_template.txt"`  |
| <a id="kt_jvm_library-javac_opts"></a>javac_opts |  Javac options to be used when compiling this target. These opts if provided will be used instead of the ones provided to the toolchain.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="kt_jvm_library-kotlinc_opts"></a>kotlinc_opts |  Kotlinc options to be used when compiling this target. These opts if provided will be used instead of the ones provided to the toolchain.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="kt_jvm_library-module_name"></a>module_name |  The name of the module, if not provided the module name is derived from the label. --e.g., `//some/package/path:label_name` is translated to `some_package_path-label_name`.   | String | optional |  `""`  |
| <a id="kt_jvm_library-neverlink"></a>neverlink |  If true only use this library for compilation and not at runtime.   | Boolean | optional |  `False`  |
| <a id="kt_jvm_library-plugins"></a>plugins |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="kt_jvm_library-resource_jars"></a>resource_jars |  Set of archives containing Java resources. If specified, the contents of these jars are merged into the output jar.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="kt_jvm_library-resource_strip_prefix"></a>resource_strip_prefix |  The path prefix to strip from Java resources. Should be a label pointing to a directory. Files residing under common prefix such as `src/main/resources` or `src/test/resources` or `kotlin` will have stripping applied by convention if this is not specified.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="kt_jvm_library-runtime_deps"></a>runtime_deps |  Libraries to make available to the final binary or test at runtime only. Like ordinary deps, these will appear on the runtime classpath, but unlike them, not on the compile-time classpath.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |


<a id="kt_jvm_test"></a>

## kt_jvm_test

<pre>
load("@rules_kotlin//kotlin:jvm.bzl", "kt_jvm_test")

kt_jvm_test(<a href="#kt_jvm_test-name">name</a>, <a href="#kt_jvm_test-deps">deps</a>, <a href="#kt_jvm_test-srcs">srcs</a>, <a href="#kt_jvm_test-data">data</a>, <a href="#kt_jvm_test-resources">resources</a>, <a href="#kt_jvm_test-associates">associates</a>, <a href="#kt_jvm_test-env">env</a>, <a href="#kt_jvm_test-env_inherit">env_inherit</a>, <a href="#kt_jvm_test-java_stub_template">java_stub_template</a>,
            <a href="#kt_jvm_test-javac_opts">javac_opts</a>, <a href="#kt_jvm_test-jvm_flags">jvm_flags</a>, <a href="#kt_jvm_test-kotlinc_opts">kotlinc_opts</a>, <a href="#kt_jvm_test-main_class">main_class</a>, <a href="#kt_jvm_test-module_name">module_name</a>, <a href="#kt_jvm_test-plugins">plugins</a>, <a href="#kt_jvm_test-resource_jars">resource_jars</a>,
            <a href="#kt_jvm_test-resource_strip_prefix">resource_strip_prefix</a>, <a href="#kt_jvm_test-runtime_deps">runtime_deps</a>, <a href="#kt_jvm_test-test_class">test_class</a>)
</pre>

Setup a simple kotlin_test.

**Notes:**
* The kotlin test library is not added implicitly, it is available with the label
`@rules_kotlin//kotlin/compiler:kotlin-test`.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="kt_jvm_test-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="kt_jvm_test-deps"></a>deps |  A list of dependencies of this rule.See general comments about `deps` at [Attributes common to all build rules](https://docs.bazel.build/versions/master/be/common-definitions.html#common-attributes).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="kt_jvm_test-srcs"></a>srcs |  The list of source files that are processed to create the target, this can contain both Java and Kotlin files. Java analysis occurs first so Kotlin classes may depend on Java classes in the same compilation unit.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="kt_jvm_test-data"></a>data |  The list of files needed by this rule at runtime. See general comments about `data` at [Attributes common to all build rules](https://docs.bazel.build/versions/master/be/common-definitions.html#common-attributes).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="kt_jvm_test-resources"></a>resources |  A list of files that should be include in a Java jar.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="kt_jvm_test-associates"></a>associates |  Kotlin deps who should be considered part of the same module/compilation-unit for the purposes of "internal" access. Such deps must all share the same module space and so a target cannot associate to two deps from two different modules.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="kt_jvm_test-env"></a>env |  Specifies additional environment variables to set when the target is executed by bazel test.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="kt_jvm_test-env_inherit"></a>env_inherit |  Environment variables to inherit from the external environment.   | List of strings | optional |  `[]`  |
| <a id="kt_jvm_test-java_stub_template"></a>java_stub_template |  -   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `"@rules_kotlin//third_party:java_stub_template.txt"`  |
| <a id="kt_jvm_test-javac_opts"></a>javac_opts |  Javac options to be used when compiling this target. These opts if provided will be used instead of the ones provided to the toolchain.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="kt_jvm_test-jvm_flags"></a>jvm_flags |  A list of flags to embed in the wrapper script generated for running this binary. Note: does not yet support make variable substitution.   | List of strings | optional |  `[]`  |
| <a id="kt_jvm_test-kotlinc_opts"></a>kotlinc_opts |  Kotlinc options to be used when compiling this target. These opts if provided will be used instead of the ones provided to the toolchain.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="kt_jvm_test-main_class"></a>main_class |  -   | String | optional |  `"com.google.testing.junit.runner.BazelTestRunner"`  |
| <a id="kt_jvm_test-module_name"></a>module_name |  The name of the module, if not provided the module name is derived from the label. --e.g., `//some/package/path:label_name` is translated to `some_package_path-label_name`.   | String | optional |  `""`  |
| <a id="kt_jvm_test-plugins"></a>plugins |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="kt_jvm_test-resource_jars"></a>resource_jars |  Set of archives containing Java resources. If specified, the contents of these jars are merged into the output jar.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="kt_jvm_test-resource_strip_prefix"></a>resource_strip_prefix |  The path prefix to strip from Java resources. Should be a label pointing to a directory. Files residing under common prefix such as `src/main/resources` or `src/test/resources` or `kotlin` will have stripping applied by convention if this is not specified.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="kt_jvm_test-runtime_deps"></a>runtime_deps |  Libraries to make available to the final binary or test at runtime only. Like ordinary deps, these will appear on the runtime classpath, but unlike them, not on the compile-time classpath.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="kt_jvm_test-test_class"></a>test_class |  The Java class to be loaded by the test runner.   | String | optional |  `""`  |


<!-- Generated with Stardoc: http://skydoc.bazel.build -->



<a id="ktlint_config"></a>

## ktlint_config

<pre>
load("@rules_kotlin//kotlin:lint.bzl", "ktlint_config")

ktlint_config(<a href="#ktlint_config-name">name</a>, <a href="#ktlint_config-android_rules_enabled">android_rules_enabled</a>, <a href="#ktlint_config-editorconfig">editorconfig</a>, <a href="#ktlint_config-experimental_rules_enabled">experimental_rules_enabled</a>)
</pre>

Used to configure ktlint.

`ktlint` can be configured to use a `.editorconfig`, as documented at
https://github.com/pinterest/ktlint/#editorconfig

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="ktlint_config-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="ktlint_config-android_rules_enabled"></a>android_rules_enabled |  Turn on Android Kotlin Style Guide compatibility   | Boolean | optional |  `False`  |
| <a id="ktlint_config-editorconfig"></a>editorconfig |  Editor config file to use   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="ktlint_config-experimental_rules_enabled"></a>experimental_rules_enabled |  Turn on experimental rules (ktlint-ruleset-experimental)   | Boolean | optional |  `False`  |


<a id="ktlint_fix"></a>

## ktlint_fix

<pre>
load("@rules_kotlin//kotlin:lint.bzl", "ktlint_fix")

ktlint_fix(<a href="#ktlint_fix-name">name</a>, <a href="#ktlint_fix-srcs">srcs</a>, <a href="#ktlint_fix-config">config</a>)
</pre>

Lint Kotlin files and automatically fix them as needed

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="ktlint_fix-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="ktlint_fix-srcs"></a>srcs |  Source files to review and fix   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="ktlint_fix-config"></a>config |  ktlint_config to use   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |


<a id="ktlint_test"></a>

## ktlint_test

<pre>
load("@rules_kotlin//kotlin:lint.bzl", "ktlint_test")

ktlint_test(<a href="#ktlint_test-name">name</a>, <a href="#ktlint_test-srcs">srcs</a>, <a href="#ktlint_test-config">config</a>)
</pre>

Lint Kotlin files, and fail if the linter raises errors.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="ktlint_test-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="ktlint_test-srcs"></a>srcs |  Source files to lint   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="ktlint_test-config"></a>config |  ktlint_config to use   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |


<!-- Generated with Stardoc: http://skydoc.bazel.build -->



<a id="kt_compiler_plugin"></a>

## kt_compiler_plugin

<pre>
load("@rules_kotlin//kotlin:core.bzl", "kt_compiler_plugin")

kt_compiler_plugin(<a href="#kt_compiler_plugin-name">name</a>, <a href="#kt_compiler_plugin-deps">deps</a>, <a href="#kt_compiler_plugin-data">data</a>, <a href="#kt_compiler_plugin-compile_phase">compile_phase</a>, <a href="#kt_compiler_plugin-id">id</a>, <a href="#kt_compiler_plugin-options">options</a>, <a href="#kt_compiler_plugin-stubs_phase">stubs_phase</a>,
                   <a href="#kt_compiler_plugin-target_embedded_compiler">target_embedded_compiler</a>)
</pre>

Define a plugin for the Kotlin compiler to run. The plugin can then be referenced in the `plugins` attribute
of the `kt_jvm_*` rules.

An example can be found under `//examples/plugin`:

```bzl
kt_compiler_plugin(
    name = "open_for_testing_plugin",
    id = "org.jetbrains.kotlin.allopen",
    options = {
        "annotation": "plugin.OpenForTesting",
    },
    deps = [
        "//kotlin/compiler:allopen-compiler-plugin",
    ],
)

kt_jvm_library(
    name = "open_for_testing",
    srcs = ["OpenForTesting.kt"],
)

kt_jvm_library(
    name = "user",
    srcs = ["User.kt"],
    plugins = [":open_for_testing_plugin"],
    deps = [
        ":open_for_testing",
    ],
)
```

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="kt_compiler_plugin-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="kt_compiler_plugin-deps"></a>deps |  The list of libraries to be added to the compiler's plugin classpath   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="kt_compiler_plugin-data"></a>data |  The list of data files to be used by compiler's plugin   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="kt_compiler_plugin-compile_phase"></a>compile_phase |  Runs the compiler plugin during kotlin compilation. Known examples: `allopen`, `sam_with_reciever`   | Boolean | optional |  `True`  |
| <a id="kt_compiler_plugin-id"></a>id |  The ID of the plugin   | String | required |  |
| <a id="kt_compiler_plugin-options"></a>options |  Dictionary of options to be passed to the plugin. Supports the following template values:<br><br>- `{generatedClasses}`: directory for generated class output - `{temp}`: temporary directory, discarded between invocations - `{generatedSources}`:  directory for generated source output - `{classpath}` : replaced with a list of jars separated by the filesystem appropriate separator.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="kt_compiler_plugin-stubs_phase"></a>stubs_phase |  Runs the compiler plugin in kapt stub generation.   | Boolean | optional |  `True`  |
| <a id="kt_compiler_plugin-target_embedded_compiler"></a>target_embedded_compiler |  Plugin was compiled against the embeddable kotlin compiler. These plugins expect shaded kotlinc dependencies, and will fail when running against a non-embeddable compiler.   | Boolean | optional |  `False`  |


<a id="kt_javac_options"></a>

## kt_javac_options

<pre>
load("@rules_kotlin//kotlin:core.bzl", "kt_javac_options")

kt_javac_options(<a href="#kt_javac_options-name">name</a>, <a href="#kt_javac_options-add_exports">add_exports</a>, <a href="#kt_javac_options-release">release</a>, <a href="#kt_javac_options-warn">warn</a>, <a href="#kt_javac_options-x_ep_disable_all_checks">x_ep_disable_all_checks</a>, <a href="#kt_javac_options-x_explicit_api_mode">x_explicit_api_mode</a>,
                 <a href="#kt_javac_options-x_lint">x_lint</a>, <a href="#kt_javac_options-xd_suppress_notes">xd_suppress_notes</a>)
</pre>

Define java compiler options for `kt_jvm_*` rules with java sources.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="kt_javac_options-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="kt_javac_options-add_exports"></a>add_exports |  Export internal jdk apis   | List of strings | optional |  `[]`  |
| <a id="kt_javac_options-release"></a>release |  Compile for the specified Java SE release   | String | optional |  `"default"`  |
| <a id="kt_javac_options-warn"></a>warn |  Control warning behaviour.   | String | optional |  `"report"`  |
| <a id="kt_javac_options-x_ep_disable_all_checks"></a>x_ep_disable_all_checks |  See javac -XepDisableAllChecks documentation   | Boolean | optional |  `False`  |
| <a id="kt_javac_options-x_explicit_api_mode"></a>x_explicit_api_mode |  Enable explicit API mode for Kotlin libraries.   | String | optional |  `"off"`  |
| <a id="kt_javac_options-x_lint"></a>x_lint |  See javac -Xlint: documentation   | List of strings | optional |  `[]`  |
| <a id="kt_javac_options-xd_suppress_notes"></a>xd_suppress_notes |  See javac -XDsuppressNotes documentation   | Boolean | optional |  `False`  |


<a id="kt_kotlinc_options"></a>

## kt_kotlinc_options

<pre>
load("@rules_kotlin//kotlin:core.bzl", "kt_kotlinc_options")

kt_kotlinc_options(<a href="#kt_kotlinc_options-name">name</a>, <a href="#kt_kotlinc_options-include_stdlibs">include_stdlibs</a>, <a href="#kt_kotlinc_options-java_parameters">java_parameters</a>, <a href="#kt_kotlinc_options-jvm_default">jvm_default</a>, <a href="#kt_kotlinc_options-jvm_target">jvm_target</a>, <a href="#kt_kotlinc_options-warn">warn</a>,
                   <a href="#kt_kotlinc_options-x_annotation_default_target">x_annotation_default_target</a>, <a href="#kt_kotlinc_options-x_assertions">x_assertions</a>, <a href="#kt_kotlinc_options-x_backend_threads">x_backend_threads</a>,
                   <a href="#kt_kotlinc_options-x_consistent_data_class_copy_visibility">x_consistent_data_class_copy_visibility</a>, <a href="#kt_kotlinc_options-x_context_parameters">x_context_parameters</a>, <a href="#kt_kotlinc_options-x_context_receivers">x_context_receivers</a>,
                   <a href="#kt_kotlinc_options-x_emit_jvm_type_annotations">x_emit_jvm_type_annotations</a>, <a href="#kt_kotlinc_options-x_enable_incremental_compilation">x_enable_incremental_compilation</a>, <a href="#kt_kotlinc_options-x_explicit_api_mode">x_explicit_api_mode</a>,
                   <a href="#kt_kotlinc_options-x_inline_classes">x_inline_classes</a>, <a href="#kt_kotlinc_options-x_jdk_release">x_jdk_release</a>, <a href="#kt_kotlinc_options-x_jspecify_annotations">x_jspecify_annotations</a>, <a href="#kt_kotlinc_options-x_jsr_305">x_jsr_305</a>, <a href="#kt_kotlinc_options-x_jvm_default">x_jvm_default</a>,
                   <a href="#kt_kotlinc_options-x_lambdas">x_lambdas</a>, <a href="#kt_kotlinc_options-x_multi_platform">x_multi_platform</a>, <a href="#kt_kotlinc_options-x_no_call_assertions">x_no_call_assertions</a>, <a href="#kt_kotlinc_options-x_no_optimize">x_no_optimize</a>,
                   <a href="#kt_kotlinc_options-x_no_param_assertions">x_no_param_assertions</a>, <a href="#kt_kotlinc_options-x_no_receiver_assertions">x_no_receiver_assertions</a>, <a href="#kt_kotlinc_options-x_no_source_debug_extension">x_no_source_debug_extension</a>,
                   <a href="#kt_kotlinc_options-x_nullability_annotations">x_nullability_annotations</a>, <a href="#kt_kotlinc_options-x_optin">x_optin</a>, <a href="#kt_kotlinc_options-x_report_perf">x_report_perf</a>, <a href="#kt_kotlinc_options-x_sam_conversions">x_sam_conversions</a>,
                   <a href="#kt_kotlinc_options-x_skip_prerelease_check">x_skip_prerelease_check</a>, <a href="#kt_kotlinc_options-x_suppress_version_warnings">x_suppress_version_warnings</a>, <a href="#kt_kotlinc_options-x_suppress_warning">x_suppress_warning</a>,
                   <a href="#kt_kotlinc_options-x_type_enhancement_improvements_strict_mode">x_type_enhancement_improvements_strict_mode</a>, <a href="#kt_kotlinc_options-x_use_fir_lt">x_use_fir_lt</a>, <a href="#kt_kotlinc_options-x_use_k2">x_use_k2</a>,
                   <a href="#kt_kotlinc_options-x_warning_level">x_warning_level</a>)
</pre>

Define kotlin compiler options.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="kt_kotlinc_options-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="kt_kotlinc_options-include_stdlibs"></a>include_stdlibs |  Don't automatically include the Kotlin standard libraries into the classpath (stdlib and reflect).   | String | optional |  `"all"`  |
| <a id="kt_kotlinc_options-java_parameters"></a>java_parameters |  Generate metadata for Java 1.8+ reflection on method parameters.   | Boolean | optional |  `False`  |
| <a id="kt_kotlinc_options-jvm_default"></a>jvm_default |  Specifies how to generate JVM default methods for interface declarations with bodies. This is the stable replacement for x_jvm_default (-Xjvm-default). Available from Kotlin 2.2. Options: - 'off': Don't pass the flag (uses compiler default, which is 'enable' in Kotlin 2.2+). - 'enable': Generate default methods and DefaultImpls for compatibility. - 'no-compatibility': Generate default methods without DefaultImpls classes. - 'disable': Do not generate JVM default methods (was the default up to Kotlin 2.1).   | String | optional |  `"off"`  |
| <a id="kt_kotlinc_options-jvm_target"></a>jvm_target |  The target version of the generated JVM bytecode   | String | optional |  `""`  |
| <a id="kt_kotlinc_options-warn"></a>warn |  Control warning behaviour.   | String | optional |  `"report"`  |
| <a id="kt_kotlinc_options-x_annotation_default_target"></a>x_annotation_default_target |  Change the default annotation targets for constructor properties: -Xannotation-default-target=first-only: use the first of the following allowed targets: '@param:', '@property:', '@field:'; -Xannotation-default-target=first-only-warn: same as first-only, and raise warnings when both '@param:' and either '@property:' or '@field:' are allowed; -Xannotation-default-target=param-property: use '@param:' target if applicable, and also use the first of either '@property:' or '@field:'; default: 'first-only-warn' in language version 2.2+, 'first-only' in version 2.1 and before.   | String | optional |  `"off"`  |
| <a id="kt_kotlinc_options-x_assertions"></a>x_assertions |  Configures how assertions are handled. The 'jvm' option enables assertions in JVM code.   | String | optional |  `""`  |
| <a id="kt_kotlinc_options-x_backend_threads"></a>x_backend_threads |  When using the IR backend, run lowerings by file in N parallel threads. 0 means use a thread per processor core. Default value is 1.   | Integer | optional |  `1`  |
| <a id="kt_kotlinc_options-x_consistent_data_class_copy_visibility"></a>x_consistent_data_class_copy_visibility |  The effect of this compiler flag is the same as applying @ConsistentCopyVisibility annotation to all data classes in the module. See https://youtrack.jetbrains.com/issue/KT-11914   | Boolean | optional |  `False`  |
| <a id="kt_kotlinc_options-x_context_parameters"></a>x_context_parameters |  Enable experimental context parameters (Kotlin 2.2+).   | Boolean | optional |  `False`  |
| <a id="kt_kotlinc_options-x_context_receivers"></a>x_context_receivers |  Enable experimental context receivers.   | Boolean | optional |  `False`  |
| <a id="kt_kotlinc_options-x_emit_jvm_type_annotations"></a>x_emit_jvm_type_annotations |  Basic support for type annotations in JVM bytecode.   | Boolean | optional |  `False`  |
| <a id="kt_kotlinc_options-x_enable_incremental_compilation"></a>x_enable_incremental_compilation |  Enable incremental compilation   | Boolean | optional |  `False`  |
| <a id="kt_kotlinc_options-x_explicit_api_mode"></a>x_explicit_api_mode |  Enable explicit API mode for Kotlin libraries.   | String | optional |  `"off"`  |
| <a id="kt_kotlinc_options-x_inline_classes"></a>x_inline_classes |  Enable experimental inline classes   | Boolean | optional |  `False`  |
| <a id="kt_kotlinc_options-x_jdk_release"></a>x_jdk_release |  Compile against the specified JDK API version, similarly to javac's '-release'. This requires JDK 9 or newer. The supported versions depend on the JDK used; for JDK 25+, the supported versions are 1.8 and 9-25. This also sets the value of '-jvm-target' to be equal to the selected JDK version.   | String | optional |  `""`  |
| <a id="kt_kotlinc_options-x_jspecify_annotations"></a>x_jspecify_annotations |  Controls how JSpecify annotations are treated. Options are 'default', 'ignore', 'warn', and 'strict'.   | String | optional |  `""`  |
| <a id="kt_kotlinc_options-x_jsr_305"></a>x_jsr_305 |  Specifies how to handle JSR-305 annotations in Kotlin code. Options are 'default', 'ignore', 'warn', and 'strict'.   | String | optional |  `""`  |
| <a id="kt_kotlinc_options-x_jvm_default"></a>x_jvm_default |  DEPRECATED: Use jvm_default instead for Kotlin 2.2+. Specifies that a JVM default method should be generated for non-abstract Kotlin interface member. Migration to jvm_default: - x_jvm_default=all -> jvm_default=no-compatibility - x_jvm_default=all-compatibility -> jvm_default=enable - x_jvm_default=disable -> jvm_default=disable   | String | optional |  `"off"`  |
| <a id="kt_kotlinc_options-x_lambdas"></a>x_lambdas |  Change codegen behavior of lambdas. Defaults to "class" (anonymous inner classes), which differs from Kotlin 2.x/Gradle default of "indy" (invokedynamic). Set to "indy" for Gradle-compatible bytecode.   | String | optional |  `"class"`  |
| <a id="kt_kotlinc_options-x_multi_platform"></a>x_multi_platform |  Enable experimental language support for multi-platform projects   | Boolean | optional |  `False`  |
| <a id="kt_kotlinc_options-x_no_call_assertions"></a>x_no_call_assertions |  Don't generate not-null assertions for arguments of platform types   | Boolean | optional |  `False`  |
| <a id="kt_kotlinc_options-x_no_optimize"></a>x_no_optimize |  Disable optimizations   | Boolean | optional |  `False`  |
| <a id="kt_kotlinc_options-x_no_param_assertions"></a>x_no_param_assertions |  Don't generate not-null assertions on parameters of methods accessible from Java   | Boolean | optional |  `False`  |
| <a id="kt_kotlinc_options-x_no_receiver_assertions"></a>x_no_receiver_assertions |  Don't generate not-null assertion for extension receiver arguments of platform types   | Boolean | optional |  `False`  |
| <a id="kt_kotlinc_options-x_no_source_debug_extension"></a>x_no_source_debug_extension |  Do not generate @kotlin.jvm.internal.SourceDebugExtension annotation on a class with the copy of SMAP   | Boolean | optional |  `False`  |
| <a id="kt_kotlinc_options-x_nullability_annotations"></a>x_nullability_annotations |  Configure how Kotlin treats nullability annotations on Java types, per annotation class. Map the fully-qualified annotation class name (prefixed with '@') to a mode: 'ignore', 'warn', or 'strict'. Ex: {'@jakarta.annotation.Nullable': 'strict', '@jakarta.annotation.Nonnull': 'strict'}. Use x_jsr305 for javax.annotation (JSR-305) and x_jspecify_annotations for org.jspecify.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="kt_kotlinc_options-x_optin"></a>x_optin |  Define APIs to opt-in to.   | List of strings | optional |  `[]`  |
| <a id="kt_kotlinc_options-x_report_perf"></a>x_report_perf |  Report detailed performance statistics   | Boolean | optional |  `False`  |
| <a id="kt_kotlinc_options-x_sam_conversions"></a>x_sam_conversions |  Change codegen behavior of SAM/functional interfaces. Defaults to "class" (anonymous inner classes), which differs from Kotlin 2.x/Gradle default of "indy" (invokedynamic). Set to "indy" for Gradle-compatible bytecode.   | String | optional |  `"class"`  |
| <a id="kt_kotlinc_options-x_skip_prerelease_check"></a>x_skip_prerelease_check |  Suppress errors thrown when using pre-release classes.   | Boolean | optional |  `False`  |
| <a id="kt_kotlinc_options-x_suppress_version_warnings"></a>x_suppress_version_warnings |  Suppress warnings about outdated, inconsistent, or experimental language or API versions.   | Boolean | optional |  `False`  |
| <a id="kt_kotlinc_options-x_suppress_warning"></a>x_suppress_warning |  Suppress specific warnings globally   | List of strings | optional |  `[]`  |
| <a id="kt_kotlinc_options-x_type_enhancement_improvements_strict_mode"></a>x_type_enhancement_improvements_strict_mode |  Enables strict mode for type enhancement improvements, enforcing stricter type checking and enhancements.   | Boolean | optional |  `False`  |
| <a id="kt_kotlinc_options-x_use_fir_lt"></a>x_use_fir_lt |  Compile using LightTree parser with Front-end IR. Warning: this feature is far from being production-ready   | Boolean | optional |  `False`  |
| <a id="kt_kotlinc_options-x_use_k2"></a>x_use_k2 |  Compile using experimental K2. K2 is a new compiler pipeline, no compatibility guarantees are yet provided   | Boolean | optional |  `False`  |
| <a id="kt_kotlinc_options-x_warning_level"></a>x_warning_level |  Suppress specific warnings globally. Ex: 'OPTION': '(error\|warning\|disabled)'   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |


<a id="kt_ksp_plugin"></a>

## kt_ksp_plugin

<pre>
load("@rules_kotlin//kotlin:core.bzl", "kt_ksp_plugin")

kt_ksp_plugin(<a href="#kt_ksp_plugin-name">name</a>, <a href="#kt_ksp_plugin-deps">deps</a>, <a href="#kt_ksp_plugin-generates_java">generates_java</a>, <a href="#kt_ksp_plugin-options">options</a>, <a href="#kt_ksp_plugin-processor_class">processor_class</a>, <a href="#kt_ksp_plugin-target_embedded_compiler">target_embedded_compiler</a>)
</pre>

Define a KSP plugin for the Kotlin compiler to run. The plugin can then be referenced in the `plugins` attribute
of the `kt_jvm_*` and `kt_android_*` rules.

An example can be found under `//examples/ksp`:

```bzl
kt_ksp_plugin(
    name = "moshi-kotlin-codegen",
    processor_class = "com.squareup.moshi.kotlin.codegen.ksp.JsonClassSymbolProcessorProvider",
    deps = [
        "@maven//:com_squareup_moshi_moshi",
        "@maven//:com_squareup_moshi_moshi_kotlin",
        "@maven//:com_squareup_moshi_moshi_kotlin_codegen",
    ],
)

kt_jvm_library(
    name = "lib",
    srcs = glob(["*.kt"]),
    plugins = ["//:moshi-kotlin-codegen"],
)
```

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="kt_ksp_plugin-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="kt_ksp_plugin-deps"></a>deps |  The list of libraries to be added to the compiler's plugin classpath   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="kt_ksp_plugin-generates_java"></a>generates_java |  Runs Java compilation action for plugin generating Java output.   | Boolean | optional |  `False`  |
| <a id="kt_ksp_plugin-options"></a>options |  Processor options passed to the KSP processor via SymbolProcessorEnvironment.options. Each entry is a key-value pair available to the processor at processing time.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="kt_ksp_plugin-processor_class"></a>processor_class |  The fully qualified class name that the Java compiler uses as an entry point to the annotation processor.   | String | required |  |
| <a id="kt_ksp_plugin-target_embedded_compiler"></a>target_embedded_compiler |  Plugin was compiled against the embeddable kotlin compiler. These plugins expect shaded kotlinc dependencies, and will fail when running against a non-embeddable compiler.   | Boolean | optional |  `False`  |


<a id="kt_plugin_cfg"></a>

## kt_plugin_cfg

<pre>
load("@rules_kotlin//kotlin:core.bzl", "kt_plugin_cfg")

kt_plugin_cfg(<a href="#kt_plugin_cfg-name">name</a>, <a href="#kt_plugin_cfg-deps">deps</a>, <a href="#kt_plugin_cfg-data">data</a>, <a href="#kt_plugin_cfg-options">options</a>, <a href="#kt_plugin_cfg-plugin">plugin</a>)
</pre>

Configurations for kt_compiler_plugin.

This allows setting options and dependencies independently from the initial plugin definition.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="kt_plugin_cfg-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="kt_plugin_cfg-deps"></a>deps |  Dependencies for this configuration.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="kt_plugin_cfg-data"></a>data |  The list of data files to be used by compiler's plugin   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="kt_plugin_cfg-options"></a>options |  A dictionary of flag to values to be used as plugin configuration options.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> List of strings</a> | optional |  `{}`  |
| <a id="kt_plugin_cfg-plugin"></a>plugin |  The plugin to associate with this configuration   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |


<a id="define_kt_toolchain"></a>

## define_kt_toolchain

<pre>
load("@rules_kotlin//kotlin:core.bzl", "define_kt_toolchain")

define_kt_toolchain(<a href="#define_kt_toolchain-name">name</a>, <a href="#define_kt_toolchain-language_version">language_version</a>, <a href="#define_kt_toolchain-api_version">api_version</a>, <a href="#define_kt_toolchain-jvm_target">jvm_target</a>, <a href="#define_kt_toolchain-experimental_use_abi_jars">experimental_use_abi_jars</a>,
                    <a href="#define_kt_toolchain-experimental_treat_internal_as_private_in_abi_jars">experimental_treat_internal_as_private_in_abi_jars</a>,
                    <a href="#define_kt_toolchain-experimental_remove_private_classes_in_abi_jars">experimental_remove_private_classes_in_abi_jars</a>,
                    <a href="#define_kt_toolchain-experimental_remove_debug_info_in_abi_jars">experimental_remove_debug_info_in_abi_jars</a>, <a href="#define_kt_toolchain-experimental_strict_kotlin_deps">experimental_strict_kotlin_deps</a>,
                    <a href="#define_kt_toolchain-experimental_report_unused_deps">experimental_report_unused_deps</a>, <a href="#define_kt_toolchain-experimental_reduce_classpath_mode">experimental_reduce_classpath_mode</a>,
                    <a href="#define_kt_toolchain-experimental_multiplex_workers">experimental_multiplex_workers</a>, <a href="#define_kt_toolchain-experimental_multiplex_sandboxing">experimental_multiplex_sandboxing</a>,
                    <a href="#define_kt_toolchain-supports_path_mapping">supports_path_mapping</a>, <a href="#define_kt_toolchain-experimental_build_tools_api">experimental_build_tools_api</a>, <a href="#define_kt_toolchain-javac_options">javac_options</a>,
                    <a href="#define_kt_toolchain-kotlinc_options">kotlinc_options</a>, <a href="#define_kt_toolchain-jvm_stdlibs">jvm_stdlibs</a>, <a href="#define_kt_toolchain-jvm_runtime">jvm_runtime</a>, <a href="#define_kt_toolchain-jacocorunner">jacocorunner</a>, <a href="#define_kt_toolchain-build_tools_impl">build_tools_impl</a>,
                    <a href="#define_kt_toolchain-jvm_abi_gen">jvm_abi_gen</a>, <a href="#define_kt_toolchain-skip_code_gen">skip_code_gen</a>, <a href="#define_kt_toolchain-jdeps_gen">jdeps_gen</a>, <a href="#define_kt_toolchain-kapt">kapt</a>, <a href="#define_kt_toolchain-exec_compatible_with">exec_compatible_with</a>,
                    <a href="#define_kt_toolchain-target_compatible_with">target_compatible_with</a>, <a href="#define_kt_toolchain-target_settings">target_settings</a>)
</pre>

Define the Kotlin toolchain.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="define_kt_toolchain-name"></a>name |  <p align="center"> - </p>   |  none |
| <a id="define_kt_toolchain-language_version"></a>language_version |  <p align="center"> - </p>   |  `None` |
| <a id="define_kt_toolchain-api_version"></a>api_version |  <p align="center"> - </p>   |  `None` |
| <a id="define_kt_toolchain-jvm_target"></a>jvm_target |  <p align="center"> - </p>   |  `None` |
| <a id="define_kt_toolchain-experimental_use_abi_jars"></a>experimental_use_abi_jars |  <p align="center"> - </p>   |  `False` |
| <a id="define_kt_toolchain-experimental_treat_internal_as_private_in_abi_jars"></a>experimental_treat_internal_as_private_in_abi_jars |  <p align="center"> - </p>   |  `False` |
| <a id="define_kt_toolchain-experimental_remove_private_classes_in_abi_jars"></a>experimental_remove_private_classes_in_abi_jars |  <p align="center"> - </p>   |  `False` |
| <a id="define_kt_toolchain-experimental_remove_debug_info_in_abi_jars"></a>experimental_remove_debug_info_in_abi_jars |  <p align="center"> - </p>   |  `False` |
| <a id="define_kt_toolchain-experimental_strict_kotlin_deps"></a>experimental_strict_kotlin_deps |  <p align="center"> - </p>   |  `None` |
| <a id="define_kt_toolchain-experimental_report_unused_deps"></a>experimental_report_unused_deps |  <p align="center"> - </p>   |  `None` |
| <a id="define_kt_toolchain-experimental_reduce_classpath_mode"></a>experimental_reduce_classpath_mode |  <p align="center"> - </p>   |  `None` |
| <a id="define_kt_toolchain-experimental_multiplex_workers"></a>experimental_multiplex_workers |  <p align="center"> - </p>   |  `None` |
| <a id="define_kt_toolchain-experimental_multiplex_sandboxing"></a>experimental_multiplex_sandboxing |  <p align="center"> - </p>   |  `None` |
| <a id="define_kt_toolchain-supports_path_mapping"></a>supports_path_mapping |  <p align="center"> - </p>   |  `None` |
| <a id="define_kt_toolchain-experimental_build_tools_api"></a>experimental_build_tools_api |  <p align="center"> - </p>   |  `None` |
| <a id="define_kt_toolchain-javac_options"></a>javac_options |  <p align="center"> - </p>   |  `Label("@rules_kotlin//kotlin/internal:default_javac_options")` |
| <a id="define_kt_toolchain-kotlinc_options"></a>kotlinc_options |  <p align="center"> - </p>   |  `Label("@rules_kotlin//kotlin/internal:default_kotlinc_options")` |
| <a id="define_kt_toolchain-jvm_stdlibs"></a>jvm_stdlibs |  <p align="center"> - </p>   |  `None` |
| <a id="define_kt_toolchain-jvm_runtime"></a>jvm_runtime |  <p align="center"> - </p>   |  `None` |
| <a id="define_kt_toolchain-jacocorunner"></a>jacocorunner |  <p align="center"> - </p>   |  `None` |
| <a id="define_kt_toolchain-build_tools_impl"></a>build_tools_impl |  <p align="center"> - </p>   |  `None` |
| <a id="define_kt_toolchain-jvm_abi_gen"></a>jvm_abi_gen |  <p align="center"> - </p>   |  `None` |
| <a id="define_kt_toolchain-skip_code_gen"></a>skip_code_gen |  <p align="center"> - </p>   |  `None` |
| <a id="define_kt_toolchain-jdeps_gen"></a>jdeps_gen |  <p align="center"> - </p>   |  `None` |
| <a id="define_kt_toolchain-kapt"></a>kapt |  <p align="center"> - </p>   |  `None` |
| <a id="define_kt_toolchain-exec_compatible_with"></a>exec_compatible_with |  <p align="center"> - </p>   |  `None` |
| <a id="define_kt_toolchain-target_compatible_with"></a>target_compatible_with |  <p align="center"> - </p>   |  `None` |
| <a id="define_kt_toolchain-target_settings"></a>target_settings |  <p align="center"> - </p>   |  `None` |


