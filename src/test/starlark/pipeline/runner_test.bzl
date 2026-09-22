"""Unit tests for the minimal internal processing-pipeline runner.

Locks the observable contract of `//src/main/starlark/core/pipeline:pipeline.bzl`:

  (a) `run` executes processors in insertion order (NOT sorted);
  (b) `append` adds after, `prepend` adds before, `replace` swaps by key while
      preserving position -- all as immutable transforms over the ordered dict;
  (c) `ProviderInfo` values accumulate and the `finalize` step sees every record,
      with later processors observing earlier results through the shared mutable
      context namespace;
  (d) runfiles contributed by processors merge.
"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//src/main/starlark/core/pipeline:pipeline.bzl", "ProviderInfo", "processing_pipeline")

def _tagging_processor(tag, value):
    def _processor(_context):
        return ProviderInfo(name = tag, value = value, runfiles = None)

    return _processor

def _order_test_impl(ctx):
    env = unittest.begin(ctx)

    # Insertion order is c, a, b -- deliberately NOT alphabetical so the assertion
    # proves the runner honours insertion order rather than sorting the keys.
    processors = {
        "c": _tagging_processor("c", "c"),
        "a": _tagging_processor("a", "a"),
        "b": _tagging_processor("b", "b"),
    }
    pipeline = processing_pipeline.make_processing_pipeline(
        processors = processors,
        finalize = lambda context: [p.name for p in context.providers],
    )

    asserts.equals(
        env,
        ["c", "a", "b"],
        processing_pipeline.run(ctx = None, java_package = "com.example", pipeline = pipeline),
    )

    return unittest.end(env)

order_test = unittest.make(_order_test_impl)

def _transforms_test_impl(ctx):
    env = unittest.begin(ctx)

    base = {"a": "pa", "b": "pb"}

    # append: new key lands AFTER the existing ones, existing order preserved.
    appended = processing_pipeline.append(base, c = "pc")
    asserts.equals(env, ["a", "b", "c"], appended.keys())
    asserts.equals(env, "pc", appended["c"])

    # prepend: new key lands BEFORE the existing ones.
    prepended = processing_pipeline.prepend(base, z = "pz")
    asserts.equals(env, ["z", "a", "b"], prepended.keys())
    asserts.equals(env, "pz", prepended["z"])

    # replace: swap by key, position preserved, no new key added.
    replaced = processing_pipeline.replace(base, b = "PB")
    asserts.equals(env, ["a", "b"], replaced.keys())
    asserts.equals(env, "pa", replaced["a"])
    asserts.equals(env, "PB", replaced["b"])

    # Transforms are immutable: the source dict is untouched.
    asserts.equals(env, {"a": "pa", "b": "pb"}, base)

    return unittest.end(env)

transforms_test = unittest.make(_transforms_test_impl)

def _accumulate_test_impl(ctx):
    env = unittest.begin(ctx)

    def _first(_context):
        return ProviderInfo(name = "first", value = 1, runfiles = None)

    def _second(context):
        # Observes the earlier result through the shared mutable namespace.
        return ProviderInfo(name = "second", value = context.outputs["first"] + 1, runfiles = None)

    pipeline = processing_pipeline.make_processing_pipeline(
        processors = {"first": _first, "second": _second},
        finalize = lambda context: {p.name: p.value for p in context.providers},
    )

    asserts.equals(
        env,
        {"first": 1, "second": 2},
        processing_pipeline.run(ctx = None, java_package = "com.example", pipeline = pipeline),
    )

    return unittest.end(env)

accumulate_test = unittest.make(_accumulate_test_impl)

def _runfiles_test_impl(ctx):
    env = unittest.begin(ctx)

    f1 = ctx.actions.declare_file(ctx.label.name + "_f1")
    f2 = ctx.actions.declare_file(ctx.label.name + "_f2")
    ctx.actions.write(f1, "")
    ctx.actions.write(f2, "")

    def _first(context):
        return ProviderInfo(name = "first", value = None, runfiles = context.ctx.runfiles(files = [f1]))

    def _second(context):
        return ProviderInfo(name = "second", value = None, runfiles = context.ctx.runfiles(files = [f2]))

    def _finalize(context):
        return context.ctx.runfiles().merge_all(
            [p.runfiles for p in context.providers if p.runfiles],
        )

    pipeline = processing_pipeline.make_processing_pipeline(
        processors = {"first": _first, "second": _second},
        finalize = _finalize,
    )

    merged = processing_pipeline.run(ctx = ctx, java_package = "com.example", pipeline = pipeline)
    basenames = [f.basename for f in merged.files.to_list()]
    asserts.true(env, (ctx.label.name + "_f1") in basenames)
    asserts.true(env, (ctx.label.name + "_f2") in basenames)

    return unittest.end(env)

runfiles_merge_test = unittest.make(_runfiles_test_impl)

def runner_test_suite(name):
    """Wire the processing-pipeline runner's order/transform/accumulate/runfiles tests."""
    unittest.suite(
        name,
        order_test,
        transforms_test,
        accumulate_test,
        runfiles_merge_test,
    )
