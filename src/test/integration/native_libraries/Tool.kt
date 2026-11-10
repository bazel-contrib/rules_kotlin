package nativelib

import java.io.File

fun main(args: Array<String>) {
    File(args[0]).writeText(NativeLib.answer().toString())
}
