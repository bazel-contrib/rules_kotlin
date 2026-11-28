package io.bazel.kotlin

import coffee.CoffeeAppModel
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.JUnit4
import src.test.data.jvm.ksp.`BytecodeExample$GeneratedDefinition$`

@RunWith(JUnit4::class)
class KotlinJvmKspAssertionTest: KotlinAssertionTestCase("src/test/data/jvm/ksp") {

    @Test
    fun testKotlinOnlyKSP() {
        assertEquals("test-id", CoffeeAppModel("test-id").id)
        jarTestCase(
            name = "ksp_kotlin_resources.jar",
            description = "KSP should work",
        ) {
            assertContainsEntries(
                "coffee/CoffeeAppModelJsonAdapter.class",
            )
        }
        jarTestCase(
            "ksp_kotlin_resources_missing_plugin.jar",
            description = "KSP should not generate files"
        ) {
            assertDoesNotContainEntries(
                "coffee/CoffeeAppModelJsonAdapter.class",
            )
        }
    }

    @Test
    fun testJavaOnlyKSP() {
        jarTestCase(
            name = "ksp_only_java.jar",
            description = "KSP should work with java",
        ) {
            assertContainsEntries(
              "META-INF/services/",
              "META-INF/services/java.lang.Object",
            )
        }
    }

    @Test
    fun testMixedModeKSP() {
        jarTestCase(
            name = "ksp_mixed_resources.jar",
            description = "KSP should work for mixed mode targets",
        ) {
            assertContainsEntries(
                "META-INF/",
                "META-INF/MANIFEST.MF",
                "coffee/",
                "coffee/CoffeeApp.class",
                "coffee/CoffeeApp\$CoffeeShop.class",
                "coffee/CoffeeApp\$Companion.class",
                "coffee/CoffeeBean.class",
                "coffee/CoffeeMaker.class",
                "coffee/CoffeeMaker_Factory.class",
                "coffee/DaggerCoffeeApp_CoffeeShop.class",
                "coffee/DaggerCoffeeApp_CoffeeShop\$Builder.class",
                "coffee/DaggerCoffeeApp_CoffeeShop\$CoffeeShopImpl.class",
                "coffee/DripCoffeeModule.class",
                "coffee/DripCoffeeModule_ProvideHeaterFactory.class",
                "coffee/ElectricHeater.class",
                "coffee/Heater.class",
                "coffee/Pump.class",
                "coffee/PumpModule.class",
                "coffee/Thermosiphon.class",
            )
        }
    }

    @Test
    fun testKSPGeneratesJavaOnlyWithPluginGeneratesJavaFlagEnabled() {
        jarTestCase(
            name = "ksp_kotlin_resources_multiple_plugins.jar",
            description = "KSP should generate java",
        ) {
            assertContainsEntries(
                "coffee/CoffeeAppModelJsonAdapter.class",
                "coffee/DripCoffeeModule_ProvideHeaterFactory.class",
            )
        }
        jarTestCase(
            "ksp_kotlin_resources_multiple_plugins_no_java_gen.jar",
            description = "KSP should not generate java files"
        ) {
            assertContainsEntries(
                "coffee/CoffeeAppModelJsonAdapter.class",
            )
            assertDoesNotContainEntries(
                "coffee/DripCoffeeModule_ProvideHeaterFactory.class",
            )
        }
    }

    @Test
    fun testKSPCopiesAllFilesFromMetaINF() {
        jarTestCase(
            name = "ksp_mixed_resources_multiple_plugins.jar",
            description = "Generated jar with ksp plugins contains all meta-inf contents",
        ) {
            assertContainsEntries(
                "META-INF/",
                "META-INF/MANIFEST.MF",
                "META-INF/proguard/",
                "META-INF/proguard/moshi-coffee.CoffeeAppModel.pro",
                "META-INF/services/",
                "META-INF/services/java.lang.Object",
                "coffee/",
                "coffee/CoffeeApp.class",
                "coffee/CoffeeAppModel.class",
                "coffee/CoffeeAppModelJsonAdapter.class",
                "coffee/CoffeeAppService.class",
                "coffee/CoffeeApp\$CoffeeShop.class",
                "coffee/CoffeeApp\$Companion.class",
                "coffee/CoffeeMaker.class",
                "coffee/CoffeeMaker_Factory.class",
                "coffee/DaggerCoffeeApp_CoffeeShop.class",
                "coffee/DaggerCoffeeApp_CoffeeShop\$Builder.class",
                "coffee/DaggerCoffeeApp_CoffeeShop\$CoffeeShopImpl.class",
                "coffee/DripCoffeeModule.class",
                "coffee/DripCoffeeModule_ProvideHeaterFactory.class",
                "coffee/ElectricHeater.class",
                "coffee/Heater.class",
                "coffee/Pump.class",
                "coffee/PumpModule.class",
                "coffee/Thermosiphon.class",
            )
        }
    }

    @Test
    fun testKSPJarIncludesGeneratedClasses() {
      assertEquals("Hello, BytecodeExample!", `BytecodeExample$GeneratedDefinition$`().greet())
      jarTestCase(
        name = "ksp_generate_bytecode.jar",
        description = "KSP should include generated classes from processors",
      ) {
        // Entries should contain the generated class files
        assertContainsEntries(
          "META-INF/",
          "META-INF/MANIFEST.MF",
          "src/",
          "src/test/",
          "src/test/data/",
          "src/test/data/jvm/",
          "src/test/data/jvm/ksp/",
          "src/test/data/jvm/ksp/BytecodeExample\$GeneratedDefinition\$.class",
          "META-INF/services/",
          "META-INF/src_test_data_jvm_ksp-ksp_generate_bytecode.kotlin_module",
          "src/test/data/jvm/ksp/BytecodeExample.class",
          "META-INF/services/src.test.data.jvm.ksp.BytecodeExample\$GeneratedDefinition\$"
        )
      }
    }

  @Test
  fun testKSPJarDoesNotGenerateClasses() {
    jarTestCase(
      name = "ksp_bytecode_plugin_generates_no_classes_with_other_plugins.jar",
      description = "KSP plugin doesn't generate class files from processor when relevant annotation isn't applied in conjunction with other plugins.",
    ) {
      // Entries should contain no generated class files from KSP itself (e.g the bytecode generator plugin)
      assertContainsEntries(
        "META-INF/",
        "META-INF/MANIFEST.MF",
        "coffee/",
        "coffee/CoffeeBean.class",
        "coffee/CoffeeApp.class",
        "coffee/CoffeeApp\$CoffeeShop.class",
        "coffee/CoffeeApp\$Companion.class",
        "coffee/CoffeeMaker.class",
        "coffee/CoffeeMaker_Factory.class",
        "coffee/DaggerCoffeeApp_CoffeeShop.class",
        "coffee/DaggerCoffeeApp_CoffeeShop\$Builder.class",
        "coffee/DaggerCoffeeApp_CoffeeShop\$CoffeeShopImpl.class",
        "coffee/DripCoffeeModule.class",
        "coffee/DripCoffeeModule_ProvideHeaterFactory.class",
        "coffee/ElectricHeater.class",
        "coffee/Heater.class",
        "coffee/Pump.class",
        "coffee/PumpModule.class",
        "coffee/Thermosiphon.class",
      )

      assertDoesNotContainEntries(
        "coffee/CoffeeApp\$GeneratedDefinition\$.class",
      )
    }
  }
}
