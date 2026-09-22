"""Minimal internal processing-pipeline runner.

Vendored so that pure `kt_jvm_*` rules never transitively load `@rules_android`
(design criterion 5 / rejected option A). The surface mirrors
`@rules_android//rules:processing_pipeline.bzl` -- ordered processors threading a
shared mutable context, `ProviderInfo` accumulation, a `finalize` step, and
immutable `prepend`/`append`/`replace` transforms over the insertion-ordered
processor dict -- but reimplements ONLY what the JVM compile shells need. It
deliberately does NOT load `@rules_android`.
"""

ProviderInfo = provider(
    doc = "One accumulation record produced by a pipeline processor.",
    fields = {
        "name": "String key identifying the contributing processor.",
        "value": "The processor's result, threaded to later stages and to finalize.",
        "runfiles": "Optional runfiles the processor contributes (merged by finalize).",
    },
)

def _make_processing_pipeline(processors = {}, finalize = None):
    """Bundle an insertion-ordered processor dict with its finalize step.

    Args:
      processors: dict of name -> processor fn; execution order = insertion order.
      finalize: fn(context) -> list_of_providers, called after every processor.

    Returns:
      An opaque pipeline struct consumed by `run`.
    """
    return struct(
        processors = processors,
        finalize = finalize,
    )

def _run(ctx, java_package, pipeline):
    """Execute a pipeline's processors in insertion order, then finalize.

    A single shared mutable context namespace is threaded through every
    processor: `providers` (the accumulated ProviderInfo records) and `outputs`
    (name -> value) are mutable, so a later processor can observe the results of
    the earlier ones. Each processor returns a `ProviderInfo` (or None to
    contribute nothing); its value is recorded before the next processor runs.

    Args:
      ctx: the rule ctx, exposed to processors and finalize as `context.ctx`.
      java_package: the target's Java package, exposed as `context.java_package`.
      pipeline: a struct from `make_processing_pipeline`.

    Returns:
      Whatever `pipeline.finalize(context)` returns (the list of providers).
    """
    providers = []
    outputs = {}
    context = struct(
        ctx = ctx,
        java_package = java_package,
        providers = providers,
        outputs = outputs,
    )
    for _name, processor in pipeline.processors.items():
        info = processor(context)
        if info != None:
            providers.append(info)
            outputs[info.name] = info.value
    return pipeline.finalize(context)

def _prepend(processors, **kwargs):
    """Return a new dict with kwargs inserted BEFORE the existing processors."""
    updated = dict(**kwargs)
    updated.update(processors)
    return updated

def _append(processors, **kwargs):
    """Return a new dict with kwargs inserted AFTER the existing processors."""
    updated = dict(processors)
    updated.update(kwargs)
    return updated

def _replace(processors, **kwargs):
    """Return a new dict swapping matching keys in place, preserving position."""
    updated = {}
    for name, processor in processors.items():
        updated[name] = kwargs.get(name, processor)
    return updated

processing_pipeline = struct(
    make_processing_pipeline = _make_processing_pipeline,
    run = _run,
    prepend = _prepend,
    append = _append,
    replace = _replace,
)
