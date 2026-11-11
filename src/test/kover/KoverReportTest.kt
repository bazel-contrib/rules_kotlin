package kover

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class KoverReportTest {
  @Test
  fun reportMatchesGolden() {
    val fixture = File(System.getProperty("fixture"))
    val cli = File(System.getProperty("cli")).absoluteFile
    val workspace = File(System.getenv("TEST_TMPDIR"), "runfiles/workspace").apply { mkdirs() }
    for (path in fixture.resolveSibling("fixture.inputs").readLines()) {
      File(path).copyTo(workspace.resolve(path))
    }
    val dir = workspace.resolve(fixture.parent)
    assertFalse("Kover fixture must not use JaCoCo", dir.resolve("exercise_test.jacoco_metadata.txt").exists())
    val raw = dir.resolve("exercise_test-kover_report.ic")
    run(workspace, fixture.absoluteFile)

    assertTrue("Missing or empty ${raw.name}", raw.length() > 0)
    val outputs = File(System.getenv("TEST_UNDECLARED_OUTPUTS_DIR"))
    raw.copyTo(outputs.resolve(raw.name))
    val metadata = dir.resolve("exercise_test-kover_metadata.txt")
    val classfiles = metadata.readLines().zipWithNext()
      .filter { (flag, _) -> flag == "--classfiles" }
      .map { (_, path) -> path }
    assertEquals("only instrumented JARs", listOf("src/test/kover/subject.jar"), classfiles)
    val xml = outputs.resolve("report.xml")
    run(workspace, cli, "@$metadata", "--xml", xml.path)
    assertTrue("Missing source from test runfiles", dir.resolve("Subject.kt").isFile)

    assertEquals(
      "Kover XML report",
      File(System.getProperty("expected_report")).readText().replace("\r\n", "\n"),
      xml.readText().replace("\r\n", "\n"),
    )
  }

  private fun run(workspace: File, program: File, vararg args: String) {
    val child = ProcessBuilder(listOf(program.path) + args).directory(workspace).inheritIO()
    // The fixture runs its own JUnit class. The outer test owns Bazel's filter and XML result.
    child.environment().remove("TESTBRIDGE_TEST_ONLY")
    child.environment().remove("XML_OUTPUT_FILE")
    assertEquals(program.name, 0, child.start().waitFor())
  }
}
