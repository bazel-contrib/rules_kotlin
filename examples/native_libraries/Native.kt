import java.io.File

object Native {
    init {
        System.loadLibrary("native")
    }

    @JvmStatic external fun answer(): Int

    @JvmStatic fun main(args: Array<String>) {
        check(answer() == 42)
        if (args.size > 1) {
            check(args.drop(1) == listOf("with spaces", "a\"b", "C:\\trailing\\")) {
                "Unexpected arguments: ${args.toList()}"
            }
        }
        if (args.isNotEmpty()) File(args[0]).writeText("42")
    }
}
