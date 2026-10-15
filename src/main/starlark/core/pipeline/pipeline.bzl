"""Runs an insertion-ordered processor chain, accumulating ProviderInfo for JVM rule shells."""

ProviderInfo = provider(
    doc = "One accumulation record produced by a pipeline processor.",
    fields = {
        "name": "String key identifying the contributing processor.",
        "runfiles": "Optional runfiles the processor contributes (merged by finalize).",
        "value": "The processor's result, threaded to later stages and to finalize.",
    },
)

def _make_processing_pipeline(processors = {}, finalize = None):
    """Bundle an insertion-ordered processor dict with its finalize step."""
    return struct(
        processors = processors,
        finalize = finalize,
    )

def _run(ctx, java_package, pipeline):
    """Execute a pipeline's processors in insertion order, then finalize."""
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
