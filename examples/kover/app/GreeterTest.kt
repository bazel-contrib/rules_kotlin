package app

import org.junit.Assert.assertEquals
import org.junit.Test

class GreeterTest {
    @Test
    fun testGreet() {
        val greeter = Greeter("World")
        assertEquals("Hello, World!", greeter.greet())
    }
}
