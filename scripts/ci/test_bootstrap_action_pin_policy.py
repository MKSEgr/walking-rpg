import json
import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BOOTSTRAP = ROOT / "scripts" / "bootstrap-action-pin-policy.sh"
VERIFY_PROJECT = ROOT / "scripts" / "verify-project.sh"
REQUIREMENTS = ROOT / "scripts" / "ci" / "action-pin-policy-requirements.txt"

FAKE_PYTHON = r'''#!/usr/bin/env python3
import json
import os
import shutil
import stat
import sys
from pathlib import Path

args = sys.argv[1:]
with Path(os.environ["FAKE_PYTHON_LOG"]).open("a", encoding="utf-8") as log:
    log.write(json.dumps(args) + "\n")

if args and args[0] == "-c":
    if "sys.version_info" in args[1] and os.environ.get("FAKE_VERSION_OK") != "1":
        raise SystemExit(1)
    raise SystemExit(0)

if args[:2] == ["-m", "venv"]:
    target = Path(args[2]) / "bin" / "python"
    target.parent.mkdir(parents=True)
    shutil.copyfile(__file__, target)
    target.chmod(target.stat().st_mode | stat.S_IXUSR)
    raise SystemExit(0)

raise SystemExit(0)
'''


class BootstrapActionPinPolicyTest(unittest.TestCase):

    def fake_python(self, directory: Path) -> tuple[Path, Path]:
        executable = directory / "python3"
        executable.write_text(FAKE_PYTHON, encoding="utf-8")
        executable.chmod(executable.stat().st_mode | stat.S_IXUSR)
        return executable, directory / "invocations.jsonl"

    def test_bootstraps_isolated_hash_pinned_environment(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            python, log = self.fake_python(root)
            venv = root / "action-pin-policy"
            environment = os.environ.copy()
            environment.update(
                {
                    "PYTHON": str(python),
                    "ACTION_PIN_POLICY_VENV": str(venv),
                    "FAKE_PYTHON_LOG": str(log),
                    "FAKE_VERSION_OK": "1",
                }
            )

            subprocess.run(
                ["sh", str(BOOTSTRAP)],
                check=True,
                capture_output=True,
                text=True,
                env=environment,
            )

            invocations = [
                json.loads(line)
                for line in log.read_text(encoding="utf-8").splitlines()
            ]
            pip = next(args for args in invocations if args[:2] == ["-m", "pip"])
            self.assertIn("--only-binary=:all:", pip)
            self.assertIn("--require-hashes", pip)
            self.assertEqual(str(REQUIREMENTS), pip[pip.index("-r") + 1])
            self.assertTrue((venv / "bin" / "python").is_file())

    def test_rejects_unpinned_python_minor_before_creating_venv(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            python, log = self.fake_python(root)
            venv = root / "action-pin-policy"
            environment = os.environ.copy()
            environment.update(
                {
                    "PYTHON": str(python),
                    "ACTION_PIN_POLICY_VENV": str(venv),
                    "FAKE_PYTHON_LOG": str(log),
                    "FAKE_VERSION_OK": "0",
                }
            )

            result = subprocess.run(
                ["sh", str(BOOTSTRAP)],
                check=False,
                capture_output=True,
                text=True,
                env=environment,
            )

            self.assertNotEqual(0, result.returncode)
            self.assertIn("requires Python 3.12", result.stderr)
            self.assertFalse(venv.exists())

    def test_verify_project_bootstraps_before_action_policy(self):
        source = VERIFY_PROJECT.read_text(encoding="utf-8")
        bootstrap = source.index("bootstrap-action-pin-policy.sh")
        verification = source.index(
            '"$ACTION_POLICY_PYTHON" "$ROOT_DIR/scripts/ci/verify_action_pins.py"'
        )

        self.assertLess(bootstrap, verification)
        self.assertIn(
            '"$ACTION_POLICY_PYTHON" '
            '"$ROOT_DIR/scripts/ci/test_verify_action_pins.py"',
            source,
        )

    def test_verify_project_uses_pinned_parser_for_every_yaml_policy(self):
        source = VERIFY_PROJECT.read_text(encoding="utf-8")

        for policy in (
            "verify_postgres_image_pins.py",
            "test_verify_postgres_image_pins.py",
            "verify_action_pins.py",
            "test_verify_action_pins.py",
        ):
            with self.subTest(policy=policy):
                invocation = (
                    '"$ACTION_POLICY_PYTHON" '
                    f'"$ROOT_DIR/scripts/ci/{policy}"'
                )
                self.assertIn(invocation, source)
                self.assertNotIn(
                    f'python3 "$ROOT_DIR/scripts/ci/{policy}"',
                    source,
                )


if __name__ == "__main__":
    unittest.main()
