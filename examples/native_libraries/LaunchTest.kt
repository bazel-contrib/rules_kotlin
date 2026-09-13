import java.io.File
import java.nio.file.Files

object LaunchTest {
    @JvmStatic fun main(args: Array<String>) {
        val binary = File(args[0]).absoluteFile
        val work = Files.createTempDirectory(File(System.getenv("TEST_TMPDIR")).toPath(), "native cwd with spaces ").toFile()
        val output = File(work, "native result.txt")
        fun launch(executable: File, manifestOnly: Boolean = false) {
            val builder = ProcessBuilder(executable.path, output.path, "with spaces", "a\"b", "C:\\trailing\\")
                .directory(work)
                .inheritIO()
            if (manifestOnly) {
                val manifest = File(System.getenv("RUNFILES_MANIFEST_FILE") ?: "${System.getenv("TEST_SRCDIR")}/MANIFEST")
                check(manifest.isFile)
                builder.environment().apply {
                    remove("RUNFILES_DIR")
                    remove("JAVA_RUNFILES")
                    remove("TEST_SRCDIR")
                    put("RUNFILES_MANIFEST_FILE", manifest.absolutePath)
                }
            }
            check(builder.start().waitFor() == 0)
            check(output.readText() == "42")
            output.delete()
        }
        launch(binary)
        if (System.getProperty("os.name").startsWith("Windows")) {
            // This copy has no runfiles tree. Every dependency must come from
            // the caller's manifest, including the JVM helper and external DLL.
            launch(binary.copyTo(File(work, "standalone.exe")), manifestOnly = true)
        }
        check(File(args[1]).readText() == "42")
    }
}
