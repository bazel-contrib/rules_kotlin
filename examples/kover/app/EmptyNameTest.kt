package app

import org.junit.Assert.assertEquals
import org.junit.Test

class EmptyNameTest {
    @Test
    fun emptyName() {
        assertEquals("Hello!", Greeter("").greet())
    }
}
