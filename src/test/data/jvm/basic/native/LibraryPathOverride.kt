package native_lib

object LibraryPathOverride {
    @JvmStatic
    fun main(args: Array<String>) {
        check(System.getProperty("java.library.path") == "user supplied path")
    }
}
