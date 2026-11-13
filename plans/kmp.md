# KMP/Native Support for rules_kotlin

## Overview

This has been [tried](https://github.com/bazelbuild/rules_kotlin/pull/1351), and exists as a [separate effort](https://github.com/kitterion/rules_kotlin_native). Here be monsters.

Following is a rough series of steps to get kmp into rules_kotlin. We might consider just trying to support interop with the existing rules; partially for maintenance; and partially because it's going to be a lotta fun. 

---

## Phase 1: Toolchain Foundation

- **Compiler distribution management.** A new repository rule downloads and registers the Kotlin Native distribution for each supported host platform. Ideally, this can be files, rather than directories. Unfortunately, the list of files turns out to be non-trivial.

- **Toolchain registration.** Each host-target combination (e.g., building for macOS on Linux) requires its own declared toolchain with explicit platform constraints. Obviously, it's easier to start with one toolchain and take it through to the end.

- **Blocking non-hermetic downloads.** Out of the box, the Native compiler fetches Clang, LLVM, and sysroots at compile time. This must be disabled and replaced with pre-fetched, hash-verified artifacts. [This will be painful.](https://github.com/bazelbuild/rules_kotlin/pull/1351#discussion_r2211504236)

- **Build Tools API (BTAPI).** Required for long term maintenance. It's not worth undertaking the effort while that is pending.

---

## Phase 2: Rules

- **Klib as the intermediate format.** It was noted in the SOC pr: klibs are not truly platform-independent. It appears the compiler embeds platform-specific metadata and ABI information, so a klib compiled for `macosArm64` is not interchangeable with one compiled for `linuxX64`. This will be very fun if it's (still?) true.
- Need to add a `kt_native_library` rule produces klibs and propagates them transitively through a provider. `klib` is not (yet) the ideal intermediate format, so we've still got jars running about. We could extend the current provider.

- **Remote caching and reproducibility.** Klib output must be reproducible across machines, which requires that embedded paths are relative rather than absolute. Explicit stdlib management — passing the standard library as a declared input -- would simplify a lot of issues.

- **Compiler cache isolation.** The Native compiler maintains an internal incremental cache. In a Bazel worker context this cache must be redirected to a sandboxed location rather than the (read-only) external repository directory. Which opens up the can of worms around incremental compilation adn bazel. Potentially, we could manage it via a persistent worker -- but I expect that would have some drawbacks, especially in the RBE space. 

---

## Phase 3: Dependency Resolution

The Gradle resolver can be used for this without changes. Amper may offer improvements (being more portable than the Gradle resolver is a definite improvement.) `kotlin_native_library` would need to be added to `rules_jvm_external`.

---

## Cross-Compilation

Is going to be fun for the user. Bazel is not known for making it simple, providing a set of platforms would ease the burden; but it's still awkward.

---

## Lessons Learned

Previous attempts surfaced several constraints worth repeating here:

- `konan.home` must be passed as a system property so the compiler can locate its native components inside the Bazel sandbox. The distribution should be exposed as a `directory` artifact (bazel-skylib) rather than via `copy_to_directory`, which forces action inputs to enumerate every file and is hostile to RBE.

- `-Xoverride-konan-properties=airplaneMode=true` disables the compiler's runtime download behavior. Without this flag, cold builds will attempt outbound network calls.

- `-Xklib-relative-path-base` and `-Xdebug-prefix-map` are required for reproducible klib output and remote cache hits. `-nostdlib` + `-no-default-libs` with an explicit `-library` are suggested.

- `-Xauto-cache-dir` / `-Xauto-cache-from` redirect the compiler's internal cache into the working directory, preventing writes into the read-only external repository. Some compiler versions also create `klib/cache/<platform>STATIC` entries in the distribution directory; a marker file in the repository rule can satisfy this without real content.

- `toolchains_llvm` or `konan.properties` parsing can be used to map the compiler's native tool dependencies to Bazel-managed binaries.
