package nativelib

object NativeLib {
    init {
        System.loadLibrary("native_lib")
    }

    @JvmStatic
    external fun answer(): Int
}
