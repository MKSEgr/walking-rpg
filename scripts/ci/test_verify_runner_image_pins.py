import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("verify_runner_image_pins.py")
SPEC = importlib.util.spec_from_file_location("verify_runner_image_pins", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


class VerifyRunnerImagePinsTest(unittest.TestCase):

    def validate(self, workflow: str, *, suffix: str = ".yml") -> list[str]:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / f"workflow{suffix}"
            path.write_text(workflow, encoding="utf-8")
            return MODULE.validate_workflows(Path(directory))

    def test_accepts_reviewed_literal_runner_labels(self):
        errors = self.validate(
            "jobs:\n"
            "  linux:\n"
            "    runs-on: ubuntu-24.04\n"
            "    steps: []\n"
            "  mac:\n"
            "    runs-on: 'macos-26'\n"
            "    steps: []\n"
        )

        self.assertEqual([], errors)

    def test_accepts_structurally_parsed_flow_and_escaped_runs_on_keys(self):
        errors = self.validate(
            "jobs:\n"
            "  linux: { runs-on: ubuntu-24.04, steps: [] }\n"
            '  mac: { "runs\\u002don": macos-26, steps: [] }\n'
        )

        self.assertEqual([], errors)

    def test_accepts_yaml_1_2_string_job_ids_tagged_as_booleans_by_pyyaml(self):
        for job_id in ("on", "off", "yes", "no", "ON", "Off", "YES", "No"):
            with self.subTest(job_id=job_id):
                errors = self.validate(
                    f"jobs:\n  {job_id}:\n"
                    "    runs-on: ubuntu-24.04\n"
                )

                self.assertEqual([], errors)

    def test_rejects_yaml_1_2_boolean_and_null_job_ids(self):
        for job_id in ("true", "false", "null", "True", "FALSE", "NULL"):
            with self.subTest(job_id=job_id):
                errors = self.validate(
                    f"jobs:\n  {job_id}:\n"
                    "    runs-on: ubuntu-24.04\n"
                )

                self.assertEqual(1, len(errors))
                self.assertIn("workflow job id must be a YAML 1.2 string", errors[0])

    def test_rejects_job_ids_outside_github_identifier_syntax(self):
        job_ids = ("123", "-leading", '"has space"', '"contains.dot"')

        for job_id in job_ids:
            with self.subTest(job_id=job_id):
                errors = self.validate(
                    f"jobs:\n  {job_id}:\n"
                    "    runs-on: ubuntu-24.04\n"
                )

                self.assertEqual(1, len(errors))
                self.assertIn("workflow job id must be a YAML 1.2 string", errors[0])

    def test_rejects_mutable_and_unreviewed_runner_labels(self):
        labels = (
            "ubuntu-latest",
            "macos-latest",
            "ubuntu-26.04",
            "macos-15",
            "self-hosted",
            "${{ matrix.os }}",
        )

        for label in labels:
            with self.subTest(label=label):
                errors = self.validate(
                    "jobs:\n  test:\n"
                    f"    runs-on: {label}\n"
                )
                self.assertTrue(errors)
                self.assertIn("unreviewed runner label", errors[-1])

    def test_rejects_sequence_mapping_and_multiline_runner_values(self):
        declarations = {
            "sequence": "    runs-on: [ubuntu-24.04]\n",
            "mapping": "    runs-on: {label: ubuntu-24.04}\n",
            "multiline": "    runs-on: >-\n      ubuntu-24.04\n",
        }

        for description, declaration in declarations.items():
            with self.subTest(description=description):
                errors = self.validate("jobs:\n  test:\n" + declaration)
                self.assertTrue(errors)
                self.assertIn("runs-on must be", errors[-1])

    def test_rejects_missing_or_malformed_jobs_and_runner_declarations(self):
        workflows = {
            "missing jobs": "name: empty\n",
            "empty jobs": "jobs: {}\n",
            "sequence jobs": "jobs: []\n",
            "scalar job": "jobs:\n  test: invalid\n",
            "missing runs-on": "jobs:\n  test:\n    steps: []\n",
        }

        for description, workflow in workflows.items():
            with self.subTest(description=description):
                self.assertTrue(self.validate(workflow))

    def test_rejects_anchors_aliases_and_merge_keys(self):
        workflows = {
            "runner alias": (
                "runner: &runner ubuntu-24.04\n"
                "jobs:\n  test:\n    runs-on: *runner\n"
            ),
            "mapping merge": (
                "defaults: &defaults\n  runs-on: ubuntu-24.04\n"
                "jobs:\n  test:\n    <<: *defaults\n"
            ),
            "recursive alias": (
                "jobs: &jobs\n"
                "  test:\n"
                "    runs-on: ubuntu-24.04\n"
                "    metadata: *jobs\n"
            ),
        }

        for description, workflow in workflows.items():
            with self.subTest(description=description):
                errors = self.validate(workflow)
                self.assertTrue(errors)
                self.assertTrue(
                    any("anchors and aliases" in error for error in errors)
                )

    def test_rejects_duplicate_keys_in_block_and_flow_mappings(self):
        workflows = {
            "duplicate job": (
                "jobs:\n"
                "  test:\n    runs-on: ubuntu-24.04\n"
                "  test:\n    runs-on: macos-26\n"
            ),
            "duplicate runs-on": (
                "jobs:\n  test: { runs-on: ubuntu-24.04, "
                "runs-on: macos-26 }\n"
            ),
            "escaped duplicate runs-on": (
                "jobs:\n  test: { runs-on: ubuntu-24.04, "
                '"runs\\u002don": macos-26 }\n'
            ),
        }

        for description, workflow in workflows.items():
            with self.subTest(description=description):
                errors = self.validate(workflow)
                self.assertTrue(
                    any("duplicate YAML key" in error for error in errors)
                )

    def test_scans_both_extensions_and_every_extra_workflow_job(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "valid.yml").write_text(
                "jobs:\n  test:\n    runs-on: ubuntu-24.04\n",
                encoding="utf-8",
            )
            (root / "extra.yaml").write_text(
                "jobs:\n"
                "  first:\n    runs-on: macos-26\n"
                "  hidden:\n    runs-on: ubuntu-latest\n",
                encoding="utf-8",
            )

            errors = MODULE.validate_workflows(root)

        self.assertEqual(1, len(errors))
        self.assertIn("extra.yaml", errors[0])
        self.assertIn("hidden", errors[0])

    def test_rejects_invalid_and_multiple_yaml_documents(self):
        invalid = self.validate("jobs:\n  test:\n    runs-on: [unterminated\n")
        multiple = self.validate(
            "jobs:\n  first:\n    runs-on: ubuntu-24.04\n"
            "---\n"
            "jobs:\n  second:\n    runs-on: macos-26\n"
        )

        self.assertEqual(1, len(invalid))
        self.assertIn("invalid workflow YAML", invalid[0])
        self.assertEqual(1, len(multiple))
        self.assertIn("exactly one YAML document", multiple[0])

    def test_fails_closed_without_workflow_files(self):
        with tempfile.TemporaryDirectory() as directory:
            errors = MODULE.validate_workflows(Path(directory))

        self.assertEqual(1, len(errors))
        self.assertIn("no workflow YAML files found", errors[0])

    def test_fails_closed_on_unexpected_parser_version(self):
        original = MODULE.yaml.__version__
        MODULE.yaml.__version__ = "0.0.0"
        try:
            errors = self.validate(
                "jobs:\n  test:\n    runs-on: ubuntu-24.04\n"
            )
        finally:
            MODULE.yaml.__version__ = original

        self.assertEqual(1, len(errors))
        self.assertIn("requires PyYAML", errors[0])


if __name__ == "__main__":
    unittest.main()
