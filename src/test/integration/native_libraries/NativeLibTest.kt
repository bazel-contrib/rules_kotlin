package nativelib

import org.junit.Assert.assertEquals
import org.junit.Test

class NativeLibTest {
    @Test
    fun callsIntoNativeLibrary() {
        assertEquals(42, NativeLib.answer())
    }
}
