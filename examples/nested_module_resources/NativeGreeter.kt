object NativeGreeter {
    init {
        System.loadLibrary("native_greeter")
    }

    @JvmStatic
    external fun greetFromNative(): String
}
