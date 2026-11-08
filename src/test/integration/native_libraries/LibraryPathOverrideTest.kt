package nativelib

import org.junit.Assert.assertEquals
import org.junit.Test

class LibraryPathOverrideTest {
    @Test
    fun userJvmFlagWins() {
        assertEquals("user supplied", System.getProperty("java.library.path"))
    }
}
