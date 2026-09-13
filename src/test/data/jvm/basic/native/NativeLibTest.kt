package native_lib

import kotlin.test.assertEquals
import org.junit.Test

class NativeLibTest {
    @Test
    fun loadsNativeLibraryFromTransitiveRuntimeDependency() {
        assertEquals("Hello from native!", NativeLib.greeting())
    }
}
