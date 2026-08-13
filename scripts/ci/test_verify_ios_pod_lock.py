import hashlib
import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("verify_ios_pod_lock.py")
SPEC = importlib.util.spec_from_file_location("verify_ios_pod_lock", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


class VerifyIosPodLockTest(unittest.TestCase):
    podfile_source = "platform :ios, '14.0'\n"

    def lock_source(self, **replacements: str) -> str:
        checksum = hashlib.sha1(self.podfile_source.encode()).hexdigest()
        source = (
            "PODS:\n"
            "  - AppAuth (2.0.0):\n"
            "    - AppAuth/Core (= 2.0.0)\n"
            "  - AppAuth/Core (2.0.0)\n"
            "  - Flutter (1.0.0)\n"
            "  - flutter_appauth (0.0.1):\n"
            "    - AppAuth (>= 1.7.2)\n"
            "    - Flutter\n\n"
            "DEPENDENCIES:\n"
            "  - Flutter (from `Flutter`)\n"
            "  - flutter_appauth (from `.symlinks/plugins/flutter_appauth/ios`)\n\n"
            "SPEC REPOS:\n"
            "  trunk:\n"
            "    - AppAuth\n\n"
            "EXTERNAL SOURCES:\n"
            "  Flutter:\n"
            "    :path: Flutter\n"
            "  flutter_appauth:\n"
            "    :path: .symlinks/plugins/flutter_appauth/ios\n\n"
            "SPEC CHECKSUMS:\n"
            f"  AppAuth: {'a1' * 20}\n"
            f"  Flutter: {'b2' * 20}\n"
            f"  flutter_appauth: {'c3' * 20}\n\n"
            f"PODFILE CHECKSUM: {checksum}\n\n"
            "COCOAPODS: 1.17.0\n"
        )
        for old, new in replacements.items():
            source = source.replace(old, new)
        return source

    def validate_lock(self, source: str, *, podfile: str | None = None) -> list[str]:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            lock = root / "Podfile.lock"
            pod = root / "Podfile"
            lock.write_text(source, encoding="utf-8")
            pod.write_text(podfile or self.podfile_source, encoding="utf-8")
            return MODULE.validate_lockfile(
                lock,
                pod,
                approved_sha256=hashlib.sha256(source.encode()).hexdigest(),
            )

    @staticmethod
    def job(build_command: str = "flutter build ios --release --no-codesign") -> str:
        return (
            "    runs-on: macos-26\n"
            "    defaults:\n"
            "      run:\n"
            "        working-directory: mobile\n"
            "    steps:\n"
            "      - name: Install dependencies\n"
            "        run: flutter pub get --enforce-lockfile\n"
            "      - name: Install locked iOS pods\n"
            "        shell: bash\n"
            "        run: |\n"
            "          set -euo pipefail\n"
            "          cd ios\n"
            "          test \"$(pod --version)\" = '1.17.0'\n"
            "          pod install --deployment\n"
            "          git diff --exit-code -- Podfile.lock\n"
            "      - name: Build iOS\n"
            f"        run: {build_command}\n"
            "      - name: Verify iOS pod lock unchanged\n"
            "        shell: bash\n"
            "        run: git diff --exit-code -- ios/Podfile.lock\n"
        )

    def validate_workflows(self, files: dict[str, str]) -> list[str]:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name, source in files.items():
                (root / name).write_text(source, encoding="utf-8")
            return MODULE.validate_workflows(root)

    def valid_workflows(self) -> dict[str, str]:
        return {
            "ci.yml": "jobs:\n  ios-host:\n" + self.job("flutter build ios --simulator --debug"),
            "release-quality.yml": "jobs:\n  ios-release:\n" + self.job(),
        }

    def test_accepts_reviewed_lock_and_frozen_workflows(self):
        source = self.lock_source()
        self.assertEqual([], self.validate_lock(source))
        self.assertEqual([], self.validate_workflows(self.valid_workflows()))

    def test_rejects_changed_lock_bytes(self):
        source = self.lock_source()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            lock = root / "Podfile.lock"
            pod = root / "Podfile"
            lock.write_text(source + "# changed\n", encoding="utf-8")
            pod.write_text(self.podfile_source, encoding="utf-8")
            errors = MODULE.validate_lockfile(
                lock,
                pod,
                approved_sha256=hashlib.sha256(source.encode()).hexdigest(),
            )
        self.assertTrue(any("reviewed SHA-256" in error for error in errors))

    def test_rejects_stale_podfile_and_cocoapods_version(self):
        stale = self.validate_lock(self.lock_source(), podfile="platform :ios, '15.0'\n")
        version = self.validate_lock(
            self.lock_source(**{"COCOAPODS: 1.17.0": "COCOAPODS: 1.18.0"})
        )
        self.assertTrue(any("PODFILE CHECKSUM" in error for error in stale))
        self.assertTrue(any("COCOAPODS" in error for error in version))

    def test_rejects_ranges_bad_checksums_and_unreviewed_sources(self):
        cases = (
            self.lock_source(**{"AppAuth (2.0.0)": "AppAuth (~> 2.0)"}),
            self.lock_source(
                **{"AppAuth: " + "a1" * 20: "AppAuth: short"}
            ),
            self.lock_source(
                **{".symlinks/plugins/flutter_appauth/ios": "https://example.invalid/plugin"}
            ),
        )
        for source in cases:
            with self.subTest(source=source):
                self.assertTrue(self.validate_lock(source))

    def test_rejects_missing_sections_duplicate_keys_aliases_and_documents(self):
        cases = (
            self.lock_source().replace("SPEC REPOS:\n", "MISSING SPEC REPOS:\n"),
            self.lock_source() + "COCOAPODS: 1.17.0\n",
            "value: &value locked\ncopy: *value\n",
            self.lock_source() + "---\nCOCOAPODS: 1.17.0\n",
        )
        for source in cases:
            with self.subTest(source=source):
                self.assertTrue(self.validate_lock(source))

    def test_requires_canonical_deployment_install_and_post_build_diff(self):
        replacements = (
            ("test \"$(pod --version)\" = '1.17.0'", "true"),
            ("pod install --deployment", "pod install"),
            ("pod install --deployment", "pod update"),
            ("git diff --exit-code -- Podfile.lock", "true"),
            ("git diff --exit-code -- ios/Podfile.lock", "true"),
        )
        for old, new in replacements:
            with self.subTest(replacement=new):
                files = self.valid_workflows()
                files["ci.yml"] = files["ci.yml"].replace(old, new)
                self.assertTrue(self.validate_workflows(files))

    def test_rejects_missing_reordered_conditional_and_extra_pod_steps(self):
        cases = []
        missing = self.valid_workflows()
        missing["ci.yml"] = missing["ci.yml"].replace(
            "      - name: Install locked iOS pods\n"
            "        shell: bash\n"
            "        run: |\n"
            "          set -euo pipefail\n"
            "          cd ios\n"
            "          test \"$(pod --version)\" = '1.17.0'\n"
            "          pod install --deployment\n"
            "          git diff --exit-code -- Podfile.lock\n",
            "",
        )
        cases.append(missing)
        reordered = self.valid_workflows()
        reordered["ci.yml"] = reordered["ci.yml"].replace(
            "      - name: Install dependencies\n"
            "        run: flutter pub get --enforce-lockfile\n",
            "",
        ) + (
            "      - name: Late dependencies\n"
            "        run: flutter pub get --enforce-lockfile\n"
        )
        cases.append(reordered)
        conditional = self.valid_workflows()
        conditional["ci.yml"] = conditional["ci.yml"].replace(
            "      - name: Install locked iOS pods\n",
            "      - name: Install locked iOS pods\n        if: ${{ false }}\n",
        )
        cases.append(conditional)
        extra = self.valid_workflows()
        extra["ci.yml"] += "  other:\n    steps:\n      - run: pod install --deployment\n"
        cases.append(extra)
        for files in cases:
            with self.subTest(files=files):
                self.assertTrue(self.validate_workflows(files))

    def test_rejects_wrapped_indented_and_path_qualified_pod_commands(self):
        commands = (
            "bundle exec pod update",
            "sudo pod install",
            "  pod update",
            "/usr/local/bin/pod install",
        )
        for command in commands:
            files = self.valid_workflows()
            files["ci.yml"] += (
                "  unprotected:\n"
                "    steps:\n"
                "      - run: |\n"
                "          true\n"
                f"          {command}\n"
            )
            with self.subTest(command=command):
                self.assertTrue(self.validate_workflows(files))

    def test_rejects_pod_commands_after_cocoapods_options(self):
        commands = (
            "pod --silent update",
            "pod --verbose install",
            "pod --no-ansi update",
            "pod --allow-root install",
            "pod --project-directory=/tmp update",
            "pod -- install",
            "bundle exec pod --no-silent update",
            "/usr/local/bin/pod --no-verbose install",
        )
        for command in commands:
            files = self.valid_workflows()
            files["ci.yml"] += (
                "  unprotected:\n"
                "    steps:\n"
                f"      - run: {command}\n"
            )
            with self.subTest(command=command):
                self.assertTrue(self.validate_workflows(files))

    def test_ignores_non_dependency_pod_option_invocations(self):
        commands = (
            "pod --silent env",
            "pod --verbose",
            "pod -- --silent update",
        )
        for command in commands:
            files = self.valid_workflows()
            files["ci.yml"] += (
                "  harmless:\n"
                "    steps:\n"
                f"      - run: {command}\n"
            )
            with self.subTest(command=command):
                self.assertEqual([], self.validate_workflows(files))

    def test_ignores_non_executable_pod_mentions(self):
        files = self.valid_workflows()
        files["ci.yml"] += (
            "  documentation:\n"
            "    steps:\n"
            "      - run: |\n"
            "          message=\"do not run pod update\"\n"
            "          echo \"$message\"\n"
            "          printf '%s\\n' 'pod install'\n"
            "          echo \"$(printf '%s' 'pod update')\"\n"
            "          bash -c \"echo 'pod install'\"\n"
            "          eval \"printf '%s' 'pod update'\"\n"
            "          echo '$(pod update)'\n"
            "          true # pod install --deployment\n"
            "          # pod update\n"
        )
        self.assertEqual([], self.validate_workflows(files))

    def test_rejects_nested_pod_commands_and_unparseable_shell(self):
        commands = (
            'echo "$(pod update)"',
            "echo \"`pod install`\"",
            "bash -lc 'pod update'",
            "eval 'pod install'",
            "{ /opt/homebrew/bin/pod update; }",
            "env MODE=ci sudo -u root bundle exec pod install",
            "true && command pod update",
            'bash -c "echo \\$(pod install)"',
        )
        for command in commands:
            files = self.valid_workflows()
            files["ci.yml"] += (
                "  unprotected:\n"
                "    steps:\n"
                "      - run: |\n"
                f"          {command}\n"
            )
            with self.subTest(command=command):
                self.assertTrue(self.validate_workflows(files))

        malformed = self.valid_workflows()
        malformed["ci.yml"] += (
            "  malformed:\n"
            "    steps:\n"
            "      - run: |\n"
            "          echo \"unterminated\n"
        )
        self.assertTrue(self.validate_workflows(malformed))

    def test_rejects_pod_commands_in_process_substitutions(self):
        commands = (
            "cat <(pod update)",
            "tee >(pod install)",
            "diff <(command pod update) <(printf safe)",
            "cat <(bash -c 'pod update')",
            "bash -c 'cat <(bundle exec pod install)'",
        )
        for command in commands:
            files = self.valid_workflows()
            files["ci.yml"] += (
                "  unprotected:\n"
                "    steps:\n"
                "      - run: |\n"
                f"          {command}\n"
            )
            with self.subTest(command=command):
                self.assertTrue(self.validate_workflows(files))

    def test_ignores_literal_and_rejects_malformed_process_substitutions(self):
        safe_commands = (
            "printf '%s\\n' '<(pod update)'",
            "printf '%s\\n' \" >(pod install) \"",
            "cat <<< 'pod update'",
            "cat <()",
            "printf '%s\\n' '$((1 + 2))'",
        )
        for command in safe_commands:
            files = self.valid_workflows()
            files["ci.yml"] += (
                "  harmless:\n"
                "    steps:\n"
                f"      - run: {command}\n"
            )
            with self.subTest(command=command):
                self.assertEqual([], self.validate_workflows(files))

        for command in ("cat <(pod update",):
            malformed = self.valid_workflows()
            malformed["ci.yml"] += (
                "  malformed:\n"
                "    steps:\n"
                f"      - run: '{command}'\n"
            )
            with self.subTest(command=command):
                self.assertTrue(self.validate_workflows(malformed))

    def test_rejects_pod_commands_after_prefix_redirections(self):
        commands = (
            ">/tmp/pod.log pod update",
            "2>/dev/null pod install",
            "> /tmp/pod.log command pod update",
            "3>>/tmp/pod.log env MODE=ci sudo pod install",
            "&>/tmp/pod.log /usr/local/bin/pod update",
        )
        for command in commands:
            files = self.valid_workflows()
            files["ci.yml"] += (
                "  unprotected:\n"
                "    steps:\n"
                "      - run: |\n"
                f"          {command}\n"
            )
            with self.subTest(command=command):
                self.assertTrue(self.validate_workflows(files))

    def test_rejects_pod_commands_wrapped_by_xargs_value_options(self):
        commands = (
            "printf x | xargs -n 1 pod install",
            "printf x | xargs --max-args 1 pod update",
            "printf x | xargs -P 2 command pod install",
            "printf x | xargs -J % /usr/local/bin/pod update %",
            "printf x | xargs -tn1 pod install",
            "printf x | xargs --max-args=1 pod update",
        )
        for command in commands:
            files = self.valid_workflows()
            files["ci.yml"] += (
                "  unprotected:\n"
                "    steps:\n"
                f"      - run: {command}\n"
            )
            with self.subTest(command=command):
                self.assertTrue(self.validate_workflows(files))

    def test_ignores_literal_here_document_bodies(self):
        files = self.valid_workflows()
        files["ci.yml"] += (
            "  documentation-here-documents:\n"
            "    steps:\n"
            "      - run: |\n"
            "          cat <<'QUOTED'\n"
            "          pod update\n"
            "          $(pod install)\n"
            "          `pod update`\n"
            "          QUOTED\n"
            "          cat <<PLAIN\n"
            "          pod install\n"
            "          \\$(pod update)\n"
            "          PLAIN\n"
            "          cat <<-TABBED\n"
            "          \tpod update\n"
            "          TABBED\n"
            "          cat <<'FIRST' <<SECOND\n"
            "          pod update\n"
            "          FIRST\n"
            "          pod install\n"
            "          SECOND\n"
        )

        self.assertEqual([], self.validate_workflows(files))

    def test_rejects_executable_here_document_substitutions_and_errors(self):
        scripts = (
            "cat <<EOF\n$(pod update)\nEOF",
            "cat <<EOF\n'$(pod install)'\nEOF",
            "cat <<EOF\n`pod update`\nEOF",
            "cat <<'FIRST' <<SECOND\npod update\nFIRST\n$(pod install)\nSECOND",
            'bash -c "cat <<EOF\n$(pod update)\nEOF\ntrue"',
            "cat <<EOF\nunterminated",
        )
        for script in scripts:
            files = self.valid_workflows()
            indented = "".join(
                f"          {line}\n" for line in script.splitlines()
            )
            files["ci.yml"] += (
                "  unprotected:\n"
                "    steps:\n"
                "      - run: |\n"
                f"{indented}"
            )
            with self.subTest(script=script):
                self.assertTrue(self.validate_workflows(files))

    def test_rejects_continued_here_document_substitution_openers(self):
        script = "cat <<EOF\n$\\\n(pod update)\nEOF"
        files = self.valid_workflows()
        indented = "".join(
            f"          {line}\n" for line in script.splitlines()
        )
        files["ci.yml"] += (
            "  unprotected:\n"
            "    steps:\n"
            "      - run: |\n"
            f"{indented}"
        )

        self.assertTrue(self.validate_workflows(files))

    def test_normalizes_only_unescaped_here_document_continuations(self):
        substitutions, errors = MODULE._expanding_here_document_substitutions(
            "$\\\r\n(command pod install)"
        )
        self.assertEqual([], errors)
        self.assertEqual(["command pod install"], substitutions)

        substitutions, errors = MODULE._expanding_here_document_substitutions(
            "$\\\\\n(pod update)"
        )
        self.assertEqual([], errors)
        self.assertEqual([], substitutions)

    def test_rejects_wrong_runner_working_directory_and_job_bypass(self):
        replacements = (
            ("runs-on: macos-26", "runs-on: macos-latest"),
            ("working-directory: mobile", "working-directory: ."),
            ("    steps:\n", "    if: ${{ false }}\n    steps:\n"),
        )
        for old, new in replacements:
            files = self.valid_workflows()
            files["ci.yml"] = files["ci.yml"].replace(old, new, 1)
            with self.subTest(replacement=new):
                self.assertTrue(self.validate_workflows(files))

    def test_rejects_invalid_yaml_duplicate_keys_aliases_and_yaml_extension(self):
        cases = (
            {"ci.yml": "jobs: [unterminated\n", "release-quality.yml": "jobs: {}\n"},
            {
                "ci.yml": "jobs:\n  ios-host:\n" + self.job() + "  ios-host: {}\n",
                "release-quality.yml": "jobs:\n  ios-release:\n" + self.job(),
            },
            {
                "ci.yml": "job: &job\n" + self.job() + "jobs:\n  ios-host: *job\n",
                "release-quality.yml": "jobs:\n  ios-release:\n" + self.job(),
            },
            {
                "ci.yml": "jobs:\n  ios-host:\n" + self.job(),
                "release-quality.yml": "jobs:\n  ios-release:\n" + self.job(),
                "hidden.yaml": "jobs:\n  hidden:\n    steps:\n      - run: pod update\n",
            },
        )
        for files in cases:
            with self.subTest(files=files):
                self.assertTrue(self.validate_workflows(files))

    def test_tracking_requires_lock_and_rejects_ignored_or_generated_paths(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            lock = root / "mobile/ios/Podfile.lock"
            lock.parent.mkdir(parents=True)
            lock.write_text(self.lock_source(), encoding="utf-8")
            missing = MODULE.validate_tracking(root)
            self.assertTrue(any("tracked" in error for error in missing))

            subprocess.run(["git", "-C", str(root), "add", str(lock)], check=True)
            self.assertEqual([], MODULE.validate_tracking(root))

            (root / ".gitignore").write_text(
                "mobile/ios/Podfile.lock\n", encoding="utf-8"
            )
            ignored = MODULE.validate_tracking(root)
            self.assertTrue(any("must not be ignored" in error for error in ignored))

            pods_file = root / "mobile/ios/Pods/generated.txt"
            pods_file.parent.mkdir(parents=True)
            pods_file.write_text("generated\n", encoding="utf-8")
            subprocess.run(
                ["git", "-C", str(root), "add", "-f", str(pods_file)], check=True
            )
            generated = MODULE.validate_tracking(root)
            self.assertTrue(any("must not be tracked" in error for error in generated))

    def test_fails_closed_without_files_or_reviewed_parser(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.assertTrue(
                MODULE.validate_lockfile(root / "Podfile.lock", root / "Podfile")
            )
            self.assertTrue(MODULE.validate_workflows(root))

        original = MODULE.yaml.__version__
        MODULE.yaml.__version__ = "0.0.0"
        try:
            self.assertTrue(self.validate_lock(self.lock_source()))
            self.assertTrue(self.validate_workflows(self.valid_workflows()))
        finally:
            MODULE.yaml.__version__ = original

    def test_repository_matches_reviewed_contract(self):
        self.assertEqual([], MODULE.validate_repository())


if __name__ == "__main__":
    unittest.main()
