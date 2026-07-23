package test_suite

import org.junit.Assert.assertEquals
import org.junit.Test

class SecondTest {
  @Test
  fun alsoUsesSharedHelper() {
    assertEquals("second:shared", sharedMessage("second"))
  }
}
