package native_lib

import org.junit.Test
import kotlin.test.assertEquals

class NativeLibTest {
    @Test
    fun testNativeGreeting() {
        assertEquals("Hello from native!", NativeLib.greeting())
    }
}
