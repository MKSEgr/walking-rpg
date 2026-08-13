import hashlib
import importlib.util
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import threading
import unittest
import zipfile
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


SCRIPT = Path(__file__).with_name("verify_build_tool_wrapper_pins.py")
SPEC = importlib.util.spec_from_file_location("verify_build_tool_wrapper_pins", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


def properties_source(values: dict[str, str]) -> str:
    return "".join(f"{key}={value}\n" for key, value in values.items())


class QuietFileHandler(SimpleHTTPRequestHandler):
    def log_message(self, format: str, *args: object) -> None:
        pass


class VerifyBuildToolWrapperPinsTest(unittest.TestCase):

    def test_repository_contract_passes(self):
        self.assertEqual([], MODULE.validate_repository())

    def test_accepts_exact_reviewed_property_sets(self):
        self.assertEqual(
            [],
            MODULE.validate_properties_source(
                properties_source(MODULE.APPROVED_MAVEN_PROPERTIES),
                MODULE.APPROVED_MAVEN_PROPERTIES,
                Path("maven-wrapper.properties"),
            ),
        )
        self.assertEqual(
            [],
            MODULE.validate_properties_source(
                properties_source(MODULE.APPROVED_GRADLE_PROPERTIES),
                MODULE.APPROVED_GRADLE_PROPERTIES,
                Path("gradle-wrapper.properties"),
            ),
        )

    def test_rejects_missing_and_duplicate_checksum_properties(self):
        expected = MODULE.APPROVED_MAVEN_PROPERTIES
        without_checksum = {
            key: value
            for key, value in expected.items()
            if key != "distributionSha256Sum"
        }
        self.assertTrue(
            MODULE.validate_properties_source(
                properties_source(without_checksum), expected, Path("wrapper.properties")
            )
        )

        source = properties_source(expected) + (
            f"distributionSha256Sum={expected['distributionSha256Sum']}\n"
        )
        errors = MODULE.validate_properties_source(
            source, expected, Path("wrapper.properties")
        )
        self.assertTrue(any("duplicate property" in error for error in errors))

    def test_rejects_changed_urls_and_checksums(self):
        for expected in (
            MODULE.APPROVED_MAVEN_PROPERTIES,
            MODULE.APPROVED_GRADLE_PROPERTIES,
        ):
            for key, value in (
                ("distributionUrl", "https://example.invalid/tool.zip"),
                ("distributionSha256Sum", "A" * 64),
                ("distributionSha256Sum", "0" * 63),
            ):
                with self.subTest(properties=expected, key=key, value=value):
                    changed = dict(expected)
                    changed[key] = value
                    self.assertTrue(
                        MODULE.validate_properties_source(
                            properties_source(changed),
                            expected,
                            Path("wrapper.properties"),
                        )
                    )

    def test_gradle_cache_namespace_is_bound_to_distribution_checksum(self):
        expected = MODULE.APPROVED_GRADLE_PROPERTIES
        checksum = expected["distributionSha256Sum"]
        checksum_cache = f"wrapper/dists/sha256-{checksum}"

        self.assertEqual(checksum_cache, expected["distributionPath"])
        self.assertEqual(checksum_cache, expected["zipStorePath"])

        for key in ("distributionPath", "zipStorePath"):
            with self.subTest(key=key):
                legacy_cache = dict(expected)
                legacy_cache[key] = "wrapper/dists"
                errors = MODULE.validate_properties_source(
                    properties_source(legacy_cache),
                    expected,
                    Path("gradle-wrapper.properties"),
                )
                self.assertTrue(
                    any(
                        f"{key} must equal the reviewed value" in error
                        for error in errors
                    )
                )

    def test_rejects_unknown_or_noncanonical_properties(self):
        expected = MODULE.APPROVED_MAVEN_PROPERTIES
        source = properties_source(expected) + "networkTimeout=10000\n"
        self.assertTrue(
            MODULE.validate_properties_source(source, expected, Path("wrapper.properties"))
        )
        source = properties_source(expected).replace(
            "distributionType=only-script",
            "distributionType =only-script",
        )
        self.assertTrue(
            MODULE.validate_properties_source(source, expected, Path("wrapper.properties"))
        )

    def test_rejects_modified_gradle_wrapper_jar(self):
        content = MODULE.GRADLE_WRAPPER_JAR.read_bytes()
        self.assertEqual(
            MODULE.APPROVED_GRADLE_WRAPPER_SHA256,
            hashlib.sha256(content).hexdigest(),
        )
        self.assertTrue(
            MODULE.validate_wrapper_jar_bytes(content + b"changed", Path("wrapper.jar"))
        )

    def test_rejects_launcher_checksum_bypass_or_late_verification(self):
        shell_source = MODULE.MAVEN_SHELL.read_text(encoding="utf-8")
        powershell_source = MODULE.MAVEN_POWERSHELL.read_text(encoding="utf-8")
        self.assertEqual(
            [], MODULE.validate_launcher_sources(shell_source, powershell_source)
        )
        self.assertTrue(
            MODULE.validate_launcher_sources(
                shell_source.replace(
                    'echo "Maven distribution SHA-256 mismatch"',
                    'echo "download failed"',
                ),
                powershell_source,
            )
        )
        self.assertTrue(
            MODULE.validate_launcher_sources(
                shell_source,
                powershell_source.replace(
                    "        if ($ActualSha256Sum -cne $DistributionSha256Sum) {",
                    "Expand-Archive -Path $Archive -DestinationPath $TempRoot -Force\n"
                    "        if ($ActualSha256Sum -cne $DistributionSha256Sum) {",
                    1,
                ),
            )
        )

    def _run_maven_fixture(
        self,
        *,
        configured_checksums: tuple[str, ...] | None,
        force_jar_extractor: bool = False,
    ) -> tuple[subprocess.CompletedProcess[str], Path, Path]:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        project = root / "backend"
        wrapper_dir = project / ".mvn" / "wrapper"
        wrapper_dir.mkdir(parents=True)
        wrapper = project / "mvnw"
        shutil.copyfile(MODULE.MAVEN_SHELL, wrapper)
        wrapper.chmod(wrapper.stat().st_mode | stat.S_IXUSR)

        distribution_dir = root / "apache-maven" / "fixture"
        distribution_dir.mkdir(parents=True)
        archive = distribution_dir / "apache-maven-fixture-bin.zip"
        marker = root / "maven-executed"
        executable = (
            "#!/usr/bin/env sh\n"
            ': > "$FAKE_MAVEN_MARKER"\n'
            "printf 'fixture:%s\\n' \"$*\"\n"
        )
        entry = zipfile.ZipInfo("apache-maven-fixture/bin/mvn")
        entry.create_system = 3
        entry.external_attr = (stat.S_IFREG | 0o755) << 16
        with zipfile.ZipFile(archive, "w") as fixture_zip:
            fixture_zip.writestr(entry, executable)
        actual_checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
        checksum_values = (
            (actual_checksum,)
            if configured_checksums is None
            else configured_checksums
        )
        checksum_lines = "".join(
            f"distributionSha256Sum={checksum}\n" for checksum in checksum_values
        )

        (wrapper_dir / "maven-wrapper.properties").write_text(
            "wrapperVersion=3.3.4\n"
            "distributionType=only-script\n"
            f"distributionUrl={archive.as_uri()}\n"
            f"{checksum_lines}",
            encoding="utf-8",
        )
        cache = root / "cache"
        temporary_root = root / "tmp"
        temporary_root.mkdir()
        environment = os.environ.copy()
        environment["MAVEN_USER_HOME"] = str(cache)
        environment["FAKE_MAVEN_MARKER"] = str(marker)
        environment["TMPDIR"] = str(temporary_root)
        if force_jar_extractor:
            restricted_path = root / "jar-only-path"
            restricted_path.mkdir()
            for command in (
                "chmod",
                "curl",
                "dirname",
                "grep",
                "mkdir",
                "mktemp",
                "mv",
                "python3",
                "rm",
                "sed",
                "sh",
                "sha256sum",
            ):
                executable_path = shutil.which(command)
                self.assertIsNotNone(executable_path, command)
                (restricted_path / command).symlink_to(executable_path)
            jar = restricted_path / "jar"
            jar.write_text(
                "#!/bin/sh\n"
                "set -eu\n"
                "test \"$1\" = xf\n"
                "printf '%s\\n' 'fixture jar extractor selected' >&2\n"
                "exec python3 -m zipfile -e \"$2\" .\n",
                encoding="utf-8",
            )
            jar.chmod(jar.stat().st_mode | stat.S_IXUSR)
            environment["PATH"] = str(restricted_path)
        result = subprocess.run(
            [str(wrapper), "alpha", "beta"],
            cwd=project,
            env=environment,
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
        return result, marker, cache

    def test_maven_shell_executes_verified_fixture(self):
        result, marker, _ = self._run_maven_fixture(configured_checksums=None)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual("fixture:alpha beta\n", result.stdout)
        self.assertTrue(marker.is_file())

    def test_maven_shell_uses_jdk_jar_when_unzip_is_unavailable(self):
        result, marker, _ = self._run_maven_fixture(
            configured_checksums=None,
            force_jar_extractor=True,
        )

        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn("fixture jar extractor selected", result.stderr)
        self.assertEqual("fixture:alpha beta\n", result.stdout)
        self.assertTrue(marker.is_file())

    def test_maven_shell_rejects_mismatch_before_install_or_execution(self):
        for force_jar_extractor in (False, True):
            with self.subTest(force_jar_extractor=force_jar_extractor):
                result, marker, cache = self._run_maven_fixture(
                    configured_checksums=("0" * 64,),
                    force_jar_extractor=force_jar_extractor,
                )
                self.assertNotEqual(0, result.returncode)
                self.assertIn("Maven distribution SHA-256 mismatch", result.stderr)
                self.assertNotIn("fixture jar extractor selected", result.stderr)
                self.assertFalse(marker.exists())
                self.assertFalse(any(cache.rglob("bin/mvn")))

    def test_maven_shell_rejects_missing_duplicate_and_malformed_checksums(self):
        invalid = (
            ((), "Exactly one distributionSha256Sum"),
            (("0" * 64, "1" * 64), "Exactly one distributionSha256Sum"),
            (("A" * 64,), "64 lowercase hexadecimal characters"),
            (("0" * 63,), "64 lowercase hexadecimal characters"),
        )
        for checksums, expected_error in invalid:
            with self.subTest(checksums=checksums):
                result, marker, cache = self._run_maven_fixture(
                    configured_checksums=checksums
                )
                self.assertNotEqual(0, result.returncode)
                self.assertIn(expected_error, result.stderr)
                self.assertFalse(marker.exists())
                self.assertFalse(any(cache.rglob("bin/mvn")))

    def test_maven_powershell_rejects_mismatch_before_extraction(self):
        powershell = shutil.which("pwsh")
        if powershell is None:
            if os.environ.get("GITHUB_ACTIONS") == "true":
                self.fail("GitHub policy job must provide PowerShell 7")
            self.skipTest("PowerShell 7 is not available")
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            project = root / "backend"
            wrapper_dir = project / ".mvn" / "wrapper"
            wrapper_dir.mkdir(parents=True)
            wrapper = wrapper_dir / "mvnw.ps1"
            shutil.copyfile(MODULE.MAVEN_POWERSHELL, wrapper)

            distribution_dir = root / "apache-maven" / "fixture"
            distribution_dir.mkdir(parents=True)
            archive = distribution_dir / "apache-maven-fixture-bin.zip"
            with zipfile.ZipFile(archive, "w") as fixture_zip:
                fixture_zip.writestr(
                    "apache-maven-fixture/bin/mvn.cmd", "@echo off\r\n"
                )

            handler = partial(QuietFileHandler, directory=str(root))
            server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                port = server.server_address[1]
                (wrapper_dir / "maven-wrapper.properties").write_text(
                    "wrapperVersion=3.3.4\n"
                    "distributionType=only-script\n"
                    "distributionUrl=http://127.0.0.1:"
                    f"{port}/apache-maven/fixture/{archive.name}\n"
                    f"distributionSha256Sum={'0' * 64}\n",
                    encoding="utf-8",
                )
                temporary_root = root / "tmp"
                temporary_root.mkdir()
                environment = os.environ.copy()
                environment["HOME"] = str(root)
                environment["USERPROFILE"] = str(root)
                environment["TMPDIR"] = str(temporary_root)
                environment["TEMP"] = str(temporary_root)
                result = subprocess.run(
                    [
                        powershell,
                        "-NoLogo",
                        "-NoProfile",
                        "-File",
                        str(wrapper),
                    ],
                    cwd=project,
                    env=environment,
                    capture_output=True,
                    text=True,
                    timeout=30,
                    check=False,
                )
            finally:
                server.shutdown()
                server.server_close()
                thread.join(timeout=5)

            self.assertNotEqual(0, result.returncode)
            self.assertIn(
                "Maven distribution SHA-256 mismatch",
                result.stdout + result.stderr,
            )
            self.assertFalse(any(root.rglob("bin/mvn.cmd")))


if __name__ == "__main__":
    unittest.main()
