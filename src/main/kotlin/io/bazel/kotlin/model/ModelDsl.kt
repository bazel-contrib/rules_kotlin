package io.bazel.kotlin.model

/**
 * Scopes model builders so nested blocks cannot accidentally modify an outer model.
 *
 * Models support construction such as `JvmCompilationTask { outputs { jar = "out.jar" } }`.
 * Builder collections accept `+=`; building copies them to keep earlier models independent.
 * Nested blocks start from the current value, preserving fields configured before the block.
 */
@DslMarker
@Target(AnnotationTarget.CLASS)
annotation class ModelDsl
