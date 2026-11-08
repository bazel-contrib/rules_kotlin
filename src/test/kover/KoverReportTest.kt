package kover

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import javax.xml.xpath.XPathFactory

class KoverReportTest {
  @Test
  fun reportDistinguishesExecutedAndUnexecutedMethods() {
    val fixture = File(System.getProperty("fixture"))
    val cli = File(System.getProperty("cli")).absoluteFile
    val workspace = File(System.getenv("TEST_TMPDIR"), "runfiles/workspace").apply { mkdirs() }
    for (path in fixture.resolveSibling("fixture.inputs").readLines()) {
      File(path).copyTo(workspace.resolve(path))
    }
    val dir = workspace.resolve(fixture.parent)
    val raw = dir.resolve("exercise_test-kover_report.ic")
    run(workspace, fixture.absoluteFile)

    assertTrue("Missing or empty ${raw.name}", raw.length() > 0)
    val outputs = File(System.getenv("TEST_UNDECLARED_OUTPUTS_DIR"))
    raw.copyTo(outputs.resolve(raw.name))
    val xml = outputs.resolve("report.xml")
    run(workspace, cli, "@${dir.resolve("exercise_test-kover_metadata.txt")}", "--xml", xml.path)
    assertTrue("Missing source from test runfiles", dir.resolve("Subject.kt").isFile)

    val document = DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(xml)
    val xpath = XPathFactory.newInstance().newXPath()
    fun lines(method: String, counter: String): String = xpath.evaluate(
      "//class[@name='kover/Subject']/method[@name='$method']/counter[@type='LINE']/@$counter",
      document,
    )
    assertEquals("covered lines in called()", "1", lines("called", "covered"))
    assertEquals("covered lines in skipped()", "0", lines("skipped", "covered"))
    assertEquals("missed lines in skipped()", "1", lines("skipped", "missed"))
    val excluded = xpath.evaluate("count(//class[@name='kover/Generated'])", document)
    assertEquals("excluded class", "0", excluded)
  }

  private fun run(workspace: File, program: File, vararg args: String) {
    val child = ProcessBuilder(listOf(program.path) + args).directory(workspace).inheritIO()
    // The fixture runs its own JUnit class. The outer test owns Bazel's filter and XML result.
    child.environment().remove("TESTBRIDGE_TEST_ONLY")
    child.environment().remove("XML_OUTPUT_FILE")
    assertEquals(program.name, 0, child.start().waitFor())
  }
}
