package native_lib

object NativeLib {
    init {
        System.loadLibrary("native_lib")
    }

    @JvmStatic
    external fun greeting(): String
}

fun main() {
    println(NativeLib.greeting())
}
