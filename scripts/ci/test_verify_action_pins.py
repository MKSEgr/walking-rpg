import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("verify_action_pins.py")
SPEC = importlib.util.spec_from_file_location("verify_action_pins", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


class VerifyActionPinsTest(unittest.TestCase):

    full_sha = "1" * 40
    full_digest = "2" * 64

    def validate(self, workflow: str, *, suffix: str = ".yml") -> list[str]:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / f"workflow{suffix}"
            path.write_text(workflow, encoding="utf-8")
            return MODULE.validate_workflows(Path(directory))

    def test_accepts_commit_pinned_remote_local_and_digest_pinned_docker_actions(self):
        errors = self.validate(
            "jobs:\n"
            "  test:\n"
            "    steps:\n"
            f"      - uses: actions/checkout@{self.full_sha} # v4.4.0\n"
            "      - uses: ./.github/actions/local-check\n"
            f"      - uses: docker://alpine:3.22@sha256:{self.full_digest} # alpine-3.22\n"
        )

        self.assertEqual([], errors)

    def test_rejects_mutable_ambiguous_and_malformed_remote_references(self):
        invalid_references = {
            "moving major tag": "actions/checkout@v4 # v4.4.0",
            "branch": "actions/checkout@main # v4.4.0",
            "short SHA": "actions/checkout@1234567 # v4.4.0",
            "expression": "actions/checkout@${{ matrix.ref }} # v4.4.0",
            "missing version comment": f"actions/checkout@{self.full_sha}",
            "inexact version comment": f"actions/checkout@{self.full_sha} # v4",
            "malformed remote path": f"checkout@{self.full_sha} # v4.4.0",
            "moving Docker tag": "docker://alpine:3.22 # alpine-3.22",
        }

        for description, reference in invalid_references.items():
            with self.subTest(description=description):
                errors = self.validate(
                    "jobs:\n  test:\n    steps:\n"
                    f"      - uses: {reference}\n"
                )
                self.assertTrue(errors)

    def test_scans_both_yaml_extensions(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "valid.yml").write_text(
                f"jobs:\n  test:\n    uses: owner/repository@{self.full_sha} # v1.2.3\n",
                encoding="utf-8",
            )
            (root / "invalid.yaml").write_text(
                "jobs:\n  test:\n    uses: owner/repository@stable # v1.2.3\n",
                encoding="utf-8",
            )

            errors = MODULE.validate_workflows(root)

        self.assertEqual(1, len(errors))
        self.assertIn("invalid.yaml", errors[0])

    def test_rejects_malformed_uses_declaration(self):
        errors = self.validate(
            "jobs:\n  test:\n    steps:\n"
            f"      - uses: actions/checkout@{self.full_sha} unexpected\n"
        )

        self.assertEqual(1, len(errors))
        self.assertIn("malformed uses declaration", errors[0])


if __name__ == "__main__":
    unittest.main()
