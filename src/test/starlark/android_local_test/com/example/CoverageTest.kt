package com.example

import org.junit.Assert.assertEquals
import org.junit.Test

class CoverageTest {
  @Test
  fun launcherPassesTestEnvironment() {
    assertEquals("from_android_local_test", System.getenv("LAUNCHER_ENV"))
  }
}
