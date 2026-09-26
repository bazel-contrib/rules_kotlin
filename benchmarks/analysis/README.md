# Starlark analysis measurements — 2026-09-26

Two optimizations were retained, relative to `10caa6d6`:

- `5ed3668c`: keep compile classpaths as nested depsets unless associate ABI replacement requires filtering.
- `bf2c26ca`: avoid an intermediate Kotlin `JavaInfo` whose dependency metadata is discarded, and create the Kotlin-to-Java stub provider only when Java compilation needs it.

These ideas were already present in the locally available proposal `c6d03d70`. They were ported separately to the current checkout, measured, tested, and committed independently. No remote changes were made.

The gains below apply to analysis of large Kotlin dependency graphs. They are not end-to-end Kotlin compiler speedups. The repository's own smaller Kotlin graphs showed no measurable overall improvement.

**Method**

The measurements follow Bazel's [rule performance guidance](https://bazel.build/rules/performance), [build performance guidance](https://bazel.build/advanced/performance/build-performance-breakdown), and [JSON trace documentation](https://bazel.build/advanced/performance/json-trace-profile):

- Bazel 9.2.0; macOS 26.6.2, Mac16,13, 10 CPUs, 32 GiB RAM. Dedicated persistent server, `-Xmx4g`, `--jobs=8`, `--loading_phase_threads=8`; no concurrent builds during measurements.
- Use `build --nobuild` to exclude execution. Run `clean` on the dedicated output base before each analysis, preserving the JVM and downloaded repositories. Dependencies and filesystem caches were warmed; final confirmation followed the exploratory runs on the same long-lived JVM. These are clean-analysis measurements on a warm server, not JVM startup benchmarks.
- Keep fixtures, test definitions, dependencies, flags and absolute checkout path identical. Alternate only the two implementation files between original and optimized versions. Balanced ABBA/BAAB ordering reduces drift; discard warmup samples. Capture JSON traces and BEP timing, configured-target, package and action counts for every run.
- Measure retained heap after GC. Separately collect phase-end heap using `--memory_profile --memory_profile_stable_heap_parameters=2,0`; exclude these forced-GC runs from timing comparisons. Capture Starlark pprof and server JFR CPU profiles separately, also excluded from timing comparisons.
- Report cached no-op analysis separately. Full source builds/tests and an actual example execution validate behavior outside analysis.

**Combined results**

Medians; eight measurements per variant on each scale fixture, 24 per variant on `//src/...`. Lower is better.

| Workload | Analysis before → after | Change | Bazel CPU before → after | Change |
| --- | --- | --- | --- | --- |
| Shared classpath: 600 Kotlin consumers, 1,000 imported jars | 616.5 → 546.0 ms | **−11.4%** | 2,580.5 → 1,865.5 ms | **−27.7%** |
| Layered: 1,200 Kotlin libraries, 100 layers × 12 libraries | 663.0 → 572.5 ms | **−13.7%** | 2,770.0 → 1,957.5 ms | **−29.3%** |
| Repository `//src/...` | 1,046.5 → 1,053.0 ms | +0.6% | 6,840.5 → 6,821.5 ms | −0.3% |

Timing variation supports the scale-fixture gains: all eight optimized analysis samples were faster than all eight baseline samples on each fixture. Paired-bootstrap 95% intervals for analysis-time reduction were 11.1–12.5% (shared classpath), 12.1–15.0% (layered), and approximately −2% to +1% (repository). The repository interval includes both faster and slower outcomes; there is no detectable overall change there. These intervals describe this machine and workload, not production guarantees.

Bootstrap calculation: for each workload, select its non-warm `confirm-` rows in CSV order and pair non-overlapping adjacent opposite variants. The repository includes all 24 pairs (run suffixes 2–17 and 100–131). Compute `100 * (1 - after / before)` per pair, then resample pairs 10,000 times with Python 3.14.7 `random.Random(17).choices` (reset the generator per workload) and take the median each time. Sort the 10,000 bootstrap medians and use zero-based entries 250 and 9749 as the approximate 95% bounds. This paired statistic differs slightly from the ratio of the two medians in the table.

Separate phase-end memory measurements, three runs per variant:

| Workload | Retained analysis heap before → after | Saved |
| --- | --- | --- |
| Shared classpath | 100.011 → 97.974 MiB | **2.037 MiB** |
| Layered | 101.751 → 99.215 MiB | **2.536 MiB** |

These are retained JVM heap measurements after GC, not process RSS or peak allocation. Absolute heap size depends on server/cache history. Cached repository no-op analysis remained **3 ms** median in both versions (six runs each); no targets were reconfigured.

Configured target / action / package counts were identical between variants:

- Shared classpath: 11,100 / 3,382 / 203.
- Layered: 9,698 / 6,377 / 203.
- Repository: 87,848 / 9,215 / 352.

**Experiments**

Each exploratory comparison used six measurements per variant. Its timings are not directly comparable to the final table because JVM warmup and fixture development preceded final confirmation.

| Experiment | Result and decision |
| --- | --- |
| Nested classpaths | Analysis −13.3% / −7.9%, CPU −15.9% / −21.8% on shared/layered graphs. Retained. Starlark profiling identified `_jvm_deps`, `depset`, and membership checks as a substantial hot path. |
| Remove discarded JavaInfo work, on top of nested classpaths | Analysis −2.3% / −5.5%, CPU −6.9% / −8.0%. No retained-heap improvement. Retained: removes redundant work with a smaller implementation. |
| Collect plugin metadata in one pass | On 300 targets with 1,000 direct dependencies each: analysis −1.9%, CPU **+2.5%**, heap unchanged. Rejected; added collector code was not justified. |
| Cache default compiler flags on the toolchain | Layered graph: analysis −2.3%, CPU −5.9%, heap unchanged. Rejected; the small elapsed-time gain did not justify new toolchain fields and compatibility handling. |

Additional inspection found redundant default providers in the separate core CLI binary implementation and launcher classpath flattening. These were not changed: the retained changes address measured common JVM-rule costs; the other paths need their own representative workload before altering them.

**Regression checks**

- All **182** source test targets passed, including new classpath ordering/dedup coverage and KAPT+KSP / mixed-Java annotation-processing metadata checks.
- Full `bazel build //src/... //:rules_kotlin_release` passed.
- `examples/trivial` built against the local checkout and its `test_execution` passed with `--nocache_test_results`.
- Normalized `aquery` comparison of mixed KAPT/KSP targets covered **576 actions**: no actions added or removed; identical arguments, parameter files, input/output paths, environment and file-write contents. Five Kotlin/KAPT/KSP action keys changed with the depset representation, so adopting this change can cause a one-time cache miss for affected actions.
- Buildifier and whitespace checks passed. An independent review found no semantic issues in the retained changes.

**Reproducing**

The fixtures are deliberately analysis-only. They use placeholder jar outputs; do not execute them as application builds. All fixture targets are tagged `manual`.

`measure.py` measures the currently checked-out implementation. It changes no sources. It clears only its dedicated `OUTPUT/server` Bazel output base, retaining profiles and logs alongside it. Use a fresh label per invocation to avoid overwriting profiles.

```sh
python3 benchmarks/analysis/measure.py //benchmarks/analysis:wide \
  --label baseline-wide --output /tmp/rules-kotlin-analysis --warmups 20 --runs 8
python3 benchmarks/analysis/measure.py //benchmarks/analysis:layered \
  --label optimized-layered --output /tmp/rules-kotlin-analysis --warmups 2 --runs 8
```

For an A/B comparison, preserve the fixtures/tests from this commit and vary only `kotlin/internal/jvm/jvm_deps.bzl` and `kotlin/internal/jvm/compile.bzl` between `10caa6d6` and `bf2c26ca`. Warm both variants, then alternate in balanced ABBA blocks using `--warmups 0 --runs 1` and unique labels. Keep the same checkout and output directory for both. Inspect individual runs for warmup trends before accepting a timing comparison. Use `//src/...` for the repository workload and `//benchmarks/analysis:fanin` for the direct-dependency stress case.

Add `--memory` for separate forced-GC measurements; add `--diagnostic` for pprof/JFR capture. Do not mix those samples into timing comparisons. Standard JSON tracing remains enabled in both timing variants. The runner's memory/CPU profile collection was smoke-tested on the final checkout.

[results.csv](results.csv) contains all 186 exploratory/confirmation/profile invocations plus 12 no-op samples. Select `confirm-` rows, excluding `warm`, for the timing table; select `memory-` for the memory table. Diagnostic, setup and warmup rows are retained for transparency, not counted as timed confirmations. Full raw profiles, BEP files and validation logs from this run are retained locally in `/tmp/rules-kotlin-perf/`.
