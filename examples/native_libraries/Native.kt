import java.io.File

object Native {
    init {
        System.loadLibrary("native")
    }

    @JvmStatic external fun answer(): Int

    @JvmStatic fun main(args: Array<String>) {
        check(answer() == 42)
        args.firstOrNull()?.let { File(it).writeText("42") }
    }
}
