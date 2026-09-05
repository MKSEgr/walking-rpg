#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("verify_pr_closing_references.py")
SPEC = importlib.util.spec_from_file_location("verify_pr_closing_references", SCRIPT)
assert SPEC and SPEC.loader
V = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = V
SPEC.loader.exec_module(V)


class PullRequestClosingReferenceTest(unittest.TestCase):
    def test_accepts_safe_relations_and_exact_completion_lines(self) -> None:
        body = (
            "Summary\n\nRelates to #155\nKeeps #154 open\n\n"
            "Closes #571\nCloses #572"
        )
        self.assertEqual((571, 572), V.validate_metadata("Guard PR metadata", body))

    def test_accepts_null_or_reference_free_body(self) -> None:
        self.assertEqual((), V.validate_metadata("Dependency update", None))
        self.assertEqual((), V.validate_metadata("Docs", "Relates to #155"))

    def test_rejects_all_audited_negated_completion_phrases(self) -> None:
        phrases = (
            "This PR does not close #152.",
            "This PR does not close #156.",
            "This PR does not sign a build or close #158.",
            "This PR does not create store records or close #159.",
            "This PR does not claim physical access and does not close #160.",
            "This PR does not run a stage deployment or close #151.",
            "This PR does not restore a backup or close #154.",
            "This PR does not validate operations, or close #155.",
        )
        for phrase in phrases:
            with self.subTest(phrase=phrase), self.assertRaisesRegex(
                V.PullRequestMetadataError, "ambiguous"
            ):
                V.validate_metadata("Repository tooling", phrase)

    def test_rejects_every_github_completion_keyword_variant(self) -> None:
        for keyword in (
            "close", "closes", "closed", "fix", "fixes", "fixed",
            "resolve", "resolves", "resolved",
        ):
            with self.subTest(keyword=keyword), self.assertRaisesRegex(
                V.PullRequestMetadataError, "ambiguous"
            ):
                V.validate_metadata("Metadata", f"We do not {keyword} #155")

    def test_rejects_inline_cross_repository_and_url_references(self) -> None:
        cases = (
            "Summary. Closes #571",
            "Closes:#571",
            "Closes MKSEgr/walking-rpg#571",
            "Fixes: https://github.com/MKSEgr/walking-rpg/issues/571",
        )
        for body in cases:
            with self.subTest(body=body), self.assertRaisesRegex(
                V.PullRequestMetadataError, "ambiguous"
            ):
                V.validate_metadata("Metadata", body)

    def test_rejects_completion_references_in_code_or_quotes(self) -> None:
        cases = (
            "```text\nCloses #571\n```",
            "~~~\nCloses #571\n~~~",
            "> Closes #571",
            "Use `Closes #571` after validation.",
        )
        for body in cases:
            with self.subTest(body=body), self.assertRaisesRegex(
                V.PullRequestMetadataError, "ambiguous"
            ):
                V.validate_metadata("Metadata", body)

    def test_rejects_title_and_duplicate_completion_references(self) -> None:
        with self.assertRaisesRegex(V.PullRequestMetadataError, "title"):
            V.validate_metadata("Fixes #571", "")
        with self.assertRaisesRegex(V.PullRequestMetadataError, "duplicate"):
            V.validate_metadata("Metadata", "Closes #571\nCloses #571")

    def test_event_requires_complete_pull_request_metadata(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "event.json"
            for event in ({}, {"number": 571, "pull_request": {"body": ""}}):
                path.write_text(json.dumps(event), encoding="utf-8")
                with self.assertRaises(V.PullRequestMetadataError):
                    V.validate_event(path)

    def test_event_and_cli_validate_the_same_body(self) -> None:
        event = {
            "number": 571,
            "pull_request": {
                "number": 571,
                "title": "Guard PR metadata",
                "body": "Relates to #155\n\nCloses #571",
            },
        }
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "event.json"
            path.write_text(json.dumps(event), encoding="utf-8")
            self.assertEqual((571,), V.validate_event(path))
            result = subprocess.run(
                [sys.executable, str(SCRIPT), "--event", str(path)],
                capture_output=True,
                text=True,
            )
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn("(#571)", result.stdout)

    def test_duplicate_event_keys_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "event.json"
            path.write_text('{"number":571,"number":572}', encoding="utf-8")
            with self.assertRaisesRegex(V.PullRequestMetadataError, "duplicate"):
                V.validate_event(path)


if __name__ == "__main__":
    unittest.main()
