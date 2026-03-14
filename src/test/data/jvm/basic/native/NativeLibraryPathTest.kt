import org.junit.Test

class NativeLibraryPathTest {
  @Test
  fun loadsSharedLibraryFromRuntimeDeps() {
    System.loadLibrary("native_lib")
  }
}
