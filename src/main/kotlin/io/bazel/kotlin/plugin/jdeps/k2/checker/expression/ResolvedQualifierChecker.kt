package io.bazel.kotlin.plugin.jdeps.k2.checker.expression

import io.bazel.kotlin.plugin.jdeps.k2.ClassUsageRecorder
import org.jetbrains.kotlin.diagnostics.DiagnosticReporter
import org.jetbrains.kotlin.fir.analysis.checkers.MppCheckerKind
import org.jetbrains.kotlin.fir.analysis.checkers.context.CheckerContext
import org.jetbrains.kotlin.fir.analysis.checkers.expression.FirResolvedQualifierChecker
import org.jetbrains.kotlin.fir.expressions.FirResolvedQualifier

// Handles expressions such as enum constants and annotation usages
internal class ResolvedQualifierChecker(
  private val classUsageRecorder: ClassUsageRecorder,
) : FirResolvedQualifierChecker(MppCheckerKind.Common) {
  context(context: CheckerContext, reporter: DiagnosticReporter)
  override fun check(expression: FirResolvedQualifier) {
    expression.qualifierSymbol?.let {
      classUsageRecorder.recordClass(it, context)
    }
  }
}
