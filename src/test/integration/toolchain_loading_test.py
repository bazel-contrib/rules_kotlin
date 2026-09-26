"""Check lazy toolchain loading with the integration rules' Bazel launcher."""

import json
import os
from pathlib import Path
import subprocess
import tarfile
import unittest
from urllib.parse import urlsplit

from python.runfiles import runfiles


class ToolchainLoadingTest(unittest.TestCase):
    def assert_downloads(self, log, expected):
        downloads = []
        complete = False
        with log.open(encoding="utf-8") as stream:
            for line in stream:
                event = json.loads(line)
                complete = complete or event.get("lastMessage", False)
                # Child IDs announce events; only inspect actual fetch payloads.
                if "fetch" not in event:
                    continue
                fetch = event["id"]["fetch"]
                filename = urlsplit(fetch["url"]).path.rsplit("/", 1)[-1]
                if filename.startswith("kotlin-compiler-"):
                    downloads.append({**fetch, **event["fetch"]})
        self.assertTrue(complete, f"Missing final BEP event in {log}")
        if expected:
            self.assertTrue(
                any(d.get("success") for d in downloads),
                f"No successful compiler download recorded in {log}",
            )
        else:
            self.assertFalse(downloads, f"Unexpected compiler download in {log}: {downloads}")
        print(f"{log.name}: expected download={expected}; {downloads}", flush=True)

    def test_loading(self):
        files = runfiles.Create()
        bazel = os.environ["BIT_BAZEL_BINARY"]
        print(f"Bazel launcher: {bazel}\nResolved path: {Path(bazel).resolve()}", flush=True)
        self.assertTrue(
            os.path.samefile(bazel, files.Rlocation(os.environ["BAZEL_BINARY_RUNFILE"])),
            f"Bazel launcher is not the declared runfile: {bazel}",
        )
        archive = files.Rlocation(os.environ["RULES_KOTLIN_RELEASE"])
        root = Path(os.environ["TEST_TMPDIR"])
        consumer = root / "consumer"
        release = root / "rules_kotlin"
        output = root / "output"
        logs = Path(os.environ["TEST_UNDECLARED_OUTPUTS_DIR"]) / "nested_bazel"
        for directory in (consumer, release, logs):
            directory.mkdir(parents=True, exist_ok=True)
        with tarfile.open(archive) as tar:
            tar.extractall(release, filter="data")

        (consumer / "MODULE.bazel").write_text('''
module(name = "unrelated_cpp")
bazel_dep(name = "rules_cc", version = "0.2.17")
bazel_dep(name = "rules_kotlin", version = "2.2.0")
''', encoding="utf-8")
        (consumer / "BUILD.bazel").write_text('''
load("@rules_cc//cc:cc_library.bzl", "cc_library")
cc_library(name = "empty")
''', encoding="utf-8")

        def build(target, phase):
            log = logs / f"{phase}.json"
            subprocess.run([
                bazel, "--batch", "--ignore_all_rc_files",
                "--host_jvm_args=-Djava.net.preferIPv6Addresses=system",
                f"--output_user_root={root / 'bazel'}",
                f"--output_base={output}",
                "build", "--jobs=2", "--noshow_progress", "--color=no",
                # Fetch events omit cache hits, so disable repository caching.
                "--repo_contents_cache=", "--repository_cache=",
                f"--override_module=rules_kotlin={release}",
                f"--build_event_json_file={log}", target,
            ], cwd=consumer, check=True)
            return log

        def metadata_present():
            return any(
                (repo / "capabilities.bzl").is_file() and (repo / "artifacts.bzl").is_file()
                for repo in (output / "external").iterdir()
            )

        self.assert_downloads(build("//:empty", "cpp"), expected=False)
        self.assertFalse(metadata_present(), "Unrelated C++ build materialized Kotlin capabilities")
        self.assert_downloads(
            build("@rules_kotlin//kotlin/internal:default_kotlinc_options", "options"),
            expected=False,
        )
        self.assertTrue(metadata_present(), "Kotlin options did not materialize capabilities")
        self.assertFalse(any((output / "external").glob("*/lib/kotlin-compiler.jar")))
        # Positive control: a real download must be observed by the log checker.
        self.assert_downloads(
            build("@rules_kotlin//kotlin/compiler:kotlin-compiler", "compiler"), expected=True,
        )


if __name__ == "__main__":
    unittest.main()
