import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("verify_workflow_toolchain_pins.py")
SPEC = importlib.util.spec_from_file_location("verify_workflow_toolchain_pins", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


class VerifyWorkflowToolchainPinsTest(unittest.TestCase):

    full_sha = "1" * 40

    def validate(
        self,
        workflow: str,
        *,
        suffix: str = ".yml",
        expected_counts=None,
    ) -> list[str]:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / f"workflow{suffix}"
            path.write_text(workflow, encoding="utf-8")
            return MODULE.validate_workflows(
                Path(directory),
                expected_counts=expected_counts,
            )

    def setup_step(
        self,
        action: str,
        input_name: str,
        version: str,
        *,
        extra: str = "",
    ) -> str:
        return (
            f"      - uses: {action}@{self.full_sha}\n"
            "        with:\n"
            f"          {input_name}: '{version}'\n"
            f"{extra}"
        )

    def test_accepts_reviewed_exact_toolchain_versions(self):
        workflow = (
            "jobs:\n  test:\n    steps:\n"
            + self.setup_step("actions/setup-node", "node-version", "22.23.1")
            + self.setup_step(
                "actions/setup-python", "python-version", "3.12.13"
            )
            + self.setup_step(
                "actions/setup-java",
                "java-version",
                "17.0.19+10",
                extra="          distribution: temurin\n",
            )
            + self.setup_step(
                "actions/setup-java",
                "java-version",
                "21.0.12+8.0.LTS",
                extra="          distribution: 'temurin'\n",
            )
        )

        self.assertEqual([], self.validate(workflow))

    def test_rejects_broad_and_unreviewed_versions(self):
        cases = (
            ("actions/setup-node", "node-version", "22", ""),
            ("actions/setup-python", "python-version", "3.12", ""),
            (
                "actions/setup-java",
                "java-version",
                "17",
                "          distribution: temurin\n",
            ),
            (
                "actions/setup-java",
                "java-version",
                "21.0.11+10",
                "          distribution: temurin\n",
            ),
            (
                "actions/setup-java",
                "java-version",
                "21.0.12+1",
                "          distribution: temurin\n",
            ),
        )
        for action, input_name, version, extra in cases:
            with self.subTest(action=action, version=version):
                errors = self.validate(
                    "jobs:\n  test:\n    steps:\n"
                    + self.setup_step(
                        action,
                        input_name,
                        version,
                        extra=extra,
                    )
                )
                self.assertTrue(
                    any("reviewed exact version" in error for error in errors)
                )

    def test_rejects_broad_versions_for_case_variant_setup_actions(self):
        cases = (
            ("Actions/Setup-Node", "node-version", "22", ""),
            ("ACTIONS/setup-python", "python-version", "3.12", ""),
            (
                "actions/SETUP-JAVA",
                "java-version",
                "21",
                "          distribution: temurin\n",
            ),
        )
        for action, input_name, version, extra in cases:
            with self.subTest(action=action, version=version):
                errors = self.validate(
                    "jobs:\n  test:\n    steps:\n"
                    + self.setup_step(
                        action,
                        input_name,
                        version,
                        extra=extra,
                    )
                )
                self.assertTrue(
                    any("reviewed exact version" in error for error in errors)
                )

    def test_counts_reviewed_case_variant_actions_canonically(self):
        workflow = (
            "jobs:\n  test:\n    steps:\n"
            + self.setup_step("Actions/Setup-Node", "node-version", "22.23.1")
            + self.setup_step(
                "ACTIONS/setup-python", "python-version", "3.12.13"
            )
            + self.setup_step(
                "actions/SETUP-JAVA",
                "java-version",
                "21.0.12+8.0.LTS",
                extra="          distribution: temurin\n",
            )
        )
        expected = {
            ("actions/setup-node", "22.23.1"): 1,
            ("actions/setup-python", "3.12.13"): 1,
            ("actions/setup-java", "21.0.12+8.0.LTS"): 1,
        }

        self.assertEqual(
            [],
            self.validate(workflow, expected_counts=expected),
        )

    def test_ignores_non_toolchain_action_lookalikes(self):
        workflow = (
            "jobs:\n  test:\n    steps:\n"
            "      - uses: ./Actions/setup-node\n"
            "      - uses: docker://actions/setup-python:latest\n"
            f"      - uses: example/setup-java@{self.full_sha}\n"
        )

        self.assertEqual([], self.validate(workflow))

    def test_rejects_missing_version_or_with_mapping(self):
        workflows = (
            "jobs:\n  test:\n    steps:\n"
            f"      - uses: actions/setup-node@{self.full_sha}\n",
            "jobs:\n  test:\n    steps:\n"
            f"      - uses: actions/setup-python@{self.full_sha}\n"
            "        with:\n          cache: pip\n",
            "jobs:\n  test:\n    steps:\n"
            f"      - uses: actions/setup-java@{self.full_sha}\n"
            "        with: invalid\n",
        )
        for workflow in workflows:
            with self.subTest(workflow=workflow):
                self.assertTrue(self.validate(workflow))

    def test_rejects_non_string_expression_and_multiline_versions(self):
        declarations = (
            "          java-version: 21\n          distribution: temurin\n",
            "          node-version: ${{ matrix.node }}\n",
            "          python-version: >-\n            3.12.13\n",
        )
        actions = (
            "actions/setup-java",
            "actions/setup-node",
            "actions/setup-python",
        )
        for action, declaration in zip(actions, declarations, strict=True):
            with self.subTest(action=action):
                errors = self.validate(
                    "jobs:\n  test:\n    steps:\n"
                    f"      - uses: {action}@{self.full_sha}\n"
                    "        with:\n"
                    + declaration
                )
                self.assertTrue(errors)

    def test_requires_exact_temurin_distribution(self):
        for declaration in ("", "          distribution: zulu\n"):
            with self.subTest(declaration=declaration):
                errors = self.validate(
                    "jobs:\n  test:\n    steps:\n"
                    + self.setup_step(
                        "actions/setup-java",
                        "java-version",
                        "21.0.12+8.0.LTS",
                        extra=declaration,
                    )
                )
                self.assertTrue(errors)
                self.assertTrue(
                    any("distribution" in error for error in errors)
                )

    def test_rejects_duplicate_keys_anchors_aliases_and_merge_keys(self):
        workflows = (
            "jobs:\n  test:\n    steps:\n"
            f"      - uses: actions/setup-node@{self.full_sha}\n"
            "        with: { node-version: '22.23.1', node-version: '22' }\n",
            "version: &version '22.23.1'\n"
            "jobs:\n  test:\n    steps:\n"
            f"      - uses: actions/setup-node@{self.full_sha}\n"
            "        with:\n          node-version: *version\n",
            "defaults: &defaults\n  python-version: '3.12.13'\n"
            "jobs:\n  test:\n    steps:\n"
            f"      - uses: actions/setup-python@{self.full_sha}\n"
            "        with:\n          <<: *defaults\n",
        )
        for workflow in workflows:
            with self.subTest(workflow=workflow):
                errors = self.validate(workflow)
                self.assertTrue(errors)
                self.assertTrue(
                    any(
                        marker in error
                        for marker in (
                            "duplicate YAML key",
                            "anchors and aliases",
                            "merge keys",
                        )
                        for error in errors
                    )
                )

    def test_enforces_reviewed_occurrence_matrix(self):
        workflow = (
            "jobs:\n  test:\n    steps:\n"
            + self.setup_step("actions/setup-node", "node-version", "22.23.1")
        )
        expected = {("actions/setup-node", "22.23.1"): 2}

        errors = self.validate(workflow, expected_counts=expected)

        self.assertTrue(any("expected 2 occurrence" in error for error in errors))

    def test_occurrence_matrix_rejects_an_unexpected_setup_version(self):
        workflow = (
            "jobs:\n  test:\n    steps:\n"
            + self.setup_step("actions/setup-node", "node-version", "22.23.1")
        )

        errors = self.validate(workflow, expected_counts={})

        self.assertTrue(any("expected 0 occurrence" in error for error in errors))

    def test_scans_both_yaml_extensions(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "valid.yml").write_text("jobs: {}\n", encoding="utf-8")
            (root / "hidden.yaml").write_text(
                "jobs:\n  test:\n    steps:\n"
                + self.setup_step(
                    "actions/setup-python", "python-version", "3.12"
                ),
                encoding="utf-8",
            )

            errors = MODULE.validate_workflows(root, expected_counts=None)

        self.assertTrue(any("hidden.yaml" in error for error in errors))

    def test_rejects_invalid_and_multiple_yaml_documents(self):
        invalid = self.validate("jobs:\n  test: [unterminated\n")
        multiple = self.validate("jobs: {}\n---\njobs: {}\n")

        self.assertEqual(1, len(invalid))
        self.assertIn("invalid workflow YAML", invalid[0])
        self.assertEqual(1, len(multiple))
        self.assertIn("exactly one YAML document", multiple[0])

    def test_fails_closed_without_workflows_or_reviewed_parser(self):
        with tempfile.TemporaryDirectory() as directory:
            errors = MODULE.validate_workflows(Path(directory))
        self.assertEqual(1, len(errors))
        self.assertIn("no workflow YAML files found", errors[0])

        original = MODULE.yaml.__version__
        MODULE.yaml.__version__ = "0.0.0"
        try:
            errors = self.validate("jobs: {}\n")
        finally:
            MODULE.yaml.__version__ = original
        self.assertEqual(1, len(errors))
        self.assertIn("requires PyYAML", errors[0])

    def test_repository_workflows_match_the_reviewed_matrix(self):
        self.assertEqual(
            [],
            MODULE.validate_workflows(MODULE.DEFAULT_WORKFLOW_DIRECTORY),
        )


if __name__ == "__main__":
    unittest.main()
