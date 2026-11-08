package kover

import org.junit.Assert.assertEquals
import org.junit.Test

class ExerciseTest {
  @Test
  fun callsOneMethod() {
    assertEquals("covered", Subject().called())
    assertEquals("excluded", Generated().value())
  }
}
