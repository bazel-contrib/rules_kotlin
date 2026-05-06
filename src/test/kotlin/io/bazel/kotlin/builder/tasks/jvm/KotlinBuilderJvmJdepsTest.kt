/*
 * Copyright 2020 The Bazel Authors. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 */
package io.bazel.kotlin.builder.tasks.jvm;

import com.google.common.truth.Truth.assertThat
import com.google.devtools.build.lib.view.proto.Deps
import io.bazel.kotlin.builder.Deps.Dep
import io.bazel.kotlin.builder.KotlinJvmTestBuilder
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.Parameterized
import java.io.BufferedInputStream
import java.nio.file.Files
import java.nio.file.Paths
import java.util.function.Consumer

@RunWith(Parameterized::class)
class KotlinBuilderJvmJdepsTest(private val enableK2Compiler: Boolean) {

  companion object {
    @JvmStatic
    @Parameterized.Parameters(name = "enableK2Compiler={0}")
    fun data(): Collection<Array<Any>> {
      return listOf(
        arrayOf(true),
        arrayOf(false),
      )
    }
  }

  val ctx = KotlinJvmTestBuilder()

  val TEST_FIXTURES_DEP = Dep.fromLabel(":JdepsParserTestFixtures")
  val TEST_FIXTURES2_DEP = Dep.fromLabel(":JdepsParserTestFixtures2")
  val KOTLIN_STDLIB_DEP = Dep.fromLabel("//kotlin/compiler:kotlin-stdlib")

  @Test
  fun `no kotlin source produces empty jdeps`() {
    val deps = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//deps")
      c.addSource(
        "AnotherClass.java",
        """
          package something;
          
          class AnotherClass {
          }
        """,
      )
    }
    val jdeps = depsProto(deps)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//deps")
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `no dependencies`() {
    val deps = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//deps")
      c.addDirectDependencies(TEST_FIXTURES_DEP)
    }

    val jdeps = depsProto(deps)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//deps")
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `java class static reference`() {
    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//dependingTarget")
      c.addSource(
        "AClass.kt",
        """
          package something
          
          val result = JavaClass.staticMethod()
        """,
      )
      c.addDirectDependencies(TEST_FIXTURES_DEP)
    }

    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//dependingTarget")
      .setSuccess(true)
      .addExplicitDep(TEST_FIXTURES_DEP.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `java constant reference`() {
    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "AnotherClass.kt",
        """
          package something.other
          
          import something.Constants
          
          class AnotherClass {
            val ref = Constants.HELLO_CONSTANT
          }
        """,
      )
      c.addDirectDependencies(TEST_FIXTURES_DEP)
    }

    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(TEST_FIXTURES_DEP.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `java annotation reference`() {
    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "AnotherClass.kt",
        """
          package something.other
          
          import something.JavaAnnotation
 
          abstract class AnotherClass {
            @JavaAnnotation
            internal abstract fun hasAnnotation()
          }
        """,
      )
      c.addDirectDependencies(TEST_FIXTURES_DEP)
    }

    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(TEST_FIXTURES_DEP.singleCompileJar())
      .addExplicitDep(KOTLIN_STDLIB_DEP.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `find explicit exception and its supertypes from throws annotation`() {
    val baseExceptionTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "BaseException.kt",
        """
          package something
          
          open class BaseException : Exception()
        """
      )
    }

    val exceptionTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "MyException.kt",
        """
          package something
          
          class MyException : something.BaseException()
        """
      )
      c.addDirectDependencies(baseExceptionTarget)
    }

    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "AnotherClass.kt",
        """
          package something
          
          import something.MyException
 
          class AnotherClass {
            @Throws(MyException::class)
            fun hasAnnotation() {}
          }
        """
      )
      c.addDirectDependencies(exceptionTarget)
      c.addTransitiveDependencies(baseExceptionTarget)
    }
    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel(dependingTarget.label())
      .setSuccess(true)
      .addExplicitDep(exceptionTarget.singleCompileJar())
      .addExplicitDep(KOTLIN_STDLIB_DEP.singleCompileJar())
      .addImplicitDep(baseExceptionTarget.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `annotation on class is an explict dep`() {
    val dependentTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "Annotation.kt",
        """
          package something;
          
          @Target(AnnotationTarget.CLASS)
          @Retention(AnnotationRetention.SOURCE)
          annotation class ClassAnnotation
        """,
      )
    }

    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "AnotherClass.kt",
        """
          package something

          @ClassAnnotation
          class AnotherClass { }
        """,
      )
      c.addDirectDependencies(dependentTarget)
    }

    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(dependentTarget.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `cyclic generic type references`() {
    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "FooAssert.kt",
        """
          package something.other
          
          import pkg.assertion.AbstractObjectAssert
          
          class FooAssert : AbstractObjectAssert<FooAssert, String>()

          fun fooAssert(): AbstractObjectAssert<*, String> = AbstractObjectAssert<FooAssert, String>()
        """,
      )
      c.addDirectDependencies(TEST_FIXTURES_DEP)
    }

    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(TEST_FIXTURES_DEP.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `java annotation on class is an explict dep`() {
    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "AnotherClass.kt",
        """
          package something

          @JavaAnnotation
          class AnotherClass {
          }
        """
      )
      c.addDirectDependencies(TEST_FIXTURES_DEP)
    }
    val jdeps = depsProto(dependingTarget)

    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel(dependingTarget.label())
      .setSuccess(true)
      .addExplicitDep(TEST_FIXTURES_DEP.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `java annotation values on class are an explict dep`() {
    val dependentTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "ClassToReference.kt",
        """
          package something;

          @JavaAnnotation
          class ClassToReference
        """
      )
      c.addDirectDependencies(TEST_FIXTURES_DEP)
    }

    val anotherDepTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "AnotherClassToReference.kt",
        """
          package something;

          @JavaAnnotation(modules = [ClassToReference::class])
          class AnotherClassToReference
        """
      )
      c.addDirectDependencies(dependentTarget)
      c.addDirectDependencies(TEST_FIXTURES_DEP)
    }

    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "AnotherClass.kt",
        """
          package something

          @JavaAnnotation(modules = [AnotherClassToReference::class])
          class AnotherClass {
          }
        """
      )
      c.addTransitiveDependencies(dependentTarget)
      c.addDirectDependencies(anotherDepTarget)
      c.addDirectDependencies(TEST_FIXTURES_DEP)
    }
    val jdeps = depsProto(dependingTarget)

    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel(dependingTarget.label())
      .setSuccess(true)
      .addExplicitDep(TEST_FIXTURES_DEP.singleCompileJar())
      .addExplicitDep(anotherDepTarget.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `types referenced inside when statements are explicit deps`() {
    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "AnotherClass.kt",
        """
          package something

          import pkg.assertion.ExampleException

          fun mapExceptions(exception: Exception) = when (exception) {
              is ExampleException -> exception
              else                -> exception
          }
        """
      )
      c.addDirectDependencies(TEST_FIXTURES_DEP)
    }
    val jdeps = depsProto(dependingTarget)

    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel(dependingTarget.label())
      .setSuccess(true)
      .addExplicitDep(TEST_FIXTURES_DEP.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `java classes with inheritance`() {
    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "AnotherClass.kt",
        """
          package something

          class SomeClass : SomeClassWithInheritance.BaseClassCallback {
          }
        """
      )
      c.addDirectDependencies(TEST_FIXTURES_DEP)
    }
    val jdeps = depsProto(dependingTarget)

    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel(dependingTarget.label())
      .setSuccess(true)
      .addExplicitDep(TEST_FIXTURES_DEP.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `java annotation on property is an explict dep`() {
    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "AnotherClass.kt",
        """
          package something

          class AnotherClass {
            @JavaAnnotation
            val property = 42
          }
        """,
      )
      c.addDirectDependencies(TEST_FIXTURES_DEP)
    }
    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(TEST_FIXTURES_DEP.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `java annotation with field target on companion object property is an explict dep`() {
    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "AnotherClass.kt",
        """
          package something

          import androidx.annotation.LayoutRes

          class AnotherClass {
              companion object {
                
                @JvmField @LayoutRes
                val property = 42
            }
          }
        """,
      )
      c.addDirectDependencies(TEST_FIXTURES_DEP)
    }
    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(KOTLIN_STDLIB_DEP.singleCompileJar())
      .addExplicitDep(TEST_FIXTURES_DEP.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }


  @Test
  fun `unused dependency listed`() {
    val dependentTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "AClass.kt",
        """
          package something
          
          class AClass{}
        """,
      )
    }

    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "HasNoReferenceToDep.kt",
        """
          package something
        """,
      )
      c.addDirectDependencies(dependentTarget)
    }
    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addUnusedDep(dependentTarget.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `unused transitive dependency not listed`() {
    val transitiveDep = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "TransitiveClass.kt",
        """
          package something
          
          class TransitiveClass{}
        """,
      )
    }

    val dependentTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "AClass.kt",
        """
          package something
          
          class AClass{}
        """,
      )
      c.addDirectDependencies(transitiveDep)
    }

    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "HasNoReferenceToDep.kt",
        """
          package something
        """,
      )
      c.addDirectDependencies(dependentTarget)
    }
    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addUnusedDep(dependentTarget.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `pattern match exception`() {
    val connectionNotFoundExceptionDep = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "ConnectionNotFoundException.kt",
        """
          package something2
          
          class ConnectionNotFoundException : Exception()
        """
      )
    }

    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "PatternMatchException.kt",
        """
          package something
          import something2.ConnectionNotFoundException
          
          fun isRetryable(e: Exception): Boolean {
            return when (e) {
              is ConnectionNotFoundException -> false
              else -> true
            }
          }
        """
      )
      c.addDirectDependencies(connectionNotFoundExceptionDep)
    }
    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel(dependingTarget.label())
      .setSuccess(true)
      .addExplicitDep(connectionNotFoundExceptionDep.singleCompileJar())
      .buildSorted()

    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `kotlin property reference`() {
    val dependentTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "AClass.kt",
        """
            package something

            class AClass{}
            """,
      )
    }

    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "HasPropertyDependency.kt",
        """
            package something
            
            val property2 =  AClass()
          """,
      )
      c.addDirectDependencies(dependentTarget)
    }
    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(dependentTarget.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `kotlin indirect property reference on object calling helloWorld function`() {
    val transitivePropertyTarget = runCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "Bar.kt",
        """
            package something

            class Bar {
              fun helloWorld() {}
            }
            """,
      )
    }

    val dependentTarget = runCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "Foo.kt",
        """
            package something

            class Foo {
              val bar = Bar()
            }
            """,
      )
      c.addDirectDependencies(transitivePropertyTarget)
    }

    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "HasPropertyDependency.kt",
        """
            package something
            
            fun something(foo: Foo) {
              val foo =  Foo()
              foo.bar.helloWorld()
            }
          """,
      )
      c.addDirectDependencies(dependentTarget)
      c.addTransitiveDependencies(transitivePropertyTarget)
    }
    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(dependentTarget.singleCompileJar())
      .addExplicitDep(transitivePropertyTarget.singleCompileJar())
      .addExplicitDep(KOTLIN_STDLIB_DEP.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `kotlin indirect property reference on object without calling helloWorld function`() {
    val transitivePropertyTarget = runCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "Bar.kt",
        """
            package something

            class Bar {
              fun helloWorld() {}
            }
            """,
      )
    }

    val dependentTarget = runCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "Foo.kt",
        """
            package something

            class Foo {
              val bar = Bar()
            }
            """,
      )
      c.addDirectDependencies(transitivePropertyTarget)
    }

    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "HasPropertyDependency.kt",
        """
            package something
            
            class HasPropertyDependency {
              fun something(): Any {
                val foo = Foo()
                return foo.bar
              }
            }
          """,
      )
      c.addDirectDependencies(dependentTarget)
      c.addTransitiveDependencies(transitivePropertyTarget)
    }

    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(dependentTarget.singleCompileJar())
      .addImplicitDep(transitivePropertyTarget.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `kotlin extension property reference`() {
    val dependentTarget = runCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "AClass.kt",
        """
            package something

            val String.doubleLength
                get() = length * 2
            """,
      )
    }

    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "HasPropertyDependency.kt",
        """
            package something
            
            val property2 = "Hello".doubleLength
          """,
      )
      c.addDirectDependencies(dependentTarget)
    }
    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(dependentTarget.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `kotlin extension property reference 2`() {
    val dependentTarget = runCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "AClass.kt",
        """
            package something
            
            object Extensions {
              @JvmStatic
              fun String.doubleLength() = length * 2
            }
            """,
      )
    }

    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "HasPropertyDependency.kt",
        """
            package something
            
            import something.Extensions.doubleLength
            
            val property2 = "Hello".doubleLength()
          """,
      )
      c.addDirectDependencies(dependentTarget)
    }
    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(dependentTarget.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `kotlin extension property reference 3`() {
    val dependentTarget = runCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "AClass.kt",
        """
            package something

            class AClass {
            }
            """,
      )
    }

    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "HasPropertyDependency.kt",
        """
            package something

            fun AClass?.foo(): String {
                return "foo"
            }
          """,
      )
      c.setLabel("//:dependingTarget")
      c.addDirectDependencies(dependentTarget)
    }
    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(dependentTarget.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `kotlin property definition`() {
    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "HasPropertyDefinition.kt",
        """
            package something
            
            interface HasPropertyDefinition {

                val callFactory: JavaClass.InnerJavaClass
            }
          """,
      )
      c.addDirectDependencies(TEST_FIXTURES_DEP)
    }
    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(TEST_FIXTURES_DEP.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `java static repro`() {
    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "HasPropertyDefinition.kt",
        """
            package something
            
            class HasPropertyDefinition {
              fun provideMyHttpClient(): MyHttpClient {
                  return MyHttpClient.builder()
                      .name("ApiClient")
                      .circuitBreakerStrategy(CircuitBreakerStrategies.alwaysClosed())
                      .build()
              }
            }
          """
      )
      c.addDirectDependencies(TEST_FIXTURES_DEP)
    }
    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel(dependingTarget.label())
      .setSuccess(true)
      .addExplicitDep(TEST_FIXTURES_DEP.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `java static repro 2`() {
    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "Repro.kt",
        """
            package something
            
            class Repro {
              fun hi() {
                  (GlobalTracer.get()?.activeSpan() as? MySpan)?.report(RuntimeException(), false)
              }
            }
          """
      )
      c.addDirectDependencies(TEST_FIXTURES_DEP)
      c.addTransitiveDependencies(TEST_FIXTURES2_DEP)
    }
    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel(dependingTarget.label())
      .setSuccess(true)
      .addExplicitDep(TEST_FIXTURES_DEP.singleCompileJar())
      .addExplicitDep(KOTLIN_STDLIB_DEP.singleCompileJar())
      .addImplicitDep(TEST_FIXTURES2_DEP.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `test client1 and client2 are explicit jdeps`() {
    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "AClass.kt",
        """
            package something
            import something.JavaBaseWithTypeParam

            class AClass: JavaBaseWithTypeParam<String>() {
                val client1Instance = JavaWidgetFactory.create(client1, client2)
            }
            """
      )
      c.addDirectDependencies(TEST_FIXTURES_DEP, TEST_FIXTURES2_DEP)
    }

    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel(dependingTarget.label())
      .setSuccess(true)
      .addExplicitDep(TEST_FIXTURES_DEP.singleCompileJar())
      .addExplicitDep(TEST_FIXTURES2_DEP.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `java enum reference`() {
    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "HasPropertyDefinition.kt",
        """
            package something
            
            class Foo {

                val result = InnerJavaEnum.A_VALUE.name
            }
          """,
      )
      c.addDirectDependencies(TEST_FIXTURES_DEP)
    }
    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(TEST_FIXTURES_DEP.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `kotlin method reference`() {
    val dependentTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "AClass.kt",
        """
            package something

            fun String.aFunction() {}
            """,
      )
    }

    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "HasFunctionDependency.kt",
        """
            package something.other
            
            import something.aFunction
            
            val functionRef = String::aFunction
          """,
      )
      c.addDirectDependencies(dependentTarget)
    }
    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(dependentTarget.singleCompileJar())
      .addExplicitDep(KOTLIN_STDLIB_DEP.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `kotlin generic type reference`() {
    val dependentTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "AClass.kt",
        """
            package something

            class AClass{}
            """,
      )
    }

    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "HasGenericTypeDependency.kt",
        """
            package something
            
            val property2 =  listOf<AClass>()
          """,
      )
      c.addDirectDependencies(dependentTarget)
    }
    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(KOTLIN_STDLIB_DEP.singleCompileJar())
      .addExplicitDep(dependentTarget.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `inline reified test`() {
    val objectMapperTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "ObjectMapper.kt",
        """
            package something

            class ObjectMapper {
            }

            object Mappers {
                val TEST_MAPPER = ObjectMapper() 
            } 
          """
      )
    }

    val dependentTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "ArgumentMatchers.kt",
        """
            package something
            import something.Mappers.TEST_MAPPER

            object ArgumentMatchers {
                inline fun <reified T : Any> argThatMatchesJson(
                    expected: String,
                    policies: List<String> = listOf(),
                    mapper: ObjectMapper = TEST_MAPPER
                ): T = T::class.java.newInstance() 
            }
          """
      )
      c.addDirectDependencies(objectMapperTarget)
    }

    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "HasGenericTypeDependency.kt",
        """
            package something
            
            import something.ArgumentMatchers.argThatMatchesJson
            
            fun hi(msg: String): String {
                return msg
            }
            
            fun something() {
                hi(argThatMatchesJson(""${'"'}{"userIds": [123]}""${'"'}))
            }
            """
      )
      c.addDirectDependencies(dependentTarget)
      c.addTransitiveDependencies(objectMapperTarget)
    }

    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel(dependingTarget.label())
      .setSuccess(true)
      .addExplicitDep(dependentTarget.singleCompileJar())
      .addExplicitDep(KOTLIN_STDLIB_DEP.singleCompileJar())
      .addImplicitDep(objectMapperTarget.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `inlined constant dependency recorded`() {
    val dependentTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "ContainsConstant.kt",
        """
          package dependency
            
          object ConstHolder {
            const val CONSTANT_VAL = 42
          }
        """,
      )
    }

    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "HasPropertyDependency.kt",
        """
            package something
            import dependency.ConstHolder
            val property2 = ConstHolder.CONSTANT_VAL
          """,
      )
      c.addDirectDependencies(dependentTarget)
    }
    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(dependentTarget.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `object inlined constant dependency recorded`() {
    val dependentTarget = runCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "HasConstants.kt",
        """
          package dependency
          object HasConstants {
            const val CONSTANT_VAL = 42
          }
        """,
      )
    }

    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "HasPropertyDependency.kt",
        """
            package something
            import dependency.HasConstants.CONSTANT_VAL
            val property2 = CONSTANT_VAL
          """,
      )
      c.addDirectDependencies(dependentTarget)
    }
    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(dependentTarget.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `companion object inlined constant dependency recorded`() {
    val dependentTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "ContainsConstant.kt",
        """
          package dependency
          class HasCompanion {
            companion object {
              const val CONSTANT_VAL = 42
            }            
          }
        """,
      )
    }

    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "HasPropertyDependency.kt",
        """
            package something
            import dependency.HasCompanion.Companion.CONSTANT_VAL
            val property2 = CONSTANT_VAL
          """,
      )
      c.addDirectDependencies(dependentTarget)
    }
    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(dependentTarget.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `constructor param inner class recorded`() {
    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "HasConstructorDependency.kt",
        """
            package something.otherthan
            
            import something.JavaClass
            
            class HasConstructorDependency constructor(javaClass: JavaClass.InnerJavaClass) {}
          """,
      )
      c.addDirectDependencies(TEST_FIXTURES_DEP)
    }
    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(TEST_FIXTURES_DEP.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `call function in dependency`() {
    val dependentTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "ContainsFunction.kt",
        """
          package dependency
            
          fun someFunction() = 42
        """,
      )
      c.compileKotlin()
    }

    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "HasFunctionDependency.kt",
        """
            package something
            import dependency.someFunction
            val property2 = someFunction()
          """,
      )
      c.addDirectDependencies(dependentTarget)
    }
    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(dependentTarget.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `implement interface reference should be an explicit dependency`() {
    val indirectInterfaceDef = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "IndirectInterface.kt",
        """
            package something

            interface IndirectInterface {
                fun doFoo()
            }
            """,
      )
    }
    val directInterfaceDef = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "DirectInterface.kt",
        """
            package something

            interface DirectInterface : IndirectInterface {
                fun doBar()
            }
            """,
      )
      c.addDirectDependencies(indirectInterfaceDef)
    }

    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "ReferencesClassWithSuperClass.kt",
        """
            package something

            interface SubInterface : DirectInterface
          """,
      )
      c.addDirectDependencies(directInterfaceDef)
      c.addTransitiveDependencies(indirectInterfaceDef)
    }
    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(directInterfaceDef.singleCompileJar())
      .addImplicitDep(indirectInterfaceDef.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `indirect super class reference should be an implicit dependency`() {
    val implicitSuperClassDep = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "Base.kt",
        """
            package something

            open class Base(p: Int)
            """,
      )
    }

    val explicitSuperClassDep = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "Derived.kt",
        """
            package something

            class Derived(p: Int) : Base(p)
            """,
      )
      c.addDirectDependencies(implicitSuperClassDep)
    }

    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "ReferencesClassWithSuperClass.kt",
        """
            package something

            val classRef = Derived(42)
          """,
      )
      c.addDirectDependencies(explicitSuperClassDep)
      c.addTransitiveDependencies(implicitSuperClassDep)
    }
    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(explicitSuperClassDep.singleCompileJar())
      .addImplicitDep(implicitSuperClassDep.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `property reference should collect indirect super class as implicit dependency`() {
    val implicitSuperClassDep = runCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "Base.kt",
        """
            package something

            open class Base(p: Int)
            """,
      )
    }

    val explicitSuperClassDep = runCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "Derived.kt",
        """
            package something

            object Derived : Base(41) {
              @JvmField
              val SOME_CONST = 42
            }
            """,
      )
      c.addDirectDependencies(implicitSuperClassDep)
    }

    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "ReferencesClassWithSuperClass.kt",
        """
            package something

            val classRef = Derived.SOME_CONST
          """,
      )
      c.addDirectDependencies(explicitSuperClassDep)
      c.addTransitiveDependencies(implicitSuperClassDep)
    }
    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(explicitSuperClassDep.singleCompileJar())
      .addImplicitDep(implicitSuperClassDep.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `function call on a class should collect the indirect super class of that class as an implicit dependency`() {
    val implicitSuperClassDep = runCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "Base.kt",
        """
            package something

            open class Base
            """,
      )
    }

    val explicitSuperClassDep = runCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "Derived.kt",
        """
            package something

            class Derived : Base() {
              fun hi(): String {
                return "Hello"
              }
            }
            """,
      )
      c.addDirectDependencies(implicitSuperClassDep)
    }

    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "ReferencesClassWithSuperClass.kt",
        """
            package something

            class ReferencesClassWithSuperClass {
                fun stuff(): String {
                    return Derived().hi()
                }
            }
          """,
      )
      c.addDirectDependencies(explicitSuperClassDep)
      c.addTransitiveDependencies(implicitSuperClassDep)
    }
    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(explicitSuperClassDep.singleCompileJar())
      .addImplicitDep(implicitSuperClassDep.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `creating a kotlin class should collect the indirect java super class, with a kotlin type param class, of that class as an implicit dependency`() {
    val implicitSuperClassGenericTypeParamDep = runCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "BaseGenericType.kt",
        """
            package something

            class BaseGenericType
            """,
      )
    }

    val explicitClassWithTypeParamJavaSuperclassDep = runCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "Derived.kt",
        """
            package something
            import something.JavaBaseWithTypeParam

            class Derived : JavaBaseWithTypeParam<BaseGenericType>() {
              fun hi(): String {
                return "Hello"
              }
            }
            """,
      )
      c.addDirectDependencies(TEST_FIXTURES_DEP)
      c.addDirectDependencies(implicitSuperClassGenericTypeParamDep)
    }

    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "ReferencesClassWithSuperClass.kt",
        """
            package something

            class ReferencesClassWithSuperClass {
                fun stuff(): String {
                    val derived = Derived()
                    return derived.toString()
                }
            }
          """,
      )
      c.addDirectDependencies(explicitClassWithTypeParamJavaSuperclassDep)
      c.addTransitiveDependencies(TEST_FIXTURES_DEP)
      c.addTransitiveDependencies(implicitSuperClassGenericTypeParamDep)
    }
    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(explicitClassWithTypeParamJavaSuperclassDep.singleCompileJar())
      .addImplicitDep(TEST_FIXTURES_DEP.singleCompileJar())
      .addImplicitDep(implicitSuperClassGenericTypeParamDep.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `class declaration all super class references should be an implicit dependency`() {
    val implicitSuperClassDep = runCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "Base.kt",
        """
            package something

            open class Base
            """,
      )
    }

    val explicitSuperClassDep = runCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "Derived.kt",
        """
            package something

            open class Derived : Base()
            """,
      )
      c.addSource(
        "Derived2.kt",
        """
            package something

            open class Derived2 : Derived()
            """,
      )
      c.addDirectDependencies(implicitSuperClassDep)
    }

    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "DependingClass.kt",
        """
            package something

            abstract class DependingClass : Derived2()
          """,
      )
      c.addDirectDependencies(explicitSuperClassDep)
      c.addTransitiveDependencies(implicitSuperClassDep)
    }
    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(explicitSuperClassDep.singleCompileJar())
      .addImplicitDep(implicitSuperClassDep.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `generic type as constructor parameter`() {
    val implicitSuperClassDep = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "Base.kt",
        """
            package something.base

            open class Base(p: Int)
            """,
      )
    }

    val explicitSuperClassDep = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "Derived.kt",
        """
            package something.derived
            
            import something.base.Base

            class Derived(p: Int) : Base(p)
            """,
      )
      c.addDirectDependencies(implicitSuperClassDep)
    }

    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "ReferencesGenericTypeWithSuperClass.kt",
        """
            package something.reference
            
            import something.derived.Derived
            import something.AnotherClass

            internal class HasConstructorDependency constructor(genericRef: AnotherClass<Derived>) {}
          """,
      )
      c.addDirectDependencies(TEST_FIXTURES_DEP)
      c.addDirectDependencies(explicitSuperClassDep)
      c.addTransitiveDependencies(implicitSuperClassDep)
    }
    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(TEST_FIXTURES_DEP.singleCompileJar())
      .addExplicitDep(explicitSuperClassDep.singleCompileJar())
      .addImplicitDep(implicitSuperClassDep.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `generic type as lazy property`() {
    val implicitSuperClassDep = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "Base.kt",
        """
            package something.base

            open class Base(p: Int)
            """,
      )
    }

    val explicitSuperClassDep = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "Derived.kt",
        """
            package something.derived
            
            import something.base.Base

            class Derived(p: Int) : Base(p)
            """,
      )
      c.addDirectDependencies(implicitSuperClassDep)
    }

    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "AnotherClass.java",
        """
          package something.reference;
          
          class AnotherClass<T> {
          }
        """,
      )
      c.addSource(
        "ReferencesGenericTypeWithSuperClass.kt",
        """
            package something.reference
            
            import something.derived.Derived

            private val lazyProperty by lazy { AnotherClass<Derived>() }
          """,
      )
      c.addDirectDependencies(explicitSuperClassDep)
      c.addTransitiveDependencies(implicitSuperClassDep)
    }
    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(KOTLIN_STDLIB_DEP.singleCompileJar())
      .addExplicitDep(explicitSuperClassDep.singleCompileJar())
      .addImplicitDep(implicitSuperClassDep.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `function call return type`() {
    val depWithReturnTypesSuperType = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "SomeSuperType.kt",
        """
            package something

            open class SomeSuperType
            """,
      )
    }
    val depWithReturnType = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "SomeType.kt",
        """
            package something

            class SomeType : SomeSuperType() {
            }
            """,
      )
      c.addDirectDependencies(depWithReturnTypesSuperType)
    }

    val depWithFunction = runCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "ContainsFunction.kt",
        """
            package something

            fun returnSomeType() = SomeType()
            """,
      )
      c.addDirectDependencies(depWithReturnType)
    }

    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "ReferencesClassWithSuperClass.kt",
        """
            package something

            fun foo() {
              returnSomeType()
            }
          """,
      )
      c.addDirectDependencies(depWithFunction)
      c.addTransitiveDependencies(depWithReturnType)
      c.addTransitiveDependencies(depWithReturnTypesSuperType)
    }

    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(depWithFunction.singleCompileJar())
      .addExplicitDep(KOTLIN_STDLIB_DEP.singleCompileJar())
      .addImplicitDep(depWithReturnType.singleCompileJar())
      .addImplicitDep(depWithReturnTypesSuperType.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `function call receiver type`() {
    val depWithReceiverTypeSuperType = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "SomeSuperType.kt",
        """
            package something

            open class SomeSuperType {}
            """,
      )
      c.setLabel("depWithSuperType")
    }
    val depWithReceiverType = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "SomeType.kt",
        """
            package something

            class SomeType : SomeSuperType() {}
            """,
      )
      c.setLabel("depWithReceiverType")
      c.addDirectDependencies(depWithReceiverTypeSuperType)
    }

    val depWithFunction = runCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "ContainsFunction.kt",
        """
            package something

            fun receiverSomeType(arg: SomeType.() -> Unit) {}
            """,
      )
      c.addDirectDependencies(depWithReceiverType)
      c.addTransitiveDependencies(depWithReceiverTypeSuperType)
      c.setLabel("depWithFunction")
    }

    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "CallsFunctionWithReceiver.kt",
        """
            package something

            fun foo() {
              receiverSomeType {
              }
            }
          """,
      )
      c.addDirectDependencies(depWithFunction)
      c.addTransitiveDependencies(depWithReceiverType, depWithReceiverTypeSuperType)
    }

    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(depWithFunction.singleCompileJar())
      .addExplicitDep(KOTLIN_STDLIB_DEP.singleCompileJar())
      .addImplicitDep(depWithReceiverType.singleCompileJar())
      .addImplicitDep(depWithReceiverTypeSuperType.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `constructor parameters are required implicit dependencies`() {
    val fooDep = runCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "FooClass.kt",
        """
          package something

          class FooClass
          """,
      )
    }
    val barDep = runCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "BarClass.kt",
        """
          package something

          class BarClass(private val foo: FooClass = FooClass()) { }
          """,
      )
      c.addDirectDependencies(fooDep)
    }

    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "ReferencesClassWithSuperClass.kt",
        """
          package something

          class Dummy {
            val result = BarClass()
          }
        """,
      )
      c.addDirectDependencies(barDep)
      c.addTransitiveDependencies(fooDep)
    }

    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(barDep.singleCompileJar())
      .addImplicitDep(fooDep.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `function call return type type parameter should not be a dependency`() {
    val depWithTypeParameter = runCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "SomeType.kt",
        """
            package something

            class SomeType {
              val booleanValue = true
            }
            """,
      )
    }

    val depWithFunction = runCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "ContainsFunction.kt",
        """
            package something

            fun returnSomeType() = setOf<SomeType>()
            """,
      )
      c.addDirectDependencies(depWithTypeParameter)
    }

    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "ReferencesClassWithSuperClass.kt",
        """
            package something

            fun foo() {
              returnSomeType()
            }
          """,
      )
      c.addDirectDependencies(depWithFunction)
      c.addTransitiveDependencies(depWithTypeParameter)
    }

    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(depWithFunction.singleCompileJar())
      .addExplicitDep(KOTLIN_STDLIB_DEP.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `function call parameter type nested type parameters should be an explicit dependency`() {
    val foo = runCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "Foo.kt",
        """
            package something

            class Foo { }
            """,
      )
    }

    val bar = runCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "Bar.kt",
        """
            package something

            class Bar<T> {
              val booleanValue = true
            }
            """,
      )
    }

    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "FunctionWithTypeParams.kt",
        """
            package something

            fun foo(param: Set<Bar<Foo>>) {

            }
          """,
      )
      c.addDirectDependencies(foo, bar)
    }

    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(KOTLIN_STDLIB_DEP.singleCompileJar())
      .addExplicitDep(bar.singleCompileJar())
      .addExplicitDep(foo.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `assignment from function call`() {
    val depWithReturnTypesSuperType = runCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "SomeSuperType.kt",
        """
            package something

            open class SomeSuperType
            """,
      )
      c.setLabel("depWithReturnType")
    }
    val depWithReturnType = runCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "SomeType.kt",
        """
            package something

            class SomeType : SomeSuperType() {
              val stringValue = "Hello World"
            }
            """,
      )
      c.setLabel("depWithReturnType")
      c.addDirectDependencies(depWithReturnTypesSuperType)
    }

    val depWithFunction = runCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "ContainsFunction.kt",
        """
            package something

            fun returnSomeType() = SomeType()
            """,
      )
      c.addDirectDependencies(depWithReturnType)
      c.setLabel("depWithFunction")
    }

    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.setLabel("//:dependingTarget")
      c.addSource(
        "ReferencesClassWithSuperClass.kt",
        """
            package something

            fun foo() {
              val assignment = returnSomeType()
              print(assignment.stringValue)
            }
          """,
      )
      c.addDirectDependencies(depWithFunction)
      c.addTransitiveDependencies(depWithReturnType, depWithReturnTypesSuperType)
    }

    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel("//:dependingTarget")
      .setSuccess(true)
      .addExplicitDep(depWithFunction.singleCompileJar())
      .addExplicitDep(depWithReturnType.singleCompileJar())
      .addExplicitDep(KOTLIN_STDLIB_DEP.singleCompileJar())
      .addImplicitDep(depWithReturnTypesSuperType.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  @Test
  fun `string interpolation`() {
    val dependingTarget = runJdepsCompileTask { c: KotlinJvmTestBuilder.TaskBuilder ->
      c.addSource(
        "ReferencesConsumerConfig.kt",
        """
            package something

            private val log = Log()
            fun doit(consumerConfig: ConsumerConfig?) {
              log.info("busConfig: ${'$'}{consumerConfig?.busConfig}")
            }
  
            class Log {
              fun info(message: String) {}
            }
          """
      )
      c.addDirectDependencies(TEST_FIXTURES_DEP)
      c.setLabel("dependingTarget")
    }

    val jdeps = depsProto(dependingTarget)
    val expected = Deps.Dependencies.newBuilder()
      .setRuleLabel(dependingTarget.label())
      .setSuccess(true)
      .addExplicitDep(KOTLIN_STDLIB_DEP.singleCompileJar())
      .addExplicitDep(TEST_FIXTURES_DEP.singleCompileJar())
      .buildSorted()
    assertThat(jdeps).isEqualTo(expected)
  }

  private fun depsProto(jdeps: Dep) =
    Deps.Dependencies.parseFrom(BufferedInputStream(Files.newInputStream(Paths.get(jdeps.jdeps()!!))))

  private fun runCompileTask(block: (c: KotlinJvmTestBuilder.TaskBuilder) -> Unit): Dep {
    return ctx.runCompileTask(
      Consumer { c: KotlinJvmTestBuilder.TaskBuilder ->
        if (enableK2Compiler) {
          c.useK2()
        }
        block(c.outputJar().compileKotlin())
      },
    )
  }

  private fun runJdepsCompileTask(block: (c: KotlinJvmTestBuilder.TaskBuilder) -> Unit): Dep {
    return runCompileTask { c -> block(c.outputJdeps()) }
  }

  private fun Deps.Dependencies.Builder.addExplicitDep(depPath: String): Deps.Dependencies.Builder {
    addDependency(Deps.Dependency.newBuilder().setPath(depPath).setKind(Deps.Dependency.Kind.EXPLICIT))
    return this
  }

  private fun Deps.Dependencies.Builder.addImplicitDep(depPath: String): Deps.Dependencies.Builder {
    addDependency(Deps.Dependency.newBuilder().setPath(depPath).setKind(Deps.Dependency.Kind.IMPLICIT))
    return this
  }

  private fun Deps.Dependencies.Builder.addUnusedDep(depPath: String): Deps.Dependencies.Builder {
    addDependency(Deps.Dependency.newBuilder().setPath(depPath).setKind(Deps.Dependency.Kind.UNUSED))
    return this
  }

  private fun Deps.Dependencies.Builder.buildSorted(): Deps.Dependencies {
    val sortedDeps = dependencyList.sortedBy { it.path }
    sortedDeps.forEachIndexed { index, dep ->
      setDependency(index, dep)
    }
    return build()
  }
}
