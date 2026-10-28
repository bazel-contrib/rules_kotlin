# Announcements and Notable Changes

| Date&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | News                    |
|:-----------------------------------------------------------------------------------------------------------------|-------------------------|
| Oct 28, 2026 | Prebuilt jars are no longer part of the release archive: they are downloaded from the `rules_kotlin_jars.tar.gz` release asset when Kotlin code is compiled. Offline setups need to provide that asset as well, e.g. via `--distdir` |
| Oct 19, 2026 | The Build Tools API implementation record requires the checksum of `kotlin-tooling-core`: custom `btapi_impl_version` records must add `tooling_core_sha256` |
| Mar 6, 2026 | Drop support for Java 8 |
| May 26, 2022  | Released version [v1.6.0-RC-2](https://github.com/bazelbuild/rules_kotlin/releases/tag/v1.6.0-RC-2). |
| April 27, 2022  | Released version [1.6.0-RC1](https://github.com/bazelbuild/rules_kotlin/releases/tag/1.6.0-RC-1). |
| Feb 2, 2022  | Released version [1.5.0](https://github.com/bazelbuild/rules_kotlin/releases/tag/v1.5.0). |
| Oct 01, 2021 | Released version [1.5.0-beta-4](https://github.com/bazelbuild/rules_kotlin/releases/tag/v1.5.0-beta-4). |
| Jul 27, 2021 | Released version [1.5.0-beta-3](https://github.com/bazelbuild/rules_kotlin/releases/tag/v1.5.0-beta-3). |
| Jul 13, 2021 | Released version [1.5.0-beta-2](https://github.com/bazelbuild/rules_kotlin/releases/tag/v1.5.0-beta-2). |
| Dec 30, 2020 | Released version [1.5.0-alpha-2](https://github.com/bazelbuild/rules_kotlin/releases/tag/v1.5.0-alpha-2). |
| Dec 3, 2020  | Released version [1.5.0-alpha-1](https://github.com/bazelbuild/rules_kotlin/releases/tag/v1.5.0-alpha-1). |
| Nov 16, 2020 | Released version [1.4.0-rc4](https://github.com/bazelbuild/rules_kotlin/releases/tag/legacy-1.4.0-rc4). |
| May 9, 2020  | Released version [1.4.0-rc3](https://github.com/bazelbuild/rules_kotlin/releases/tag/legacy-1.4.0-rc3). |
| May 7, 2020  | Released version [1.4.0-rc2](https://github.com/bazelbuild/rules_kotlin/releases/tag/legacy-1.4.0-rc2). |
| May 1, 2020  | Released version [1.4.0-rc1](https://github.com/bazelbuild/rules_kotlin/releases/tag/legacy-1.4.0-rc1). |
| Apr 28, 2020 | Fix missing plugin inputs (#318) |
| Apr 7, 2020  | Fix non-reproducible archives (hermeticity, helps remote builds) (#304) |
| Apr 6, 2020  | Support for Kotlin compiler plugins via the kt_compiler_plugin (#308) |
| Apr 3, 2020  | Correctness and hermeticity fixes (#298) |
| Mar 2, 2020  | Performance and correctness fixes (#291) |
| Feb 28, 2020 | Performance fixes (#292) |
| Feb 24, 2020 | Performance fixes and code cleanup (#287, #288) |
| Feb 24, 2020 | Filter non-kotlin code out of generated sources (#263) |
| Feb 18, 2020 | Only propagate srcjar if it isn't the default empty jar added by intellij aspect (#276) |
| Feb 18, 2020 | Requires release binary for regular use, or special instructions for local development use (#279 |
| Feb 14, 2020 | Allow resources to be in a kotlin directory (#268) |
| Feb 9, 2020  | Released version [1.3.0](https://github.com/bazelbuild/rules_kotlin/releases/tag/legacy-1.3.0). (No changes from `legacy-1.3.0-rc4`) | 
| Jan 15, 2020 | Add InteliiJ aspect info (Improved intellij support) (#242) |
| Jan 15, 2019 | Released version [1.3.0-rc4](https://github.com/bazelbuild/rules_kotlin/releases/tag/legacy-1.3.0-rc4). | 
| Jan 15, 2019 | Bug fixes and tweaks (#255, #257). | 
| Dec 6, 2019  | Released version [1.3.0-rc3](https://github.com/bazelbuild/rules_kotlin/releases/tag/legacy-1.3.0-rc3). | 
| Dec 6, 2019  | Add support for later java versions as target platforms (#236). | 
| Dec 5, 2019  | Released version [1.3.0-rc2](https://github.com/bazelbuild/rules_kotlin/releases/tag/legacy-1.3.0-rc2). | 
| Dec 5, 2019  | Fix for problem with jdeps generation (#235). | 
| Oct 29, 2019 | Released version [1.3.0-rc1](https://github.com/bazelbuild/rules_kotlin/releases/tag/legacy-1.3.0-rc1). | 
| Oct 28, 2019 | Fix various regressions (#217, #221, #222).  | 
| Oct 28, 2019 | Improve file handling for maven-packaged JS jars in `kt_js_import()` (#223).  | 
| Oct 15, 2019 | Infer the test class from the test name in `kt_jvm_unit_test()` (#209).  | 
| Oct 5, 2019  | [cgruber/rules_kotlin](github.com/cgruber/rules_kotlin) upstreamed into this repository.  | 
| Oct 2, 2019  | Fixes to bazel 1.0.0 (as of rc4). Release (cgruber) `legacy_modded-1_0_0-01` | 
| Oct 2, 2019  | NOTE: (cgruber) `legacy_modded-1_0_0-01` will be the last release on this fork, prior to upstreaming to github.com/bazelbuild/rules_kotlin.  For any further releases after this one, please look at that repository. | 
| Oct 2, 2019  | Fixes to bazel 1.0.0 (as of rc4). Release (cgruber) `legacy_modded-1_0_0-01` | 
| Sep 27, 2019 | Fixes to support latest versions and bring upstream in, release (cgruber) `legacy_modded-0_29_0-01` | 
| Jun 20, 2019 | Fix to support 0.27.0 and release of (cgruber) `legacy_modded-0_26_1-02`<br>Serious reconsideration of the version naming scheme... | 
| Jun 12, 2019 | Kotlin 1.3 support, and release of (cgruber) `legacy_modded-0_26_1-01` | 
| Jun 11, 2019 | Fix to kotlin worker to allow modern dagger to be used in kapt. (worker was leaking its dagger dep) | 
| May 17, 2019 | More changes from upstream (mostly fixes for bazel version bump) and releases from the fork | 
| Apr 1, 2019  | [Roadmap](https://github.com/bazelbuild/rules_kotlin/blob/master/ROADMAP.md) for rules_kotlin published by the Google team.  The `cgruber` fork will continue until the legacy branch in the parent repo can be updated (or no one needs the fork) | 
| Feb 20, 2019 | [Future directions](https://github.com/bazelbuild/rules_kotlin/issues/174) of rules_kotlin. | 
| Oct 24, 2018 | Christian Gruber forks the main kotlin rules repository, adding in two fixes. | 
| Aug 14, 2018 | Js support. No documentation yet but see the nested example workspace `examples/node`. | 
| Aug 14, 2018 | Android support. No documentation but it's a simple integration. see `kotlin/internal/jvm/android.bzl`. | 
| Jun 29, 2018 | The commits from this date forward are compatible with bazel `>=0.14`. JDK9 host issues were fixed as well some other deprecations. I recommend skipping `0.15.0` if you   are on a Mac.  | 
| May 25, 2018 | Test "friend" support. A single friend dep can be provided to `kt_jvm_test` which allows the test to access internal members of the module under test. | 
| Feb 15, 2018 | Toolchains for the JVM rules. Currently this allow tweaking The JVM target (bytecode level), API and Language levels. Coroutines, enabled by default. | 
| Feb 9, 2018  | Annotation processing (kapt) support
| Feb 5, 2018  | JVM rule name change:</b> the prefix has changed from `kotlin_` to `kt_jvm_`.

For fixes and more detail, please view the [list of pull requests](https://github.com/bazelbuild/rules_kotlin/pulls?q=is%3Apr+is%3Aclosed).
