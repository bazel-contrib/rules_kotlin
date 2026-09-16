package io.bazel.kotlin.plugin.jdeps.k2

import org.jetbrains.kotlin.fir.analysis.checkers.context.CheckerContext
import org.jetbrains.kotlin.fir.declarations.utils.sourceElement
import org.jetbrains.kotlin.fir.resolve.providers.symbolProvider
import org.jetbrains.kotlin.fir.symbols.impl.FirClassLikeSymbol
import org.jetbrains.kotlin.fir.symbols.impl.FirClassSymbol
import org.jetbrains.kotlin.fir.types.ConeKotlinType
import org.jetbrains.kotlin.fir.types.FirTypeRef
import org.jetbrains.kotlin.fir.types.classId
import org.jetbrains.kotlin.fir.types.coneType
import org.jetbrains.kotlin.fir.types.forEachType
import org.jetbrains.kotlin.name.ClassId

private const val ANONYMOUS = "<anonymous>"

class ClassUsageRecorder(
  internal val explicitClassesCanonicalPaths: MutableSet<String> = mutableSetOf(),
  internal val implicitClassesCanonicalPaths: MutableSet<String> = mutableSetOf(),
) {
  internal fun recordTypeRef(
    typeRef: FirTypeRef,
    context: CheckerContext,
    isExplicit: Boolean = true,
    collectTypeArguments: Boolean = true,
    visited: MutableSet<Pair<ClassId, Boolean>> = mutableSetOf(),
  ) {
    recordConeType(typeRef.coneType, context, isExplicit, collectTypeArguments, visited)
  }

  internal fun recordConeType(
    coneKotlinType: ConeKotlinType,
    context: CheckerContext,
    isExplicit: Boolean = true,
    collectTypeArguments: Boolean = true,
    visited: MutableSet<Pair<ClassId, Boolean>> = mutableSetOf(),
  ) {
    if (collectTypeArguments) {
      coneKotlinType.forEachType(
        action = { coneType ->
          val classId = coneType.classId ?: return@forEachType
          if (ANONYMOUS in classId.toString()) return@forEachType
          context.session.symbolProvider
            .getClassLikeSymbolByClassId(classId)
            ?.let { recordClass(it, context, isExplicit, collectTypeArguments, visited) }
        },
      )
    } else {
      coneKotlinType.classId?.let { classId ->
        if (!classId.isLocal) {
          context.session.symbolProvider
            .getClassLikeSymbolByClassId(classId)
            ?.let { recordClass(it, context, isExplicit, collectTypeArguments, visited) }
        }
      }
    }
  }

  internal fun recordClass(
    firClass: FirClassLikeSymbol<*>,
    context: CheckerContext,
    isExplicit: Boolean = true,
    collectTypeArguments: Boolean = true,
    visited: MutableSet<Pair<ClassId, Boolean>> = mutableSetOf(),
  ) {
    val classIdAndIsExplicit = firClass.classId to isExplicit
    if (classIdAndIsExplicit in visited) {
      return
    } else {
      visited.add(classIdAndIsExplicit)
    }

    firClass.sourceElement?.binaryClass()?.let { addFile(it, isExplicit) }

    if (firClass is FirClassSymbol<*>) {
      firClass.resolvedSuperTypeRefs.forEach {
        recordTypeRef(it, context, false, collectTypeArguments, visited)
      }
      if (collectTypeArguments) {
        firClass.typeParameterSymbols
          .flatMap { it.resolvedBounds }
          .forEach { recordTypeRef(it, context, isExplicit, collectTypeArguments, visited) }
      }
    }
  }

  internal fun recordClass(
    binaryClass: String,
    isExplicit: Boolean = true,
  ) {
    addFile(binaryClass, isExplicit)
  }

  private fun addFile(
    path: String,
    isExplicit: Boolean,
  ) {
    if (isExplicit) {
      explicitClassesCanonicalPaths.add(path)
    } else {
      implicitClassesCanonicalPaths.add(path)
    }
  }
}
