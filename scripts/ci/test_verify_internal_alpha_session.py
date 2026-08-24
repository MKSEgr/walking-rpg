#!/usr/bin/env python3
"""Regression tests for the internal-alpha participant session contract."""

from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
VALIDATOR = HERE / "verify_internal_alpha_session.py"
TEMPLATE = ROOT / "docs/evidence/internal-alpha-session-template.json"
SPEC = importlib.util.spec_from_file_location("session_validator", VALIDATOR)
assert SPEC and SPEC.loader
validator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(validator)


def utc(seconds: int) -> str:
    start = datetime(2026, 8, 20, 8, 0, 0, tzinfo=timezone.utc)
    return (start + timedelta(seconds=seconds)).strftime("%Y-%m-%dT%H:%M:%SZ")


def recorded() -> dict:
    document = json.loads(TEMPLATE.read_text(encoding="utf-8"))
    document.update(recordStatus="RECORDED", recordedAtUtc=utc(1200))
    document["protocol"]["commitSha"] = "1" * 40
    document["candidate"] = {
        "sourceSha": "2" * 40,
        "treeSha": "3" * 40,
        "appVersion": "1.0.0-alpha.1",
        "buildNumber": "42",
        "platformArtifactSha256": "4" * 64,
    }
    document["kickoff"] = {
        "recordSha256": "5" * 64,
        "observationStartsAtUtc": "2026-08-20T07:00:00Z",
        "observationEndsAtUtc": "2026-08-27T18:00:00Z",
        "participantEvidenceDeleteByUtc": "2026-11-25T18:00:00Z",
    }
    document["session"] = {
        "studyCode": "P01",
        "platform": "ios",
        "startedAtUtc": utc(0),
        "endedAtUtc": utc(720),
        "moderatorRole": "approved_alpha_moderator",
        "consentConfirmed": True,
        "withdrawalRouteExplained": True,
        "exactCandidateVerified": True,
        "stopPauseStatus": "NOT_INVOKED",
    }
    elapsed = [0, 30, 60, 120, 180, 240, 300, 360, 480, 600]
    for index, seconds in enumerate(elapsed):
        milestone = document["milestones"][index]
        milestone.update(
            status="OBSERVED",
            observedAtUtc=utc(seconds),
            elapsedSeconds=seconds,
            sourceCategory=validator.SOURCES[milestone["milestoneId"]],
            helpRequested=False,
            gapReasonCode=None,
        )
    document["outcome"] = {
        "completedUnaided": True,
        "permissionRequestShown": True,
        "permissionDecision": "GRANTED",
        "firstDayRewardStatus": "YES",
        "candidateSessions": 2,
        "crashFreeSessions": 2,
        "authoritativeSyncAttempts": 3,
        "failedNonCancelledSyncAttempts": 0,
        "applicableMandatoryMilestones": 10,
        "recordedMandatoryMilestones": 10,
        "nextActionComprehension": "CLEAR",
        "nextActionComprehensionAtUtc": utc(590),
        "nextActionComprehensionElapsedSeconds": 590,
        "walkingAsAdventure": "YES",
        "companionReturn": "YES",
    }
    document["evidence"] = {
        "storageCategory": "approved_research_workspace",
        "evidencePackageSha256": "6" * 64,
        "redactionReviewedAtUtc": utc(900),
        "redactionReviewerRole": "approved_redaction_reviewer",
        "participantEvidenceDeleteByUtc": "2026-11-25T18:00:00Z",
        "rawEvidenceCommittedToGit": False,
    }
    return document


def set_gap(document: dict, index: int, status: str, reason: str) -> None:
    document["milestones"][index].update(
        status=status,
        observedAtUtc=None,
        elapsedSeconds=None,
        sourceCategory=None,
        helpRequested=None,
        gapReasonCode=reason,
    )


class SessionContractTests(unittest.TestCase):
    def assert_valid(self, document: dict) -> None:
        validator.validate_session(document, require_recorded=True)

    def assert_invalid(self, document: dict) -> None:
        with self.assertRaises(validator.SessionValidationError):
            validator.validate_session(document, require_recorded=True)

    def test_template_is_valid_but_not_recorded(self) -> None:
        template = json.loads(TEMPLATE.read_text(encoding="utf-8"))
        validator.validate_session(template)
        self.assert_invalid(template)

    def test_exact_ten_minute_unaided_session_is_valid(self) -> None:
        self.assert_valid(recorded())

    def test_result_ack_after_ten_minutes_blocks_unaided_claim(self) -> None:
        document = recorded()
        document["milestones"][-1].update(observedAtUtc=utc(601), elapsedSeconds=601)
        self.assert_invalid(document)

    def test_comprehension_after_ten_minutes_blocks_unaided_claim(self) -> None:
        document = recorded()
        document["outcome"].update(
            nextActionComprehensionAtUtc=utc(601),
            nextActionComprehensionElapsedSeconds=601,
        )
        self.assert_invalid(document)

    def test_comprehension_elapsed_seconds_match_utc(self) -> None:
        document = recorded()
        document["outcome"]["nextActionComprehensionElapsedSeconds"] = 589
        self.assert_invalid(document)

    def test_comprehension_data_gap_has_no_timing_claim(self) -> None:
        document = recorded()
        document["outcome"].update(
            completedUnaided=False,
            nextActionComprehension="DATA_GAP",
            nextActionComprehensionAtUtc=None,
            nextActionComprehensionElapsedSeconds=None,
        )
        self.assert_valid(document)
        document["outcome"]["nextActionComprehensionAtUtc"] = utc(590)
        self.assert_invalid(document)

    def test_help_comprehension_and_reward_are_unaided_gates(self) -> None:
        for mutation in ("help", "comprehension", "reward"):
            with self.subTest(mutation=mutation):
                document = recorded()
                if mutation == "help":
                    document["milestones"][4]["helpRequested"] = True
                elif mutation == "comprehension":
                    document["outcome"]["nextActionComprehension"] = "PARTIAL"
                else:
                    document["outcome"]["firstDayRewardStatus"] = "NO"
                self.assert_invalid(document)

    def test_elapsed_seconds_must_match_ordered_utc(self) -> None:
        document = recorded()
        document["milestones"][3]["elapsedSeconds"] = 119
        self.assert_invalid(document)
        document = recorded()
        document["milestones"][3].update(observedAtUtc=utc(20), elapsedSeconds=20)
        self.assert_invalid(document)

    def test_observation_cannot_follow_not_reached(self) -> None:
        document = recorded()
        set_gap(document, 5, "NOT_REACHED", "flow_blocked")
        document["outcome"].update(completedUnaided=False, recordedMandatoryMilestones=9)
        self.assert_invalid(document)

    def test_stopped_session_with_unreached_tail_is_valid(self) -> None:
        document = recorded()
        for index in range(5, 10):
            set_gap(document, index, "NOT_REACHED", "session_stopped")
        document["session"]["stopPauseStatus"] = "STOPPED"
        document["outcome"].update(
            completedUnaided=False,
            firstDayRewardStatus="NO",
            recordedMandatoryMilestones=5,
            nextActionComprehension="PARTIAL",
            walkingAsAdventure="DATA_GAP",
            companionReturn="DATA_GAP",
        )
        self.assert_valid(document)

    def test_data_gap_can_preserve_later_observations(self) -> None:
        document = recorded()
        set_gap(document, 5, "DATA_GAP", "instrumentation_missing")
        document["outcome"].update(completedUnaided=False, recordedMandatoryMilestones=9)
        self.assert_valid(document)

    def test_permission_claims_are_consistent(self) -> None:
        document = recorded()
        document["outcome"].update(permissionRequestShown=False, permissionDecision="DENIED")
        self.assert_invalid(document)
        document = recorded()
        set_gap(document, 3, "DATA_GAP", "instrumentation_missing")
        document["outcome"].update(completedUnaided=False, recordedMandatoryMilestones=9)
        self.assert_invalid(document)

    def test_reward_yes_requires_observed_event_resolution(self) -> None:
        document = recorded()
        set_gap(document, 8, "NOT_REACHED", "flow_blocked")
        set_gap(document, 9, "NOT_REACHED", "flow_blocked")
        document["outcome"].update(completedUnaided=False, recordedMandatoryMilestones=8)
        self.assert_invalid(document)

    def test_metric_counts_are_bounded_and_match_milestones(self) -> None:
        for key, value in (
            ("crashFreeSessions", 3),
            ("failedNonCancelledSyncAttempts", 4),
            ("recordedMandatoryMilestones", 9),
            ("applicableMandatoryMilestones", 9),
        ):
            with self.subTest(key=key):
                document = recorded()
                document["outcome"][key] = value
                self.assert_invalid(document)

    def test_blocking_finding_requires_issue_and_safe_code(self) -> None:
        document = recorded()
        document["findings"] = [{
            "findingCode": "duplicate_reward",
            "stageId": "first_event_resolved",
            "severity": "FIX_BEFORE_EXPAND",
            "reproducible": True,
            "owner": "MKSEgr",
            "issueNumber": None,
            "evidenceDigestSha256": "7" * 64,
        }]
        self.assert_invalid(document)
        document["findings"][0]["issueNumber"] = 480
        self.assert_valid(document)
        document["findings"][0]["findingCode"] = "device_id_12345678"
        self.assert_invalid(document)

    def test_milestone_order_and_unknown_fields_are_rejected(self) -> None:
        document = recorded()
        document["milestones"][0], document["milestones"][1] = (
            document["milestones"][1], document["milestones"][0]
        )
        self.assert_invalid(document)
        document = recorded()
        document["unexpected"] = True
        self.assert_invalid(document)
        self.assert_invalid({key: value for key, value in reversed(list(recorded().items()))})

    def test_hash_time_retention_and_git_privacy_are_strict(self) -> None:
        for mutation in ("hash", "time", "retention", "git"):
            with self.subTest(mutation=mutation):
                document = recorded()
                if mutation == "hash":
                    document["candidate"]["sourceSha"] = "ABC"
                elif mutation == "time":
                    document["recordedAtUtc"] = utc(700)
                elif mutation == "retention":
                    document["evidence"]["participantEvidenceDeleteByUtc"] = "2027-01-01T00:00:00Z"
                else:
                    document["evidence"]["rawEvidenceCommittedToGit"] = True
                self.assert_invalid(document)

    def test_early_session_accepts_kickoff_wide_retention_deadline(self) -> None:
        document = recorded()
        self.assertEqual(
            document["kickoff"]["participantEvidenceDeleteByUtc"],
            "2026-11-25T18:00:00Z",
        )
        self.assert_valid(document)

    def test_session_must_match_kickoff_window_and_shared_deadline(self) -> None:
        document = recorded()
        document["kickoff"]["observationStartsAtUtc"] = utc(1)
        self.assert_invalid(document)
        document = recorded()
        document["evidence"]["participantEvidenceDeleteByUtc"] = "2026-11-24T18:00:00Z"
        self.assert_invalid(document)

    def test_boolean_and_integer_types_are_not_coerced(self) -> None:
        document = recorded()
        document["session"]["consentConfirmed"] = 1
        self.assert_invalid(document)
        document = recorded()
        document["outcome"]["candidateSessions"] = True
        self.assert_invalid(document)

    def test_duplicate_json_key_is_rejected_by_cli(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "duplicate.json"
            path.write_text('{"schemaVersion":"a","schemaVersion":"b"}', encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(VALIDATOR), str(path)],
                check=False,
                capture_output=True,
                text=True,
            )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("duplicate JSON key", result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
