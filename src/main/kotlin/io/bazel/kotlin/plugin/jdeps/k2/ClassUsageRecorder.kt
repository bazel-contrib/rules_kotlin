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

/**
 * The classes the analyzed sources use, by the path of the source using them. A usage outside a
 * source file is recorded under the empty path.
 */
class ClassUsageRecorder {
  internal val explicitClassesBySource = LinkedHashMap<String, MutableSet<String>>()
  internal val implicitClassesBySource = LinkedHashMap<String, MutableSet<String>>()

  internal val explicitClassesCanonicalPaths: Set<String>
    get() = explicitClassesBySource.values.flatten().toSet()
  internal val implicitClassesCanonicalPaths: Set<String>
    get() = implicitClassesBySource.values.flatten().toSet()

  /** Records an analyzed source, so that it is listed even if it uses no classes. */
  internal fun recordSource(path: String) {
    explicitClassesBySource.getOrPut(path) { linkedSetOf() }
    implicitClassesBySource.getOrPut(path) { linkedSetOf() }
  }

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

    firClass.sourceElement?.binaryClass()?.let { addFile(it, isExplicit, context) }

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
    context: CheckerContext,
    isExplicit: Boolean = true,
  ) {
    addFile(binaryClass, isExplicit, context)
  }

  private fun addFile(
    path: String,
    isExplicit: Boolean,
    context: CheckerContext,
  ) {
    val source = context.containingFile?.path.orEmpty()
    recordSource(source)
    if (isExplicit) {
      explicitClassesBySource.getValue(source).add(path)
    } else {
      implicitClassesBySource.getValue(source).add(path)
    }
  }
}
