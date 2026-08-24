#!/usr/bin/env python3
"""Regression tests for the internal-alpha decision contract."""

from __future__ import annotations

import copy
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
VALIDATOR = HERE / "verify_internal_alpha_decision.py"
TEMPLATE = ROOT / "docs/evidence/internal-alpha-decision-template.json"
SPEC = importlib.util.spec_from_file_location("decision_validator", VALIDATOR)
assert SPEC and SPEC.loader
validator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(validator)


def decided() -> dict:
    document = json.loads(TEMPLATE.read_text(encoding="utf-8"))
    document.update({
        "recordStatus": "DECIDED",
        "recordedAtUtc": "2026-08-20T08:00:00Z",
        "decisionAtUtc": "2026-08-20T09:00:00Z",
    })
    document["protocol"]["commitSha"] = "1" * 40
    document["candidate"] = {
        "sourceSha": "2" * 40,
        "treeSha": "3" * 40,
        "kickoffRecordSha256": "4" * 64,
        "alphaEvidencePackageSha256": "5" * 64,
    }
    document["cohort"] = {
        "invited": 12, "started": 12, "completed": 12,
        "iosRealUsers": 6, "androidRealUsers": 6,
        "withdrawn": 0, "excluded": 0, "stoppedOrPaused": 0,
    }
    values = {
        "unaidedFirstTenMinutes": (9, 12),
        "stepPermissionAcceptance": (9, 12),
        "firstDayReward": (7, 12),
        "crashFreeSessions": (201, 201),
        "syncErrorRate": (0, 100),
        "instrumentationCoverage": (19, 20),
    }
    for name, (numerator, denominator) in values.items():
        document["metrics"][name] = {
            "status": "MEASURED", "numerator": numerator,
            "denominator": denominator, "dataGapReasonCode": None,
        }
    document["qualitative"] = {
        "instrumentationInterpretable": True,
        "walkingAsAdventureSupported": True,
        "companionReturnSupported": True,
        "dataGapReasonCode": None,
    }
    document["findings"] = {
        "stopCount": 0, "fixBeforeExpandCount": 0, "experimentCount": 1,
        "laterCount": 2, "openReleaseBlockers": 0,
    }
    document["decision"] = {
        "selected": "EXPAND", "rationaleCode": "thresholds_passed",
        "nextScope": "closed_beta_wave", "authority": "MKSEgr",
        "confirmationAtUtc": "2026-08-20T09:05:00Z",
    }
    return document


class DecisionContractTests(unittest.TestCase):
    def assert_valid(self, document: dict) -> None:
        validator.validate(document, require_decided=True)

    def assert_invalid(self, document: dict) -> None:
        with self.assertRaises(validator.ContractError):
            validator.validate(document, require_decided=True)

    def test_committed_template_is_valid_but_not_decided(self) -> None:
        template = json.loads(TEMPLATE.read_text(encoding="utf-8"))
        validator.validate(template)
        self.assert_invalid(template)

    def test_exact_expand_boundaries_pass(self) -> None:
        self.assert_valid(decided())

    def test_crash_free_exactly_99_5_percent_fails(self) -> None:
        document = decided()
        document["metrics"]["crashFreeSessions"].update(numerator=199, denominator=200)
        self.assert_invalid(document)

    def test_permission_exactly_70_percent_fails(self) -> None:
        document = decided()
        document["metrics"]["stepPermissionAcceptance"].update(numerator=7, denominator=10)
        self.assert_invalid(document)

    def test_first_day_six_of_twelve_fails(self) -> None:
        document = decided()
        document["metrics"]["firstDayReward"]["numerator"] = 6
        self.assert_invalid(document)

    def test_sync_exactly_one_percent_fails(self) -> None:
        document = decided()
        document["metrics"]["syncErrorRate"].update(numerator=1, denominator=100)
        self.assert_invalid(document)

    def test_instrumentation_95_percent_is_inclusive(self) -> None:
        document = decided()
        document["metrics"]["instrumentationCoverage"].update(numerator=95, denominator=100)
        self.assert_valid(document)

    def test_data_gap_blocks_expand_but_allows_fix(self) -> None:
        document = decided()
        document["metrics"]["crashFreeSessions"] = {
            "status": "DATA_GAP", "numerator": None, "denominator": None,
            "dataGapReasonCode": "instrumentation_missing",
        }
        self.assert_invalid(document)
        document["decision"].update(
            selected="FIX_AND_RERUN", rationaleCode="instrumentation_gap",
            nextScope="focused_fix_and_alpha_rerun",
        )
        self.assert_valid(document)

    def test_partial_data_gap_counts_are_rejected(self) -> None:
        document = decided()
        document["metrics"]["syncErrorRate"] = {
            "status": "DATA_GAP", "numerator": 1, "denominator": None,
            "dataGapReasonCode": "collection_stopped",
        }
        self.assert_invalid(document)

    def test_blocker_and_qualitative_miss_block_expand(self) -> None:
        for mutation in ("blocker", "qualitative"):
            with self.subTest(mutation=mutation):
                document = decided()
                if mutation == "blocker":
                    document["findings"]["openReleaseBlockers"] = 1
                else:
                    document["qualitative"]["companionReturnSupported"] = False
                self.assert_invalid(document)

    def test_invalid_cohort_blocks_expand(self) -> None:
        for key, value in (("completed", 11), ("iosRealUsers", 3), ("withdrawn", 1)):
            with self.subTest(key=key):
                document = decided()
                document["cohort"][key] = value
                self.assert_invalid(document)

    def test_decision_metadata_must_match_selected_outcome(self) -> None:
        document = decided()
        document["decision"]["selected"] = "STOP"
        self.assert_invalid(document)

    def test_stop_record_can_preserve_incomplete_evidence(self) -> None:
        document = decided()
        document["metrics"]["unaidedFirstTenMinutes"] = {
            "status": "DATA_GAP", "numerator": None, "denominator": None,
            "dataGapReasonCode": "collection_stopped",
        }
        document["qualitative"] = {
            "instrumentationInterpretable": False,
            "walkingAsAdventureSupported": None,
            "companionReturnSupported": None,
            "dataGapReasonCode": "collection_stopped",
        }
        document["findings"]["stopCount"] = 1
        document["decision"].update(
            selected="STOP", rationaleCode="safety_risk", nextScope="stop_and_archive",
        )
        self.assert_valid(document)

    def test_unknown_and_reordered_fields_are_rejected(self) -> None:
        document = decided()
        document["unexpected"] = 1
        self.assert_invalid(document)
        reordered = {key: value for key, value in reversed(list(decided().items()))}
        self.assert_invalid(reordered)

    def test_malformed_hash_and_timestamp_order_are_rejected(self) -> None:
        document = decided()
        document["candidate"]["sourceSha"] = "ABC"
        self.assert_invalid(document)
        document = decided()
        document["decisionAtUtc"] = "2026-08-20T07:59:59Z"
        self.assert_invalid(document)

    def test_boolean_and_integer_types_are_strict(self) -> None:
        document = decided()
        document["cohort"]["completed"] = True
        self.assert_invalid(document)
        document = decided()
        document["qualitative"]["instrumentationInterpretable"] = 1
        self.assert_invalid(document)

    def test_duplicate_json_key_is_rejected_by_cli(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "duplicate.json"
            path.write_text('{"schemaVersion":"a","schemaVersion":"b"}', encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(VALIDATOR), str(path)],
                check=False, capture_output=True, text=True,
            )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("duplicate JSON key", result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
