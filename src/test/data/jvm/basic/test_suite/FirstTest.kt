package test_suite

import org.junit.Assert.assertEquals
import org.junit.Test

class FirstTest {
  @Test
  fun usesSharedHelper() {
    assertEquals("first:shared", sharedMessage("first"))
  }
}
