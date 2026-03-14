object NativeLibraryPathTest {
  @JvmStatic
  fun main(args: Array<String>) {
    System.loadLibrary("native_resource_helper")
    println("Loaded native_resource_helper from runtime_deps.")
  }
}
