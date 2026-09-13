import java.io.File
import java.nio.file.Files

object LaunchTest {
    @JvmStatic fun main(args: Array<String>) {
        val binary = File(args[0]).absoluteFile
        val work = Files.createTempDirectory(File(System.getenv("TEST_TMPDIR")).toPath(), "native cwd with spaces ").toFile()
        val output = File(work, "native result.txt")
        val process = ProcessBuilder(binary.path, output.path)
            .directory(work)
            .inheritIO()
            .start()
        check(process.waitFor() == 0)
        check(output.readText() == "42")
        check(File(args[1]).readText() == "42")
    }
}
