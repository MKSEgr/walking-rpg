#!/usr/bin/env python3
"""Regression tests for decision-to-session evidence reconciliation."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import test_verify_internal_alpha_decision as decision_fixture
import test_verify_internal_alpha_session as session_fixture


HERE = Path(__file__).resolve().parent
VALIDATOR = HERE / "verify_internal_alpha_decision_evidence.py"
SPEC = importlib.util.spec_from_file_location("decision_evidence_validator", VALIDATOR)
assert SPEC and SPEC.loader
validator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(validator)


def _encoded(document: dict) -> bytes:
    return (json.dumps(document, ensure_ascii=False, indent=2) + "\n").encode()


class DecisionEvidenceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

        self.kickoff = session_fixture.ready_kickoff()
        self.kickoff_path = self.root / "approved-kickoff.json"
        self.kickoff_path.write_bytes(_encoded(self.kickoff))

        self.session_paths: list[Path] = []
        for number in range(1, 13):
            document = session_fixture.recorded()
            code = f"P{number:02d}"
            platform = "ios" if number <= 6 else "android"
            document["session"].update(studyCode=code, platform=platform)
            document["candidate"]["platformArtifactSha256"] = (
                self.kickoff["candidate"][platform]["artifactSha256"]
            )
            started = document["session"]["startedAtUtc"].replace("-", "").replace(
                ":", ""
            )
            path = self.root / (
                f"internal-alpha-v1_{document['candidate']['sourceSha']}_"
                f"{platform}_{code}_{started}_session.json"
            )
            path.write_bytes(_encoded(document))
            self.session_paths.append(path)

        self.decision = decision_fixture.decided()
        self.decision.update(
            recordedAtUtc="2026-08-28T08:00:00Z",
            decisionAtUtc="2026-08-28T09:00:00Z",
        )
        self.decision["decision"]["confirmationAtUtc"] = "2026-08-28T09:05:00Z"
        self.decision["candidate"]["kickoffRecordSha256"] = hashlib.sha256(
            self.kickoff_path.read_bytes()
        ).hexdigest()
        self.decision["cohort"] = {
            "invited": 12,
            "started": 12,
            "completed": 12,
            "iosRealUsers": 6,
            "androidRealUsers": 6,
            "withdrawn": 0,
            "excluded": 0,
            "stoppedOrPaused": 0,
        }
        self.decision["findings"] = {
            "stopCount": 0,
            "fixBeforeExpandCount": 0,
            "experimentCount": 0,
            "laterCount": 0,
            "openReleaseBlockers": 0,
        }
        counts = {
            "unaidedFirstTenMinutes": (12, 12),
            "stepPermissionAcceptance": (12, 12),
            "firstDayReward": (12, 12),
            "crashFreeSessions": (24, 24),
            "syncErrorRate": (0, 36),
            "instrumentationCoverage": (12, 12),
        }
        for name, (numerator, denominator) in counts.items():
            self.decision["metrics"][name].update(
                status="MEASURED",
                numerator=numerator,
                denominator=denominator,
                dataGapReasonCode=None,
            )
        self.decision_path = self.root / "decision.json"
        self.refresh_package()

    def write_decision(self) -> None:
        self.decision_path.write_bytes(_encoded(self.decision))

    def refresh_package(self) -> None:
        self.decision["candidate"]["alphaEvidencePackageSha256"] = (
            validator.evidence_package_sha256(
                self.kickoff_path, self.session_paths
            )
        )
        self.write_decision()

    def make_kickoff_only_stop(self) -> None:
        self.session_paths = []
        self.decision["cohort"] = {
            "invited": 0,
            "started": 0,
            "completed": 0,
            "iosRealUsers": 0,
            "androidRealUsers": 0,
            "withdrawn": 0,
            "excluded": 0,
            "stoppedOrPaused": 0,
        }
        for name in self.decision["metrics"]:
            self.decision["metrics"][name] = {
                "status": "DATA_GAP",
                "numerator": None,
                "denominator": None,
                "dataGapReasonCode": "collection_stopped",
            }
        self.decision["decision"].update(
            selected="STOP",
            rationaleCode="safety_risk",
            nextScope="stop_and_archive",
        )
        self.refresh_package()

    def assert_valid(self, paths: list[Path] | None = None) -> str:
        return validator.validate_bundle(
            self.decision_path,
            self.kickoff_path,
            paths or self.session_paths,
        )

    def assert_invalid(self, paths: list[Path] | None = None) -> None:
        with self.assertRaises(validator.BundleValidationError):
            self.assert_valid(paths)

    def test_complete_bundle_is_valid_and_order_independent(self) -> None:
        expected = self.assert_valid()
        actual = self.assert_valid(list(reversed(self.session_paths)))
        self.assertEqual(expected, actual)

    def test_cli_prints_the_verified_package_digest(self) -> None:
        command = [
            sys.executable,
            str(VALIDATOR),
            str(self.decision_path),
            "--kickoff",
            str(self.kickoff_path),
        ]
        for path in self.session_paths:
            command.extend(("--session", str(path)))
        result = subprocess.run(command, check=False, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(
            self.decision["candidate"]["alphaEvidencePackageSha256"],
            result.stdout,
        )

    def test_cli_prints_package_digest_before_decision_exists(self) -> None:
        command = [
            sys.executable,
            str(VALIDATOR),
            "--print-package-sha256",
            "--kickoff",
            str(self.kickoff_path),
        ]
        for path in self.session_paths:
            command.extend(("--session", str(path)))
        result = subprocess.run(command, check=False, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(
            self.decision["candidate"]["alphaEvidencePackageSha256"],
            result.stdout,
        )

    def test_any_session_byte_change_invalidates_the_package(self) -> None:
        path = self.session_paths[0]
        document = json.loads(path.read_text(encoding="utf-8"))
        path.write_text(json.dumps(document, separators=(",", ":")), encoding="utf-8")
        self.assert_invalid()

    def test_validator_parses_the_same_session_bytes_it_hashes(self) -> None:
        target = self.session_paths[0]
        document = json.loads(target.read_text(encoding="utf-8"))
        document["candidate"]["sourceSha"] = "f" * 40
        swapped = _encoded(document)
        original_read_bytes = Path.read_bytes

        def read_bytes(path: Path) -> bytes:
            return swapped if path == target else original_read_bytes(path)

        with mock.patch.object(Path, "read_bytes", new=read_bytes):
            with self.assertRaises(validator.BundleValidationError):
                validator._validated_evidence(
                    self.kickoff_path, self.session_paths
                )

    def test_duplicate_or_missing_study_code_is_rejected(self) -> None:
        duplicate = self.session_paths[:-1] + [self.session_paths[0]]
        self.assert_invalid(duplicate)
        self.assert_invalid(self.session_paths[:-1])

    def test_mixed_candidate_is_rejected(self) -> None:
        path = self.session_paths[0]
        document = json.loads(path.read_text(encoding="utf-8"))
        document["candidate"]["sourceSha"] = "f" * 40
        path.write_bytes(_encoded(document))
        self.assert_invalid()

    def test_forged_metric_and_cohort_counts_are_rejected(self) -> None:
        self.decision["metrics"]["unaidedFirstTenMinutes"]["numerator"] = 11
        self.write_decision()
        self.assert_invalid()

    def test_completed_count_cannot_omit_completed_records(self) -> None:
        self.decision["cohort"]["completed"] = 0
        self.write_decision()
        self.assert_invalid()

    def test_interrupted_session_cannot_be_counted_as_completed(self) -> None:
        path = self.session_paths[0]
        document = json.loads(path.read_text(encoding="utf-8"))
        for index in range(5, 10):
            session_fixture.set_gap(
                document, index, "NOT_REACHED", "session_stopped"
            )
        document["session"].update(
            stopPauseStatus="STOPPED",
            stopPauseAtUtc=session_fixture.utc(200),
        )
        document["evidence"]["redactionReviewedAtUtc"] = session_fixture.utc(46800)
        document["outcome"].update(
            completedUnaided=False,
            firstDayRewardStatus="NO",
            firstDayRewardReceiptAtUtc=None,
            applicableMandatoryMilestones=5,
            recordedMandatoryMilestones=5,
            nextActionComprehension="DATA_GAP",
            nextActionSummaryCode=None,
            nextActionComprehensionAtUtc=None,
            nextActionComprehensionElapsedSeconds=None,
            nextActionComprehensionHelpRequested=None,
            nextActionComprehensionHelpProvided=None,
            walkingAsAdventure="DATA_GAP",
            companionReturn="DATA_GAP",
        )
        path.write_bytes(_encoded(document))
        self.decision["cohort"]["stoppedOrPaused"] = 1
        self.decision["metrics"]["unaidedFirstTenMinutes"]["numerator"] = 11
        self.decision["metrics"]["firstDayReward"]["numerator"] = 11
        self.decision["decision"].update(
            selected="STOP",
            rationaleCode="safety_risk",
            nextScope="stop_and_archive",
        )
        self.refresh_package()
        self.assert_invalid()

        self.decision["cohort"]["completed"] = 11
        self.write_decision()
        self.assert_valid()

    def test_session_findings_are_counted_by_unique_issue(self) -> None:
        for path in self.session_paths[:2]:
            document = json.loads(path.read_text(encoding="utf-8"))
            document["findings"] = [{
                "findingCode": "privacy_boundary",
                "stageId": "session",
                "severity": "STOP",
                "reproducible": True,
                "owner": "MKSEgr",
                "issueNumber": 900,
                "evidenceDigestSha256": "a" * 64,
            }]
            path.write_bytes(_encoded(document))
        self.refresh_package()
        self.assert_invalid()

        self.decision["findings"]["stopCount"] = 1
        self.decision["decision"].update(
            selected="STOP",
            rationaleCode="safety_risk",
            nextScope="stop_and_archive",
        )
        self.write_decision()
        self.assert_valid()
        self.decision["metrics"]["unaidedFirstTenMinutes"]["numerator"] = 12
        self.decision["cohort"].update(iosRealUsers=7, androidRealUsers=5)
        self.write_decision()
        self.assert_invalid()

    def test_pending_reward_requires_a_decision_data_gap(self) -> None:
        path = self.session_paths[0]
        document = json.loads(path.read_text(encoding="utf-8"))
        document["recordedAtUtc"] = session_fixture.utc(1000)
        document["outcome"].update(
            firstDayRewardStatus="PENDING",
            firstDayRewardReceiptAtUtc=None,
        )
        document["evidence"]["redactionReviewedAtUtc"] = session_fixture.utc(900)
        path.write_bytes(_encoded(document))
        self.refresh_package()
        self.assert_invalid()

        self.decision["metrics"]["firstDayReward"] = {
            "status": "DATA_GAP",
            "numerator": None,
            "denominator": None,
            "dataGapReasonCode": "collection_stopped",
        }
        self.decision["decision"].update(
            selected="FIX_AND_RERUN",
            rationaleCode="instrumentation_gap",
            nextScope="focused_fix_and_alpha_rerun",
        )
        self.write_decision()
        self.assert_valid()

    def test_missing_comprehension_propagates_unaided_data_gap(self) -> None:
        path = self.session_paths[0]
        document = json.loads(path.read_text(encoding="utf-8"))
        document["outcome"].update(
            completedUnaided=False,
            nextActionComprehension="DATA_GAP",
            nextActionSummaryCode=None,
            nextActionComprehensionAtUtc=None,
            nextActionComprehensionElapsedSeconds=None,
            nextActionComprehensionHelpRequested=None,
            nextActionComprehensionHelpProvided=None,
            walkingAsAdventure="DATA_GAP",
            companionReturn="DATA_GAP",
        )
        path.write_bytes(_encoded(document))
        self.refresh_package()
        self.assert_invalid()

        self.decision["metrics"]["unaidedFirstTenMinutes"] = {
            "status": "DATA_GAP",
            "numerator": None,
            "denominator": None,
            "dataGapReasonCode": "instrumentation_missing",
        }
        self.decision["cohort"]["completed"] = 11
        self.decision["decision"].update(
            selected="FIX_AND_RERUN",
            rationaleCode="instrumentation_gap",
            nextScope="focused_fix_and_alpha_rerun",
        )
        self.write_decision()
        self.assert_valid()

    def test_late_pause_does_not_turn_comprehension_gap_into_failure(self) -> None:
        path = self.session_paths[0]
        document = json.loads(path.read_text(encoding="utf-8"))
        document["session"].update(
            stopPauseStatus="PAUSED",
            stopPauseAtUtc=session_fixture.utc(700),
        )
        document["outcome"].update(
            completedUnaided=False,
            nextActionComprehension="DATA_GAP",
            nextActionSummaryCode=None,
            nextActionComprehensionAtUtc=None,
            nextActionComprehensionElapsedSeconds=None,
            nextActionComprehensionHelpRequested=None,
            nextActionComprehensionHelpProvided=None,
            walkingAsAdventure="DATA_GAP",
            companionReturn="DATA_GAP",
        )
        path.write_bytes(_encoded(document))
        self.decision["cohort"].update(completed=11, stoppedOrPaused=1)
        self.decision["metrics"]["unaidedFirstTenMinutes"] = {
            "status": "DATA_GAP",
            "numerator": None,
            "denominator": None,
            "dataGapReasonCode": "instrumentation_missing",
        }
        self.decision["decision"].update(
            selected="FIX_AND_RERUN",
            rationaleCode="instrumentation_gap",
            nextScope="focused_fix_and_alpha_rerun",
        )
        self.refresh_package()
        self.assert_valid()

    def test_instrumentation_gap_rationale_requires_support(self) -> None:
        self.decision["decision"].update(
            selected="FIX_AND_RERUN",
            rationaleCode="instrumentation_gap",
            nextScope="focused_fix_and_alpha_rerun",
        )
        self.write_decision()
        self.assert_invalid()

    def test_release_blocker_rationale_requires_an_open_blocker(self) -> None:
        self.decision["decision"].update(
            selected="FIX_AND_RERUN",
            rationaleCode="release_blocker",
            nextScope="focused_fix_and_alpha_rerun",
        )
        self.write_decision()
        self.assert_invalid()

        self.decision["findings"]["openReleaseBlockers"] = 1
        self.write_decision()
        self.assert_valid()

    def test_instrumentation_coverage_is_counted_per_participant(self) -> None:
        path = self.session_paths[0]
        document = json.loads(path.read_text(encoding="utf-8"))
        session_fixture.set_gap(
            document, 5, "DATA_GAP", "instrumentation_missing"
        )
        document["outcome"]["recordedMandatoryMilestones"] = 9
        path.write_bytes(_encoded(document))
        self.refresh_package()

        self.decision["metrics"]["instrumentationCoverage"].update(
            numerator=119,
            denominator=120,
        )
        self.write_decision()
        self.assert_invalid()

        self.decision["metrics"]["instrumentationCoverage"].update(
            numerator=11,
            denominator=12,
        )
        self.decision["decision"].update(
            selected="FIX_AND_RERUN",
            rationaleCode="instrumentation_gap",
            nextScope="focused_fix_and_alpha_rerun",
        )
        self.write_decision()
        self.assert_valid()

    def test_threshold_miss_rationale_requires_a_failed_threshold(self) -> None:
        self.decision["decision"].update(
            selected="FIX_AND_RERUN",
            rationaleCode="threshold_miss",
            nextScope="focused_fix_and_alpha_rerun",
        )
        self.write_decision()
        self.assert_invalid()

        for path in self.session_paths[:4]:
            document = json.loads(path.read_text(encoding="utf-8"))
            document["milestones"][4]["helpRequested"] = True
            document["outcome"]["completedUnaided"] = False
            path.write_bytes(_encoded(document))
        self.decision["metrics"]["unaidedFirstTenMinutes"]["numerator"] = 8
        self.refresh_package()
        self.assert_valid()

    def test_outcome_rationales_reject_all_positive_sessions(self) -> None:
        cases = (
            (
                "FIX_AND_RERUN",
                "focused_comprehension_gap",
                "focused_fix_and_alpha_rerun",
            ),
            ("STOP", "core_value_not_supported", "stop_and_archive"),
        )
        for selected, rationale, scope in cases:
            with self.subTest(rationale=rationale):
                self.decision["decision"].update(
                    selected=selected,
                    rationaleCode=rationale,
                    nextScope=scope,
                )
                self.write_decision()
                self.assert_invalid()

    def test_outcome_rationales_require_matching_session_signals(self) -> None:
        path = self.session_paths[0]
        document = json.loads(path.read_text(encoding="utf-8"))
        document["outcome"].update(
            completedUnaided=False,
            nextActionComprehension="PARTIAL",
        )
        path.write_bytes(_encoded(document))
        self.decision["metrics"]["unaidedFirstTenMinutes"]["numerator"] = 11
        self.decision["decision"].update(
            selected="FIX_AND_RERUN",
            rationaleCode="focused_comprehension_gap",
            nextScope="focused_fix_and_alpha_rerun",
        )
        self.refresh_package()
        self.assert_valid()

        document["outcome"]["walkingAsAdventure"] = "NO"
        path.write_bytes(_encoded(document))
        self.decision["qualitative"]["companionReturnSupported"] = False
        self.decision["decision"].update(
            selected="STOP",
            rationaleCode="core_value_not_supported",
            nextScope="stop_and_archive",
        )
        self.refresh_package()
        self.assert_invalid()

        self.decision["qualitative"].update(
            walkingAsAdventureSupported=False,
            companionReturnSupported=True,
        )
        self.write_decision()
        self.assert_valid()

    def test_decision_cannot_predate_participant_records(self) -> None:
        self.decision["recordedAtUtc"] = "2026-08-20T09:00:00Z"
        self.write_decision()
        self.assert_invalid()

    def test_early_stop_keeps_actual_invitations_as_owner_input(self) -> None:
        self.session_paths = self.session_paths[:8]
        self.decision["cohort"].update(
            invited=10,
            started=8,
            completed=8,
            iosRealUsers=6,
            androidRealUsers=2,
        )
        counts = {
            "unaidedFirstTenMinutes": (8, 8),
            "stepPermissionAcceptance": (8, 8),
            "firstDayReward": (8, 8),
            "crashFreeSessions": (16, 16),
            "syncErrorRate": (0, 24),
            "instrumentationCoverage": (8, 8),
        }
        for name, (numerator, denominator) in counts.items():
            self.decision["metrics"][name].update(
                numerator=numerator,
                denominator=denominator,
            )
        self.decision["decision"].update(
            selected="STOP",
            rationaleCode="safety_risk",
            nextScope="stop_and_archive",
        )
        self.refresh_package()
        self.assert_valid()

        self.decision["cohort"]["invited"] = 13
        self.write_decision()
        self.assert_invalid()

    def test_stop_before_first_session_accepts_an_empty_bundle(self) -> None:
        self.make_kickoff_only_stop()
        self.assert_valid()

        result = subprocess.run(
            [
                sys.executable,
                str(VALIDATOR),
                str(self.decision_path),
                "--kickoff",
                str(self.kickoff_path),
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_kickoff_only_stop_preserves_non_session_findings(self) -> None:
        self.make_kickoff_only_stop()
        self.decision["findings"]["stopCount"] = 1
        self.write_decision()
        self.assert_valid()

    def test_kickoff_only_stop_preserves_pre_session_withdrawal(self) -> None:
        self.make_kickoff_only_stop()
        self.decision["cohort"].update(invited=1, withdrawn=1)
        self.write_decision()
        self.assert_valid()

    def test_kickoff_only_fix_accepts_a_pre_session_rationale(self) -> None:
        self.make_kickoff_only_stop()
        self.decision["decision"].update(
            selected="FIX_AND_RERUN",
            rationaleCode="instrumentation_gap",
            nextScope="focused_fix_and_alpha_rerun",
        )
        self.write_decision()
        self.assert_valid()

    def test_kickoff_only_rejects_evidence_dependent_rationales(self) -> None:
        cases = (
            ("FIX_AND_RERUN", "threshold_miss", "focused_fix_and_alpha_rerun"),
            (
                "FIX_AND_RERUN",
                "focused_comprehension_gap",
                "focused_fix_and_alpha_rerun",
            ),
            ("STOP", "core_value_not_supported", "stop_and_archive"),
        )
        for selected, rationale, scope in cases:
            with self.subTest(rationale=rationale):
                self.make_kickoff_only_stop()
                self.decision["decision"].update(
                    selected=selected,
                    rationaleCode=rationale,
                    nextScope=scope,
                )
                self.write_decision()
                self.assert_invalid()

    def test_kickoff_only_decision_cannot_predate_approval(self) -> None:
        self.make_kickoff_only_stop()
        self.decision.update(
            recordedAtUtc="2026-08-20T05:00:00Z",
            decisionAtUtc="2026-08-20T05:30:00Z",
        )
        self.decision["decision"]["confirmationAtUtc"] = "2026-08-20T05:45:00Z"
        self.write_decision()
        self.assert_invalid()

    def test_decision_must_precede_evidence_deletion(self) -> None:
        self.decision.update(
            recordedAtUtc="2026-11-26T08:00:00Z",
            decisionAtUtc="2026-11-26T08:30:00Z",
        )
        self.decision["decision"]["confirmationAtUtc"] = "2026-11-26T08:45:00Z"
        self.write_decision()
        self.assert_invalid()

    def test_deletion_deadline_is_within_90_days_of_early_decision(self) -> None:
        self.make_kickoff_only_stop()
        self.decision.update(
            recordedAtUtc="2026-08-20T07:00:00Z",
            decisionAtUtc="2026-08-20T07:10:00Z",
        )
        self.decision["decision"]["confirmationAtUtc"] = "2026-08-20T07:15:00Z"
        self.write_decision()
        self.assert_invalid()

        self.kickoff["evidence"]["participantEvidenceDeleteByUtc"] = (
            "2026-11-18T07:15:00Z"
        )
        self.kickoff_path.write_bytes(_encoded(self.kickoff))
        self.decision["candidate"]["kickoffRecordSha256"] = hashlib.sha256(
            self.kickoff_path.read_bytes()
        ).hexdigest()
        self.refresh_package()
        self.assert_valid()


if __name__ == "__main__":
    unittest.main(verbosity=2)
