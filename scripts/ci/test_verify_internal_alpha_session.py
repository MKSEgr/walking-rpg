#!/usr/bin/env python3
"""Regression tests for the internal-alpha participant session contract."""

from __future__ import annotations

import importlib.util
import hashlib
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
KICKOFF_TEMPLATE = ROOT / "docs/evidence/internal-alpha-kickoff-template.json"
SPEC = importlib.util.spec_from_file_location("session_validator", VALIDATOR)
assert SPEC and SPEC.loader
validator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(validator)


def utc(seconds: int) -> str:
    start = datetime(2026, 8, 20, 8, 0, 0, tzinfo=timezone.utc)
    return (start + timedelta(seconds=seconds)).strftime("%Y-%m-%dT%H:%M:%SZ")


def ready_kickoff() -> dict:
    document = json.loads(KICKOFF_TEMPLATE.read_text(encoding="utf-8"))
    document.update(
        recordStatus="READY",
        recordedAtUtc="2026-08-20T06:00:00Z",
        approvedAtUtc="2026-08-20T06:30:00Z",
    )
    document["protocol"]["commitSha"] = "1" * 40
    document["candidate"].update(
        sourceSha="2" * 40,
        treeSha="3" * 40,
        appVersion="1.0.0-alpha.1",
        buildNumber="42",
        contentVersion="chapter-1-v2",
        remoteConfigVersion="alpha-v1",
    )
    document["candidate"]["ios"] = {
        "bundleId": "app.walkingrpg.stage",
        "artifactSha256": "4" * 64,
        "distributionTrack": "testflight_internal",
    }
    document["candidate"]["android"] = {
        "applicationId": "app.walkingrpg.stage",
        "artifactSha256": "7" * 64,
        "distributionTrack": "play_internal",
    }
    document["candidate"]["backend"] = {
        "imageDigest": "sha256:" + "8" * 64,
        "deploymentReceiptSha256": "9" * 64,
        "stageEnvironment": "walking-rpg-alpha-eu",
    }
    document["observationWindow"] = {
        "startsAtUtc": "2026-08-20T07:00:00Z",
        "endsAtUtc": "2026-08-27T18:00:00Z",
        "supportUntilUtc": "2026-08-27T19:00:00Z",
    }
    document["evidence"] = {
        "storageCategory": "approved_research_workspace",
        "redactionPolicy": validator.kickoff_validator.REDACTION_POLICY,
        "participantEvidenceDeleteByUtc": "2026-11-25T18:00:00Z",
        "supportChannelCategory": "approved_private_channel",
    }
    for index, gate in enumerate(document["gates"]):
        gate.update(
            status="PASS",
            checkedAtUtc="2026-08-20T06:15:00Z",
            evidenceCategory="approved_research_workspace",
            evidenceDigestSha256=format(index + 1, "x") * 64,
        )
    return document


def encoded_kickoff(document: dict) -> bytes:
    return (json.dumps(document, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def kickoff_digest(document: dict) -> str:
    return hashlib.sha256(encoded_kickoff(document)).hexdigest()


def recorded() -> dict:
    document = json.loads(TEMPLATE.read_text(encoding="utf-8"))
    kickoff = ready_kickoff()
    document.update(recordStatus="RECORDED", recordedAtUtc=utc(60000))
    document["protocol"]["commitSha"] = "1" * 40
    document["candidate"] = {
        "sourceSha": "2" * 40,
        "treeSha": "3" * 40,
        "appVersion": "1.0.0-alpha.1",
        "buildNumber": "42",
        "platformArtifactSha256": "4" * 64,
    }
    document["kickoff"] = {
        "recordSha256": kickoff_digest(kickoff),
        "observationStartsAtUtc": kickoff["observationWindow"]["startsAtUtc"],
        "observationEndsAtUtc": kickoff["observationWindow"]["endsAtUtc"],
        "participantEvidenceDeleteByUtc": kickoff["evidence"]["participantEvidenceDeleteByUtc"],
    }
    document["session"] = {
        "studyCode": "P01",
        "platform": "ios",
        "deviceEnvironment": "physical_device",
        "sessionDriver": "participant",
        "adultEligibilityConfirmed": True,
        "selectedLocale": "ru",
        "startedAtUtc": utc(0),
        "endedAtUtc": utc(720),
        "moderatorRole": "approved_alpha_moderator",
        "consentConfirmed": True,
        "withdrawalRouteExplained": True,
        "exactCandidateVerified": True,
        "stopPauseStatus": "NOT_INVOKED",
        "stopPauseAtUtc": None,
        "withdrawalStatus": "NOT_WITHDRAWN",
        "withdrawnAtUtc": None,
    }
    elapsed = [0, 30, 60, 120, 180, 240, 300, 360, 480, 540]
    for index, seconds in enumerate(elapsed):
        milestone = document["milestones"][index]
        milestone.update(
            status="OBSERVED",
            observedAtUtc=utc(seconds),
            elapsedSeconds=seconds,
            sourceCategory=validator.SOURCES[milestone["milestoneId"]],
            helpRequested=False,
            facilitatorHelpProvided=False,
            gapReasonCode=None,
        )
    document["outcome"] = {
        "completedUnaided": True,
        "permissionRequestShown": True,
        "permissionDecision": "GRANTED",
        "firstDayRewardStatus": "YES",
        "firstDayRewardReceiptAtUtc": utc(480),
        "firstDayTimeZoneOffsetMinutes": 180,
        "firstDayRewardCutoffAtUtc": utc(46800),
        "candidateSessions": 2,
        "crashFreeSessions": 2,
        "authoritativeSyncAttempts": 3,
        "successfulAuthoritativeSyncAttempts": 3,
        "failedNonCancelledSyncAttempts": 0,
        "applicableMandatoryMilestones": 10,
        "recordedMandatoryMilestones": 10,
        "nextActionComprehension": "CLEAR",
        "nextActionSummaryCode": "continue_to_next_node",
        "nextActionComprehensionAtUtc": utc(600),
        "nextActionComprehensionElapsedSeconds": 600,
        "nextActionComprehensionHelpRequested": False,
        "nextActionComprehensionHelpProvided": False,
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
        helpRequested=False if status == "DATA_GAP" else None,
        facilitatorHelpProvided=False if status == "DATA_GAP" else None,
        gapReasonCode=reason,
    )


def set_not_applicable(document: dict, index: int, reason: str) -> None:
    document["milestones"][index].update(
        status="NOT_APPLICABLE",
        observedAtUtc=None,
        elapsedSeconds=None,
        sourceCategory=None,
        helpRequested=None,
        facilitatorHelpProvided=None,
        gapReasonCode=reason,
    )


class SessionContractTests(unittest.TestCase):
    def assert_valid(self, document: dict, kickoff: dict | None = None) -> None:
        referenced = ready_kickoff() if kickoff is None else kickoff
        validator.validate_session(
            document,
            require_recorded=True,
            referenced_kickoff=referenced,
            referenced_kickoff_sha256=kickoff_digest(referenced),
        )

    def assert_invalid(self, document: dict, kickoff: dict | None = None) -> None:
        referenced = ready_kickoff() if kickoff is None else kickoff
        with self.assertRaises(validator.SessionValidationError):
            validator.validate_session(
                document,
                require_recorded=True,
                referenced_kickoff=referenced,
                referenced_kickoff_sha256=kickoff_digest(referenced),
            )

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

    def test_result_ack_after_nine_minutes_blocks_unaided_claim(self) -> None:
        document = recorded()
        document["milestones"][-1].update(observedAtUtc=utc(541), elapsedSeconds=541)
        self.assert_invalid(document)

    def test_comprehension_after_ten_minutes_blocks_unaided_claim(self) -> None:
        document = recorded()
        document["outcome"].update(
            nextActionComprehensionAtUtc=utc(601),
            nextActionComprehensionElapsedSeconds=601,
        )
        self.assert_invalid(document)

    def test_comprehension_must_follow_result_ack(self) -> None:
        document = recorded()
        document["milestones"][-1].update(observedAtUtc=utc(560), elapsedSeconds=560)
        document["outcome"].update(
            nextActionComprehensionAtUtc=utc(550),
            nextActionComprehensionElapsedSeconds=550,
        )
        self.assert_invalid(document)

    def test_comprehension_must_use_protocol_task_window(self) -> None:
        document = recorded()
        document["milestones"][-1].update(observedAtUtc=utc(530), elapsedSeconds=530)
        document["outcome"].update(
            nextActionComprehensionAtUtc=utc(539),
            nextActionComprehensionElapsedSeconds=539,
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
            nextActionSummaryCode=None,
            nextActionComprehensionAtUtc=None,
            nextActionComprehensionElapsedSeconds=None,
            nextActionComprehensionHelpRequested=None,
            nextActionComprehensionHelpProvided=None,
            walkingAsAdventure="DATA_GAP",
            companionReturn="DATA_GAP",
        )
        self.assert_valid(document)
        document["outcome"]["nextActionComprehensionAtUtc"] = utc(590)
        self.assert_invalid(document)

    def test_comprehension_summary_code_is_required_and_sanitized(self) -> None:
        for code in (None, "Continue to next node", "device_id_12345678"):
            with self.subTest(code=code):
                document = recorded()
                document["outcome"]["nextActionSummaryCode"] = code
                self.assert_invalid(document)

    def test_help_and_comprehension_are_unaided_gates(self) -> None:
        for mutation in (
            "milestone_help", "milestone_help_provided", "comprehension",
            "comprehension_help", "comprehension_help_provided",
        ):
            with self.subTest(mutation=mutation):
                document = recorded()
                if mutation == "milestone_help":
                    document["milestones"][4]["helpRequested"] = True
                elif mutation == "milestone_help_provided":
                    document["milestones"][4]["facilitatorHelpProvided"] = True
                elif mutation == "comprehension":
                    document["outcome"]["nextActionComprehension"] = "PARTIAL"
                elif mutation == "comprehension_help":
                    document["outcome"]["nextActionComprehensionHelpRequested"] = True
                else:
                    document["outcome"]["nextActionComprehensionHelpProvided"] = True
                self.assert_invalid(document)

    def test_false_unaided_claim_is_rejected_when_evidence_qualifies(self) -> None:
        document = recorded()
        document["outcome"]["completedUnaided"] = False
        self.assert_invalid(document)

    def test_first_day_reward_is_independent_of_unaided_completion(self) -> None:
        for reward_status in ("NO", "DATA_GAP"):
            with self.subTest(reward_status=reward_status):
                document = recorded()
                document["outcome"].update(
                    firstDayRewardStatus=reward_status,
                    firstDayRewardReceiptAtUtc=None,
                )
                self.assert_invalid(document)
                document["evidence"]["redactionReviewedAtUtc"] = utc(46800)
                self.assert_valid(document)

    def test_reward_no_waits_for_local_first_day_cutoff(self) -> None:
        document = recorded()
        document["recordedAtUtc"] = utc(1200)
        document["outcome"].update(
            firstDayRewardStatus="NO",
            firstDayRewardReceiptAtUtc=None,
        )
        self.assert_invalid(document)
        document["outcome"]["firstDayRewardStatus"] = "PENDING"
        self.assert_valid(document)
        document["recordedAtUtc"] = utc(60000)
        self.assert_invalid(document)

    def test_reward_cutoff_matches_sanitized_timezone_offset(self) -> None:
        document = recorded()
        document["outcome"]["firstDayTimeZoneOffsetMinutes"] = 60
        self.assert_invalid(document)
        document["outcome"].update(
            firstDayTimeZoneOffsetMinutes=240,
            firstDayRewardCutoffAtUtc=utc(43200),
        )
        self.assert_valid(document)

    def test_session_requires_physical_device_and_participant_driver(self) -> None:
        for key, value in (
            ("deviceEnvironment", "emulator"),
            ("sessionDriver", "developer"),
            ("adultEligibilityConfirmed", False),
        ):
            with self.subTest(key=key):
                document = recorded()
                document["session"][key] = value
                self.assert_invalid(document)

    def test_elapsed_seconds_must_match_ordered_utc(self) -> None:
        document = recorded()
        document["milestones"][3]["elapsedSeconds"] = 119
        self.assert_invalid(document)
        document = recorded()
        document["milestones"][3].update(observedAtUtc=utc(20), elapsedSeconds=20)
        self.assert_invalid(document)

    def test_registration_milestone_anchors_session_timer(self) -> None:
        document = recorded()
        document["milestones"][0].update(observedAtUtc=utc(1), elapsedSeconds=1)
        self.assert_invalid(document)

    def test_unaided_task_group_deadlines_are_exact(self) -> None:
        mutations = (
            ("registration", {1: 121, 2: 121, 3: 180}),
            ("permission", {3: 241, 4: 241, 5: 241}),
            ("companion", {6: 361, 7: 361}),
            ("result", {8: 541, 9: 541}),
        )
        for group, timings in mutations:
            with self.subTest(group=group):
                document = recorded()
                for index, seconds in timings.items():
                    document["milestones"][index].update(
                        observedAtUtc=utc(seconds),
                        elapsedSeconds=seconds,
                    )
                self.assert_invalid(document)

    def test_observation_cannot_follow_not_reached(self) -> None:
        document = recorded()
        set_gap(document, 5, "NOT_REACHED", "flow_blocked")
        document["outcome"].update(completedUnaided=False, recordedMandatoryMilestones=9)
        self.assert_invalid(document)

    def test_data_gap_cannot_follow_not_reached(self) -> None:
        document = recorded()
        set_gap(document, 5, "NOT_REACHED", "flow_blocked")
        set_gap(document, 6, "DATA_GAP", "instrumentation_missing")
        document["outcome"].update(
            completedUnaided=False,
            applicableMandatoryMilestones=5,
            recordedMandatoryMilestones=8,
        )
        self.assert_invalid(document)

    def test_stopped_session_with_unreached_tail_is_valid(self) -> None:
        document = recorded()
        for index in range(5, 10):
            set_gap(document, index, "NOT_REACHED", "session_stopped")
        document["session"].update(
            stopPauseStatus="STOPPED",
            stopPauseAtUtc=utc(200),
        )
        document["evidence"]["redactionReviewedAtUtc"] = utc(46800)
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
        self.assert_valid(document)

    def test_withdrawal_requires_stopped_status(self) -> None:
        document = recorded()
        for index in range(5, 10):
            set_gap(document, index, "NOT_REACHED", "participant_withdrew")
        document["outcome"].update(
            completedUnaided=False,
            firstDayRewardStatus="DATA_GAP",
            firstDayRewardReceiptAtUtc=None,
            applicableMandatoryMilestones=5,
            recordedMandatoryMilestones=5,
            nextActionComprehension="DATA_GAP",
            nextActionSummaryCode=None,
            nextActionComprehensionAtUtc=None,
            nextActionComprehensionElapsedSeconds=None,
            nextActionComprehensionHelpRequested=None,
            nextActionComprehensionHelpProvided=None,
        )
        self.assert_invalid(document)
        document["session"].update(
            stopPauseStatus="PAUSED",
            stopPauseAtUtc=utc(240),
        )
        self.assert_invalid(document)
        document["session"]["stopPauseStatus"] = "STOPPED"
        self.assert_invalid(document)
        document["session"].update(
            withdrawalStatus="WITHDREW",
            withdrawnAtUtc=utc(240),
        )
        self.assert_invalid(document)
        document["outcome"].update(
            walkingAsAdventure="DATA_GAP",
            companionReturn="DATA_GAP",
        )
        document["evidence"]["redactionReviewedAtUtc"] = utc(46800)
        self.assert_valid(document)
        document["session"]["withdrawnAtUtc"] = utc(1000)
        self.assert_invalid(document)

    def test_data_gap_can_preserve_later_observations(self) -> None:
        document = recorded()
        set_gap(document, 5, "DATA_GAP", "instrumentation_missing")
        document["outcome"]["recordedMandatoryMilestones"] = 9
        self.assert_valid(document)

    def test_permission_claims_are_consistent(self) -> None:
        document = recorded()
        document["outcome"].update(permissionRequestShown=False, permissionDecision="DENIED")
        self.assert_invalid(document)
        document = recorded()
        document["outcome"].update(
            permissionRequestShown=False,
            permissionDecision="NOT_APPLICABLE",
        )
        self.assert_invalid(document)
        document = recorded()
        set_gap(document, 3, "DATA_GAP", "instrumentation_missing")
        document["outcome"].update(completedUnaided=False, recordedMandatoryMilestones=9)
        self.assert_invalid(document)
        document["outcome"].update(
            completedUnaided=True,
            permissionDecision="DATA_GAP",
        )
        self.assert_valid(document)
        for reason in ("permission_not_requested", "permission_denied", "no_activity_data"):
            with self.subTest(energy_reason=reason):
                contradiction = recorded()
                set_gap(contradiction, 3, "DATA_GAP", "instrumentation_missing")
                set_not_applicable(contradiction, 5, reason)
                contradiction["outcome"].update(
                    permissionDecision="DATA_GAP",
                    applicableMandatoryMilestones=9,
                    recordedMandatoryMilestones=8,
                )
                self.assert_invalid(contradiction)

    def test_unshown_permission_uses_explicit_non_applicable_stages(self) -> None:
        document = recorded()
        set_not_applicable(document, 3, "permission_not_requested")
        set_not_applicable(document, 5, "permission_not_requested")
        document["outcome"].update(
            permissionRequestShown=False,
            permissionDecision="NOT_APPLICABLE",
            applicableMandatoryMilestones=8,
            recordedMandatoryMilestones=8,
        )
        self.assert_valid(document)

    def test_unshown_permission_can_remain_in_stopped_tail(self) -> None:
        document = recorded()
        for index in range(3, 10):
            set_gap(document, index, "NOT_REACHED", "participant_withdrew")
        document["session"].update(
            stopPauseStatus="STOPPED",
            stopPauseAtUtc=utc(60),
            withdrawalStatus="WITHDREW",
            withdrawnAtUtc=utc(60),
        )
        document["outcome"].update(
            completedUnaided=False,
            permissionRequestShown=False,
            permissionDecision="NOT_APPLICABLE",
            firstDayRewardStatus="DATA_GAP",
            firstDayRewardReceiptAtUtc=None,
            applicableMandatoryMilestones=3,
            recordedMandatoryMilestones=3,
            nextActionComprehension="DATA_GAP",
            nextActionSummaryCode=None,
            nextActionComprehensionAtUtc=None,
            nextActionComprehensionElapsedSeconds=None,
            nextActionComprehensionHelpRequested=None,
            nextActionComprehensionHelpProvided=None,
            walkingAsAdventure="DATA_GAP",
            companionReturn="DATA_GAP",
        )
        document["evidence"]["redactionReviewedAtUtc"] = utc(46800)
        self.assert_invalid(document)
        document["outcome"].update(
            authoritativeSyncAttempts=0,
            successfulAuthoritativeSyncAttempts=0,
            failedNonCancelledSyncAttempts=0,
        )
        self.assert_valid(document)

    def test_shown_permission_can_end_without_decision_on_withdrawal(self) -> None:
        document = recorded()
        for index in range(3, 10):
            set_gap(document, index, "NOT_REACHED", "participant_withdrew")
        document["session"].update(
            stopPauseStatus="STOPPED",
            stopPauseAtUtc=utc(90),
            withdrawalStatus="WITHDREW",
            withdrawnAtUtc=utc(90),
        )
        document["outcome"].update(
            completedUnaided=False,
            permissionDecision="NOT_REACHED",
            firstDayRewardStatus="DATA_GAP",
            firstDayRewardReceiptAtUtc=None,
            applicableMandatoryMilestones=3,
            recordedMandatoryMilestones=3,
            nextActionComprehension="DATA_GAP",
            nextActionSummaryCode=None,
            nextActionComprehensionAtUtc=None,
            nextActionComprehensionElapsedSeconds=None,
            nextActionComprehensionHelpRequested=None,
            nextActionComprehensionHelpProvided=None,
            walkingAsAdventure="DATA_GAP",
            companionReturn="DATA_GAP",
        )
        document["evidence"]["redactionReviewedAtUtc"] = utc(46800)
        document["outcome"].update(
            authoritativeSyncAttempts=0,
            successfulAuthoritativeSyncAttempts=0,
            failedNonCancelledSyncAttempts=0,
        )
        self.assert_valid(document)
        document["outcome"]["permissionDecision"] = "DATA_GAP"
        self.assert_invalid(document)

    def test_shown_permission_can_end_without_decision_on_safety_stop(self) -> None:
        for reason in ("session_stopped", "flow_blocked"):
            with self.subTest(reason=reason):
                document = recorded()
                for index in range(3, 10):
                    set_gap(document, index, "NOT_REACHED", reason)
                document["session"].update(
                    stopPauseStatus="STOPPED",
                    stopPauseAtUtc=utc(90),
                )
                document["outcome"].update(
                    completedUnaided=False,
                    permissionDecision="NOT_REACHED",
                    firstDayRewardStatus="DATA_GAP",
                    firstDayRewardReceiptAtUtc=None,
                    applicableMandatoryMilestones=3,
                    recordedMandatoryMilestones=3,
                    nextActionComprehension="DATA_GAP",
                    nextActionSummaryCode=None,
                    nextActionComprehensionAtUtc=None,
                    nextActionComprehensionElapsedSeconds=None,
                    nextActionComprehensionHelpRequested=None,
                    nextActionComprehensionHelpProvided=None,
                    walkingAsAdventure="DATA_GAP",
                    companionReturn="DATA_GAP",
                )
                document["evidence"]["redactionReviewedAtUtc"] = utc(46800)
                document["outcome"].update(
                    authoritativeSyncAttempts=0,
                    successfulAuthoritativeSyncAttempts=0,
                    failedNonCancelledSyncAttempts=0,
                )
                self.assert_valid(document)

    def test_permission_denial_has_valid_unaided_limited_path(self) -> None:
        document = recorded()
        set_not_applicable(document, 5, "permission_denied")
        document["outcome"].update(
            permissionDecision="DENIED",
            applicableMandatoryMilestones=9,
            recordedMandatoryMilestones=9,
        )
        self.assert_valid(document)
        document["outcome"]["permissionDecision"] = "GRANTED"
        self.assert_invalid(document)
        document = recorded()
        document["outcome"]["permissionDecision"] = "DENIED"
        self.assert_invalid(document)

    def test_permission_denial_can_end_before_energy(self) -> None:
        document = recorded()
        for index in range(4, 10):
            set_gap(document, index, "NOT_REACHED", "participant_withdrew")
        document["session"].update(
            stopPauseStatus="STOPPED",
            stopPauseAtUtc=utc(120),
            withdrawalStatus="WITHDREW",
            withdrawnAtUtc=utc(120),
        )
        document["outcome"].update(
            completedUnaided=False,
            permissionDecision="DENIED",
            firstDayRewardStatus="DATA_GAP",
            firstDayRewardReceiptAtUtc=None,
            applicableMandatoryMilestones=4,
            recordedMandatoryMilestones=4,
            nextActionComprehension="DATA_GAP",
            nextActionSummaryCode=None,
            nextActionComprehensionAtUtc=None,
            nextActionComprehensionElapsedSeconds=None,
            nextActionComprehensionHelpRequested=None,
            nextActionComprehensionHelpProvided=None,
            walkingAsAdventure="DATA_GAP",
            companionReturn="DATA_GAP",
        )
        document["evidence"]["redactionReviewedAtUtc"] = utc(46800)
        document["outcome"].update(
            authoritativeSyncAttempts=0,
            successfulAuthoritativeSyncAttempts=0,
            failedNonCancelledSyncAttempts=0,
        )
        self.assert_valid(document)

    def test_granted_permission_without_activity_data_skips_energy(self) -> None:
        document = recorded()
        set_not_applicable(document, 5, "no_activity_data")
        document["outcome"].update(
            applicableMandatoryMilestones=9,
            recordedMandatoryMilestones=9,
        )
        self.assert_valid(document)
        document["milestones"][5]["gapReasonCode"] = "permission_denied"
        self.assert_invalid(document)

    def test_selected_locale_must_be_kickoff_approved(self) -> None:
        document = recorded()
        document["session"]["selectedLocale"] = "en"
        self.assert_valid(document)
        document["session"]["selectedLocale"] = "de"
        self.assert_invalid(document)
        document = recorded()
        set_gap(document, 1, "DATA_GAP", "instrumentation_missing")
        document["session"]["selectedLocale"] = None
        document["outcome"]["recordedMandatoryMilestones"] = 9
        self.assert_valid(document)
        document["session"]["selectedLocale"] = "ru"
        self.assert_invalid(document)

    def test_reward_yes_requires_observed_event_resolution(self) -> None:
        document = recorded()
        set_gap(document, 8, "NOT_REACHED", "flow_blocked")
        set_gap(document, 9, "NOT_REACHED", "flow_blocked")
        document["outcome"].update(completedUnaided=False, recordedMandatoryMilestones=8)
        self.assert_invalid(document)
        document = recorded()
        document["outcome"]["firstDayRewardReceiptAtUtc"] = None
        self.assert_invalid(document)
        document = recorded()
        document["outcome"]["firstDayRewardStatus"] = "NO"
        self.assert_invalid(document)
        document = recorded()
        document["outcome"]["firstDayRewardReceiptAtUtc"] = utc(479)
        self.assert_invalid(document)
        document = recorded()
        document["outcome"]["firstDayRewardReceiptAtUtc"] = utc(901)
        self.assert_invalid(document)
        document = recorded()
        set_gap(document, 8, "DATA_GAP", "instrumentation_missing")
        document["outcome"]["recordedMandatoryMilestones"] = 9
        self.assert_valid(document)
        document["outcome"]["firstDayRewardReceiptAtUtc"] = utc(359)
        self.assert_invalid(document)
        document["outcome"]["firstDayRewardReceiptAtUtc"] = utc(360)
        self.assert_valid(document)

    def test_reward_yes_must_arrive_by_local_day_cutoff(self) -> None:
        document = recorded()
        document["evidence"]["redactionReviewedAtUtc"] = utc(15000)
        document["outcome"].update(
            firstDayTimeZoneOffsetMinutes=720,
            firstDayRewardCutoffAtUtc=utc(14400),
            firstDayRewardReceiptAtUtc=utc(14400),
        )
        self.assert_valid(document)
        document["outcome"]["firstDayRewardReceiptAtUtc"] = utc(14401)
        self.assert_invalid(document)

    def test_metric_counts_are_bounded_and_match_milestones(self) -> None:
        for key, value in (
            ("crashFreeSessions", 3),
            ("successfulAuthoritativeSyncAttempts", 4),
            ("failedNonCancelledSyncAttempts", 4),
            ("recordedMandatoryMilestones", 9),
            ("applicableMandatoryMilestones", 9),
        ):
            with self.subTest(key=key):
                document = recorded()
                document["outcome"][key] = value
                self.assert_invalid(document)

    def test_observed_sync_receipt_requires_successful_attempt(self) -> None:
        for attempts, successful, failed in ((0, 0, 0), (2, 0, 0), (2, 1, 2)):
            with self.subTest(attempts=attempts, successful=successful, failed=failed):
                document = recorded()
                document["outcome"].update(
                    authoritativeSyncAttempts=attempts,
                    successfulAuthoritativeSyncAttempts=successful,
                    failedNonCancelledSyncAttempts=failed,
                )
                self.assert_invalid(document)

    def test_sync_data_gap_needs_attempt_evidence_for_unaided_completion(self) -> None:
        document = recorded()
        set_gap(document, 4, "DATA_GAP", "instrumentation_missing")
        document["outcome"].update(
            authoritativeSyncAttempts=1,
            successfulAuthoritativeSyncAttempts=0,
            failedNonCancelledSyncAttempts=0,
            recordedMandatoryMilestones=9,
        )
        self.assert_invalid(document)
        document["outcome"]["successfulAuthoritativeSyncAttempts"] = 1
        self.assert_valid(document)

    def test_withdrawal_after_result_ack_discards_later_outcomes(self) -> None:
        document = recorded()
        document["session"].update(
            stopPauseStatus="STOPPED",
            stopPauseAtUtc=utc(570),
            withdrawalStatus="WITHDREW",
            withdrawnAtUtc=utc(570),
        )
        document["outcome"]["completedUnaided"] = False
        self.assert_invalid(document)
        document["outcome"].update(
            nextActionComprehension="DATA_GAP",
            nextActionSummaryCode=None,
            nextActionComprehensionAtUtc=None,
            nextActionComprehensionElapsedSeconds=None,
            nextActionComprehensionHelpRequested=None,
            nextActionComprehensionHelpProvided=None,
            walkingAsAdventure="DATA_GAP",
            companionReturn="DATA_GAP",
        )
        self.assert_valid(document)
        document["outcome"]["firstDayRewardReceiptAtUtc"] = utc(571)
        self.assert_invalid(document)
        document["session"].update(
            stopPauseAtUtc=utc(650),
            withdrawnAtUtc=utc(650),
        )
        document["outcome"].update(
            completedUnaided=True,
            firstDayRewardReceiptAtUtc=utc(480),
            nextActionComprehension="CLEAR",
            nextActionSummaryCode="continue_to_next_node",
            nextActionComprehensionAtUtc=utc(600),
            nextActionComprehensionElapsedSeconds=600,
            nextActionComprehensionHelpRequested=False,
            nextActionComprehensionHelpProvided=False,
            walkingAsAdventure="DATA_GAP",
            companionReturn="DATA_GAP",
        )
        document["evidence"]["redactionReviewedAtUtc"] = utc(900)
        self.assert_valid(document)
        document["session"].update(
            stopPauseAtUtc=utc(1000),
            withdrawnAtUtc=utc(1000),
        )
        document["outcome"].update(
            walkingAsAdventure="YES",
            companionReturn="YES",
        )
        document["evidence"]["redactionReviewedAtUtc"] = utc(1000)
        self.assert_valid(document)
        document["outcome"]["firstDayRewardReceiptAtUtc"] = utc(1001)
        self.assert_invalid(document)
        document["session"].update(
            stopPauseAtUtc=utc(50000),
            withdrawnAtUtc=utc(50000),
        )
        document["outcome"].update(
            firstDayRewardStatus="NO",
            firstDayRewardReceiptAtUtc=None,
        )
        document["evidence"]["redactionReviewedAtUtc"] = utc(50000)
        self.assert_valid(document)
        document["session"].update(
            stopPauseAtUtc=utc(1000),
            withdrawnAtUtc=utc(1000),
        )
        document["evidence"]["redactionReviewedAtUtc"] = utc(46800)
        self.assert_invalid(document)

    def test_post_task_pause_or_stop_preserves_completion(self) -> None:
        for status in ("PAUSED", "STOPPED"):
            with self.subTest(status=status):
                document = recorded()
                document["session"].update(
                    stopPauseStatus=status,
                    stopPauseAtUtc=utc(650),
                )
                if status == "STOPPED":
                    document["outcome"].update(
                        walkingAsAdventure="DATA_GAP",
                        companionReturn="DATA_GAP",
                    )
                self.assert_valid(document)
                document["session"]["stopPauseAtUtc"] = utc(590)
                self.assert_invalid(document)
                document["outcome"]["completedUnaided"] = False
                if status == "PAUSED":
                    self.assert_valid(document)
                else:
                    self.assert_invalid(document)

    def test_withdrawal_rejects_unanchored_data_gap_tail(self) -> None:
        document = recorded()
        for index in range(5, 10):
            set_gap(document, index, "DATA_GAP", "instrumentation_missing")
        document["session"].update(
            stopPauseStatus="STOPPED",
            stopPauseAtUtc=utc(200),
            withdrawalStatus="WITHDREW",
            withdrawnAtUtc=utc(200),
        )
        document["outcome"].update(
            completedUnaided=False,
            firstDayRewardStatus="DATA_GAP",
            firstDayRewardReceiptAtUtc=None,
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
        document["evidence"]["redactionReviewedAtUtc"] = utc(46800)
        self.assert_invalid(document)
        for index in range(5, 10):
            set_gap(document, index, "NOT_REACHED", "participant_withdrew")
        document["outcome"]["applicableMandatoryMilestones"] = 5
        self.assert_valid(document)

    def test_reward_cutoff_must_precede_shared_evidence_deadline(self) -> None:
        kickoff = ready_kickoff()
        delete_by = utc(640801)
        kickoff["evidence"]["participantEvidenceDeleteByUtc"] = delete_by
        document = recorded()
        start_seconds = 639900
        document.update(recordedAtUtc=utc(640700))
        document["kickoff"].update(
            recordSha256=kickoff_digest(kickoff),
            participantEvidenceDeleteByUtc=delete_by,
        )
        document["session"].update(
            startedAtUtc=utc(start_seconds),
            endedAtUtc=utc(start_seconds + 720),
        )
        for index, seconds in enumerate((0, 30, 60, 120, 180, 240, 300, 360, 480, 540)):
            document["milestones"][index].update(
                observedAtUtc=utc(start_seconds + seconds),
                elapsedSeconds=seconds,
            )
        document["outcome"].update(
            firstDayRewardStatus="PENDING",
            firstDayRewardReceiptAtUtc=None,
            firstDayTimeZoneOffsetMinutes=720,
            firstDayRewardCutoffAtUtc=utc(705600),
            nextActionComprehensionAtUtc=utc(start_seconds + 600),
        )
        document["evidence"].update(
            redactionReviewedAtUtc=utc(640650),
            participantEvidenceDeleteByUtc=delete_by,
        )
        self.assert_invalid(document, kickoff)
        delete_by = utc(705601)
        kickoff["evidence"]["participantEvidenceDeleteByUtc"] = delete_by
        document["kickoff"].update(
            recordSha256=kickoff_digest(kickoff),
            participantEvidenceDeleteByUtc=delete_by,
        )
        document["evidence"]["participantEvidenceDeleteByUtc"] = delete_by
        self.assert_valid(document, kickoff)

    def test_every_finding_requires_issue_and_safe_code(self) -> None:
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
        document["findings"][0].update(severity="EXPERIMENT", issueNumber=None)
        self.assert_invalid(document)
        document["findings"][0]["issueNumber"] = 480
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

    def test_referenced_kickoff_digest_is_exact(self) -> None:
        document = recorded()
        document["kickoff"]["recordSha256"] = "5" * 64
        self.assert_invalid(document)

    def test_session_identity_must_equal_referenced_kickoff(self) -> None:
        mutations = (
            ("protocol", "commitSha", "a" * 40),
            ("candidate", "sourceSha", "a" * 40),
            ("candidate", "treeSha", "b" * 40),
            ("candidate", "appVersion", "2.0.0"),
            ("candidate", "buildNumber", "43"),
            ("candidate", "platformArtifactSha256", "a" * 64),
            ("kickoff", "observationStartsAtUtc", "2026-08-20T07:00:01Z"),
            ("kickoff", "observationEndsAtUtc", "2026-08-27T17:59:59Z"),
            ("kickoff", "participantEvidenceDeleteByUtc", "2026-11-24T18:00:00Z"),
        )
        for section, key, value in mutations:
            with self.subTest(path=f"{section}.{key}"):
                document = recorded()
                document[section][key] = value
                self.assert_invalid(document)

    def test_recorded_cli_requires_exact_kickoff_file(self) -> None:
        kickoff = ready_kickoff()
        document = recorded()
        with tempfile.TemporaryDirectory() as directory:
            session_path = Path(directory) / (
                "internal-alpha-v1_" + document["candidate"]["sourceSha"]
                + "_ios_P01_20260820T080000Z_session.json"
            )
            kickoff_path = Path(directory) / "kickoff.json"
            session_path.write_text(json.dumps(document), encoding="utf-8")
            kickoff_path.write_bytes(encoded_kickoff(kickoff))
            missing = subprocess.run(
                [sys.executable, str(VALIDATOR), str(session_path), "--require-recorded"],
                check=False,
                capture_output=True,
                text=True,
            )
            accepted = subprocess.run(
                [
                    sys.executable,
                    str(VALIDATOR),
                    str(session_path),
                    "--kickoff",
                    str(kickoff_path),
                    "--require-recorded",
                ],
                check=False,
                capture_output=True,
                text=True,
            )
        self.assertNotEqual(missing.returncode, 0)
        self.assertEqual(accepted.returncode, 0, accepted.stderr)

    def test_recorded_cli_rejects_unsafe_or_arbitrary_filename(self) -> None:
        kickoff = ready_kickoff()
        document = recorded()
        with tempfile.TemporaryDirectory() as directory:
            session_path = Path(directory) / "participant@example.com.json"
            kickoff_path = Path(directory) / "kickoff.json"
            session_path.write_text(json.dumps(document), encoding="utf-8")
            kickoff_path.write_bytes(encoded_kickoff(kickoff))
            result = subprocess.run(
                [
                    sys.executable,
                    str(VALIDATOR),
                    str(session_path),
                    "--kickoff",
                    str(kickoff_path),
                    "--require-recorded",
                ],
                check=False,
                capture_output=True,
                text=True,
            )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("session filename", result.stderr)

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
