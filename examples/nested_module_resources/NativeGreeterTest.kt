object NativeGreeterTest {
    @JvmStatic
    fun main(args: Array<String>) {
        val result = NativeGreeter.greetFromNative()
        check(result == "Hello from native!") {
            "Expected 'Hello from native!' but got '$result'"
        }
        println("PASS: NativeGreeter returned '$result'")
    }
}
