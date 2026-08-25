#!/usr/bin/env python3
"""Fail-closed validation for a redacted internal-alpha participant session."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import verify_internal_alpha_kickoff as kickoff_validator


SCHEMA = "walking-rpg-internal-alpha-session-v1"
PROTOCOL = "walking-rpg-internal-alpha-v1"
SHA = re.compile(r"[0-9a-f]{40}")
DIGEST = re.compile(r"[0-9a-f]{64}")
SEMVER = re.compile(r"[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?")
BUILD = re.compile(r"[1-9][0-9]{0,8}")
STUDY_CODE = re.compile(r"P(?:0[1-9]|1[0-2])")
UTC = re.compile(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z")
SAFE_CODE = re.compile(r"[a-z][a-z0-9_]{2,63}")
SENSITIVE = re.compile(
    r"(?i)(?:token|secret|password|bearer|email|phone|contact|imei|serial|"
    r"device_id|account_id|user_id|subject_id|installation_id)"
)
IDENTIFIER_LIKE = re.compile(r"(?:[0-9]{8,}|[0-9a-f]{16,})")

MILESTONES = [
    "registration_shown",
    "locale_selected",
    "authenticated_shell",
    "permission_decision",
    "first_sync_receipt",
    "first_energy",
    "companion_selected",
    "first_node_available",
    "first_event_resolved",
    "result_ack",
]
SOURCES = {
    "registration_shown": "client_observation",
    "locale_selected": "client_server",
    "authenticated_shell": "authoritative_client",
    "permission_decision": "platform_client",
    "first_sync_receipt": "authoritative",
    "first_energy": "authoritative",
    "companion_selected": "authoritative",
    "first_node_available": "authoritative",
    "first_event_resolved": "authoritative",
    "result_ack": "authoritative",
}
GAP_CODES = {
    "DATA_GAP": {"instrumentation_missing", "evidence_corrupt"},
    "NOT_REACHED": {"session_stopped", "participant_withdrew", "flow_blocked"},
}
NOT_APPLICABLE_CODES = {
    "permission_decision": {"permission_not_requested"},
    "first_energy": {
        "permission_denied",
        "permission_not_requested",
        "no_activity_data",
    },
}
UNAIDED_DEADLINES = {
    "locale_selected": 120,
    "authenticated_shell": 120,
    "permission_decision": 240,
    "first_sync_receipt": 240,
    "first_energy": 240,
    "companion_selected": 360,
    "first_node_available": 360,
    "first_event_resolved": 540,
    "result_ack": 540,
}
STORAGE_CATEGORIES = {
    "approved_internal_evidence",
    "encrypted_project_storage",
    "approved_research_workspace",
}
RU_TIME_ZONE_OFFSETS = set(range(120, 721, 60))


class SessionValidationError(ValueError):
    pass


def _fail(path: str, message: str) -> None:
    raise SessionValidationError(f"{path}: {message}")


def _unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            _fail("$", f"duplicate JSON key {key!r}")
        result[key] = value
    return result


def _keys(value: Any, expected: list[str], path: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        _fail(path, "must be an object")
    actual = list(value)
    if actual != expected:
        _fail(path, f"keys must be exactly {expected} in that order; got {actual}")
    return value


def _matches(value: Any, pattern: re.Pattern[str], path: str, description: str) -> str:
    if not isinstance(value, str) or not pattern.fullmatch(value):
        _fail(path, f"must be {description}")
    return value


def _utc(value: Any, path: str) -> datetime:
    raw = _matches(value, UTC, path, "an RFC 3339 UTC timestamp with whole seconds")
    try:
        return datetime.strptime(raw, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    except ValueError as error:
        _fail(path, f"must be a real timestamp ({error})")


def _integer(value: Any, path: str, *, positive: bool = False) -> int:
    minimum = 1 if positive else 0
    if type(value) is not int or value < minimum:
        label = "positive" if positive else "non-negative"
        _fail(path, f"must be a {label} integer")
    return value


def _template_nulls(value: dict[str, Any], path: str) -> None:
    for key, item in value.items():
        if item is not None:
            _fail(f"{path}.{key}", "must be null in the committed template")


def _validate_template(root: dict[str, Any]) -> None:
    if root["recordedAtUtc"] is not None:
        _fail("$.recordedAtUtc", "must be null in the committed template")
    if root["protocol"]["commitSha"] is not None:
        _fail("$.protocol.commitSha", "must be null in the committed template")
    _template_nulls(root["candidate"], "$.candidate")
    _template_nulls(root["kickoff"], "$.kickoff")
    session = root["session"]
    if session["moderatorRole"] != "approved_alpha_moderator":
        _fail("$.session.moderatorRole", "must preserve the approved role")
    _template_nulls(
        {key: value for key, value in session.items() if key != "moderatorRole"},
        "$.session",
    )
    for index, milestone in enumerate(root["milestones"]):
        path = f"$.milestones[{index}]"
        if milestone["milestoneId"] != MILESTONES[index]:
            _fail(f"{path}.milestoneId", "must preserve the protocol order")
        expected = {
            "status": "OWNER_INPUT_REQUIRED",
            "observedAtUtc": None,
            "elapsedSeconds": None,
            "sourceCategory": None,
            "helpRequested": None,
            "facilitatorHelpProvided": None,
            "gapReasonCode": None,
        }
        for key, value in expected.items():
            if milestone[key] != value:
                _fail(f"{path}.{key}", "must remain unclaimed in the template")
    _template_nulls(root["outcome"], "$.outcome")
    if root["findings"] != []:
        _fail("$.findings", "template findings must be empty")
    evidence = root["evidence"]
    if evidence["rawEvidenceCommittedToGit"] is not False:
        _fail("$.evidence.rawEvidenceCommittedToGit", "must be false")
    _template_nulls(
        {key: value for key, value in evidence.items() if key != "rawEvidenceCommittedToGit"},
        "$.evidence",
    )


def _validate_milestones(
    milestones: list[Any], started: datetime, ended: datetime
) -> dict[str, dict[str, Any]]:
    if len(milestones) != len(MILESTONES):
        _fail("$.milestones", f"must contain exactly {len(MILESTONES)} entries")
    result: dict[str, dict[str, Any]] = {}
    previous_time = started
    not_reached = False
    for index, value in enumerate(milestones):
        path = f"$.milestones[{index}]"
        milestone = _keys(value, [
            "milestoneId", "status", "observedAtUtc", "elapsedSeconds",
            "sourceCategory", "helpRequested", "facilitatorHelpProvided",
            "gapReasonCode",
        ], path)
        expected_id = MILESTONES[index]
        if milestone["milestoneId"] != expected_id:
            _fail(f"{path}.milestoneId", f"must be {expected_id!r}")
        status = milestone["status"]
        if not_reached and status != "NOT_REACHED":
            _fail(path, "every milestone after the first NOT_REACHED must remain NOT_REACHED")
        if status == "OBSERVED":
            observed = _utc(milestone["observedAtUtc"], f"{path}.observedAtUtc")
            if not started <= observed <= ended or observed < previous_time:
                _fail(f"{path}.observedAtUtc", "must be ordered within the session window")
            elapsed = _integer(milestone["elapsedSeconds"], f"{path}.elapsedSeconds")
            if elapsed != int((observed - started).total_seconds()):
                _fail(f"{path}.elapsedSeconds", "must exactly equal observedAtUtc - startedAtUtc")
            if expected_id == "registration_shown" and (observed != started or elapsed != 0):
                _fail(
                    path,
                    "registration_shown must anchor the session at startedAtUtc and zero seconds",
                )
            if milestone["sourceCategory"] != SOURCES[expected_id]:
                _fail(f"{path}.sourceCategory", f"must be {SOURCES[expected_id]!r}")
            if type(milestone["helpRequested"]) is not bool:
                _fail(f"{path}.helpRequested", "must be a boolean")
            if type(milestone["facilitatorHelpProvided"]) is not bool:
                _fail(f"{path}.facilitatorHelpProvided", "must be a boolean")
            if milestone["gapReasonCode"] is not None:
                _fail(f"{path}.gapReasonCode", "must be null when OBSERVED")
            previous_time = observed
        elif status in GAP_CODES:
            for key in ("observedAtUtc", "elapsedSeconds", "sourceCategory"):
                if milestone[key] is not None:
                    _fail(f"{path}.{key}", f"must be null when {status}")
            if status == "DATA_GAP":
                for key in ("helpRequested", "facilitatorHelpProvided"):
                    if type(milestone[key]) is not bool:
                        _fail(f"{path}.{key}", "must be a boolean when DATA_GAP")
            else:
                for key in ("helpRequested", "facilitatorHelpProvided"):
                    if milestone[key] is not None:
                        _fail(f"{path}.{key}", "must be null when NOT_REACHED")
            if milestone["gapReasonCode"] not in GAP_CODES[status]:
                _fail(
                    f"{path}.gapReasonCode",
                    f"must be one of {sorted(GAP_CODES[status])}",
                )
            if status == "NOT_REACHED":
                not_reached = True
        elif status == "NOT_APPLICABLE":
            for key in (
                "observedAtUtc", "elapsedSeconds", "sourceCategory",
                "helpRequested", "facilitatorHelpProvided",
            ):
                if milestone[key] is not None:
                    _fail(f"{path}.{key}", "must be null when NOT_APPLICABLE")
            expected_reasons = NOT_APPLICABLE_CODES.get(expected_id, set())
            if milestone["gapReasonCode"] not in expected_reasons:
                _fail(
                    f"{path}.gapReasonCode",
                    f"must be one of {sorted(expected_reasons)} when NOT_APPLICABLE",
                )
        else:
            _fail(
                f"{path}.status",
                "must be OBSERVED, DATA_GAP, NOT_APPLICABLE or NOT_REACHED",
            )
        if expected_id == "registration_shown" and status != "OBSERVED":
            _fail(path, "registration_shown must be OBSERVED at the session start")
        result[expected_id] = milestone
    return result


def _validate_outcome(
    outcome: dict[str, Any],
    milestones: dict[str, dict[str, Any]],
    stop_status: str,
    started: datetime,
    ended: datetime,
    recorded_at: datetime,
    withdrawal_at: datetime | None,
    stop_at: datetime | None,
) -> None:
    boolean_fields = ("completedUnaided", "permissionRequestShown")
    for key in boolean_fields:
        if type(outcome[key]) is not bool:
            _fail(f"$.outcome.{key}", "must be a boolean")
    permission = outcome["permissionDecision"]
    if outcome["permissionRequestShown"]:
        permission_status = milestones["permission_decision"]["status"]
        if permission in {"GRANTED", "DENIED"}:
            if permission_status != "OBSERVED":
                _fail(
                    "$.outcome.permissionRequestShown",
                    "recorded decision requires an observed permission milestone",
                )
        elif permission == "DATA_GAP":
            if permission_status != "DATA_GAP":
                _fail(
                    "$.outcome.permissionDecision",
                    "DATA_GAP requires a permission milestone instrumentation gap",
                )
        elif permission == "NOT_REACHED":
            gap_reason = milestones["permission_decision"]["gapReasonCode"]
            if not (
                permission_status == "NOT_REACHED"
                and gap_reason in {"participant_withdrew", "session_stopped", "flow_blocked"}
                and stop_status != "NOT_INVOKED"
                and (gap_reason != "participant_withdrew" or withdrawal_at is not None)
            ):
                _fail(
                    "$.outcome.permissionDecision",
                    "NOT_REACHED requires a consistent stopped, blocked or withdrawn tail",
                )
        else:
            _fail(
                "$.outcome.permissionDecision",
                "shown request requires GRANTED, DENIED, DATA_GAP or withdrawal NOT_REACHED",
            )
    elif permission != "NOT_APPLICABLE":
        _fail("$.outcome.permissionDecision", "unshown request requires NOT_APPLICABLE")
    else:
        permission_milestone = milestones["permission_decision"]
        if permission_milestone["status"] != "NOT_REACHED" and not (
            permission_milestone["status"] == "NOT_APPLICABLE"
            and permission_milestone["gapReasonCode"] == "permission_not_requested"
        ):
            _fail(
                "$.outcome.permissionRequestShown",
                "unshown request requires an explicit non-applicable stage or unreached tail",
            )
    reward_status = outcome["firstDayRewardStatus"]
    if reward_status not in {"YES", "NO", "DATA_GAP", "PENDING"}:
        _fail("$.outcome.firstDayRewardStatus", "must be YES, NO, DATA_GAP or PENDING")
    reward_receipt_raw = outcome["firstDayRewardReceiptAtUtc"]
    offset = outcome["firstDayTimeZoneOffsetMinutes"]
    if type(offset) is not int or offset not in RU_TIME_ZONE_OFFSETS:
        _fail(
            "$.outcome.firstDayTimeZoneOffsetMinutes",
            f"must be one of the RU cohort offsets {sorted(RU_TIME_ZONE_OFFSETS)}",
        )
    participant_zone = timezone(timedelta(minutes=offset))
    local_started = started.astimezone(participant_zone)
    expected_cutoff = (local_started + timedelta(days=1)).replace(
        hour=0,
        minute=0,
        second=0,
        microsecond=0,
    ).astimezone(timezone.utc)
    reward_cutoff = _utc(
        outcome["firstDayRewardCutoffAtUtc"],
        "$.outcome.firstDayRewardCutoffAtUtc",
    )
    if reward_cutoff != expected_cutoff:
        _fail(
            "$.outcome.firstDayRewardCutoffAtUtc",
            "must equal the next local midnight derived from session start and UTC offset",
        )
    withdrawal_before_cutoff = withdrawal_at is not None and withdrawal_at < reward_cutoff
    if withdrawal_before_cutoff and reward_status not in {"YES", "DATA_GAP"}:
        _fail(
            "$.outcome.firstDayRewardStatus",
            "withdrawal before cutoff without an existing receipt requires DATA_GAP",
        )
    if (
        recorded_at < reward_cutoff
        and reward_status not in {"YES", "PENDING"}
        and not (withdrawal_before_cutoff and reward_status == "DATA_GAP")
    ):
        _fail(
            "$.outcome.firstDayRewardStatus",
            "must remain PENDING before cutoff unless reward delivery is already YES",
        )
    if recorded_at >= reward_cutoff and reward_status == "PENDING":
        _fail("$.outcome.firstDayRewardStatus", "must be resolved at or after cutoff")
    if reward_status == "YES":
        reward_receipt = _utc(
            reward_receipt_raw,
            "$.outcome.firstDayRewardReceiptAtUtc",
        )
        if not started <= reward_receipt <= min(reward_cutoff, recorded_at):
            _fail(
                "$.outcome.firstDayRewardReceiptAtUtc",
                "must be between session start and both the cutoff and record time",
            )
        if withdrawal_at is not None and reward_receipt > withdrawal_at:
            _fail(
                "$.outcome.firstDayRewardReceiptAtUtc",
                "must not be collected after participant withdrawal",
            )
    elif reward_receipt_raw is not None:
        _fail(
            "$.outcome.firstDayRewardReceiptAtUtc",
            "must be null unless firstDayRewardStatus is YES",
        )

    candidate_sessions = _integer(outcome["candidateSessions"], "$.outcome.candidateSessions", positive=True)
    crash_free = _integer(outcome["crashFreeSessions"], "$.outcome.crashFreeSessions")
    sync_attempts = _integer(outcome["authoritativeSyncAttempts"], "$.outcome.authoritativeSyncAttempts")
    successful_syncs = _integer(
        outcome["successfulAuthoritativeSyncAttempts"],
        "$.outcome.successfulAuthoritativeSyncAttempts",
    )
    failed_syncs = _integer(
        outcome["failedNonCancelledSyncAttempts"],
        "$.outcome.failedNonCancelledSyncAttempts",
    )
    applicable = _integer(outcome["applicableMandatoryMilestones"], "$.outcome.applicableMandatoryMilestones")
    recorded = _integer(outcome["recordedMandatoryMilestones"], "$.outcome.recordedMandatoryMilestones")
    if crash_free > candidate_sessions:
        _fail("$.outcome.crashFreeSessions", "must not exceed candidateSessions")
    if successful_syncs + failed_syncs > sync_attempts:
        _fail(
            "$.outcome",
            "successful plus failed non-cancelled sync attempts must not exceed authoritative attempts",
        )
    if milestones["first_sync_receipt"]["status"] == "OBSERVED" and successful_syncs == 0:
        _fail(
            "$.outcome.successfulAuthoritativeSyncAttempts",
            "an observed sync receipt requires at least one successful authoritative attempt",
        )
    if milestones["first_sync_receipt"]["status"] == "NOT_REACHED" and successful_syncs != 0:
        _fail(
            "$.outcome.successfulAuthoritativeSyncAttempts",
            "an unreached sync receipt requires zero successful authoritative attempts",
        )
    sync_gap_has_attempt = not (
        milestones["first_sync_receipt"]["status"] == "DATA_GAP"
        and successful_syncs == 0
    )
    reached = []
    for item in milestones.values():
        if item["status"] == "NOT_REACHED":
            break
        reached.append(item)
    actual_applicable = sum(item["status"] != "NOT_APPLICABLE" for item in reached)
    energy = milestones["first_energy"]
    if permission == "DENIED":
        if energy["status"] != "NOT_REACHED" and not (
            energy["status"] == "NOT_APPLICABLE" and energy["gapReasonCode"] == "permission_denied"
        ):
            _fail(
                "$.milestones[5]",
                "DENIED permission requires first_energy to be NOT_APPLICABLE or in a NOT_REACHED tail",
            )
    elif permission == "GRANTED" and energy["status"] == "NOT_APPLICABLE":
        if energy["gapReasonCode"] != "no_activity_data":
            _fail(
                "$.milestones[5]",
                "GRANTED permission permits NOT_APPLICABLE only when no activity data exists",
            )
    elif permission == "DATA_GAP" and energy["status"] == "NOT_APPLICABLE":
        _fail(
            "$.milestones[5]",
            "decision-dependent ENERGY non-applicability requires a represented permission decision",
        )
    elif permission == "NOT_APPLICABLE" and energy["status"] != "NOT_REACHED" and not (
        energy["status"] == "NOT_APPLICABLE"
        and energy["gapReasonCode"] == "permission_not_requested"
    ):
        _fail(
            "$.milestones[5]",
            "unshown permission request requires first_energy to be NOT_APPLICABLE or unreached",
        )
    if applicable != actual_applicable:
        _fail(
            "$.outcome.applicableMandatoryMilestones",
            "must equal applicable stages before the first NOT_REACHED stage",
        )
    if recorded > applicable:
        _fail("$.outcome.recordedMandatoryMilestones", "must not exceed applicableMandatoryMilestones")
    actual_recorded = sum(item["status"] == "OBSERVED" for item in milestones.values())
    if recorded != actual_recorded:
        _fail("$.outcome.recordedMandatoryMilestones", "must equal the observed milestone count")

    comprehension = outcome["nextActionComprehension"]
    if comprehension not in {"CLEAR", "PARTIAL", "UNCLEAR", "DATA_GAP"}:
        _fail("$.outcome.nextActionComprehension", "has an unsupported code")
    summary_code = outcome["nextActionSummaryCode"]
    comprehension_at = outcome["nextActionComprehensionAtUtc"]
    comprehension_elapsed = outcome["nextActionComprehensionElapsedSeconds"]
    comprehension_help = outcome["nextActionComprehensionHelpRequested"]
    comprehension_help_provided = outcome["nextActionComprehensionHelpProvided"]
    demonstrated = None
    if comprehension == "DATA_GAP":
        if (
            summary_code is not None
            or comprehension_at is not None
            or comprehension_elapsed is not None
            or comprehension_help is not None
            or comprehension_help_provided is not None
        ):
            _fail(
                "$.outcome.nextActionComprehension",
                "DATA_GAP requires null summary, timing and help fields",
            )
    else:
        summary_code = _matches(
            summary_code,
            SAFE_CODE,
            "$.outcome.nextActionSummaryCode",
            "a sanitized next-action summary code",
        )
        if SENSITIVE.search(summary_code) or IDENTIFIER_LIKE.search(summary_code):
            _fail(
                "$.outcome.nextActionSummaryCode",
                "must not contain sensitive or identifier-like data",
            )
        if type(comprehension_help) is not bool:
            _fail(
                "$.outcome.nextActionComprehensionHelpRequested",
                "must be a boolean when comprehension is recorded",
            )
        if type(comprehension_help_provided) is not bool:
            _fail(
                "$.outcome.nextActionComprehensionHelpProvided",
                "must be a boolean when comprehension is recorded",
            )
        demonstrated = _utc(
            comprehension_at,
            "$.outcome.nextActionComprehensionAtUtc",
        )
        if not started <= demonstrated <= ended:
            _fail(
                "$.outcome.nextActionComprehensionAtUtc",
                "must be within the session window",
            )
        elapsed = _integer(
            comprehension_elapsed,
            "$.outcome.nextActionComprehensionElapsedSeconds",
        )
        if elapsed != int((demonstrated - started).total_seconds()):
            _fail(
                "$.outcome.nextActionComprehensionElapsedSeconds",
                "must exactly equal nextActionComprehensionAtUtc - startedAtUtc",
            )
        if not 540 <= elapsed <= 600:
            _fail(
                "$.outcome.nextActionComprehensionElapsedSeconds",
                "must be within the protocol comprehension task window of 540 through 600 seconds",
            )
        result_ack = milestones["result_ack"]
        if result_ack["status"] != "OBSERVED":
            _fail(
                "$.outcome.nextActionComprehension",
                "requires an observed result ACK",
            )
        result_ack_at = _utc(
            result_ack["observedAtUtc"],
            "$.milestones[9].observedAtUtc",
        )
        if demonstrated < result_ack_at:
            _fail(
                "$.outcome.nextActionComprehensionAtUtc",
                "must be at or after the result ACK",
            )
        if stop_status == "STOPPED" and stop_at is not None and demonstrated > stop_at:
            _fail(
                "$.outcome.nextActionComprehensionAtUtc",
                "must not record comprehension after a terminal stop",
            )
    for key in ("walkingAsAdventure", "companionReturn"):
        if outcome[key] not in {"YES", "PARTIAL", "NO", "DATA_GAP"}:
            _fail(f"$.outcome.{key}", "has an unsupported code")
    if stop_status == "STOPPED" and stop_at < ended and any(
        outcome[key] != "DATA_GAP"
        for key in ("walkingAsAdventure", "companionReturn")
    ):
        _fail(
            "$.outcome",
            "terminal stop before session end requires qualitative DATA_GAP values",
        )
    if reward_status == "YES":
        reward_event = milestones["first_event_resolved"]
        if reward_event["status"] not in {"OBSERVED", "DATA_GAP"}:
            _fail(
                "$.outcome.firstDayRewardStatus",
                "YES requires event resolution to be observed or have an instrumentation gap",
            )
        if reward_event["status"] == "OBSERVED":
            reward_event_at = _utc(
                reward_event["observedAtUtc"],
                "$.milestones[8].observedAtUtc",
            )
            if reward_receipt < reward_event_at:
                _fail(
                    "$.outcome.firstDayRewardReceiptAtUtc",
                    "must be at or after the authoritative event resolution",
                )
        else:
            observed_prerequisites = [
                item for milestone_id, item in milestones.items()
                if milestone_id != "first_event_resolved"
                and MILESTONES.index(milestone_id) < MILESTONES.index("first_event_resolved")
                and item["status"] == "OBSERVED"
            ]
            latest_prerequisite = max(
                _utc(item["observedAtUtc"], "$.milestones[].observedAtUtc")
                for item in observed_prerequisites
            )
            if reward_receipt < latest_prerequisite:
                _fail(
                    "$.outcome.firstDayRewardReceiptAtUtc",
                    "event DATA_GAP receipt must follow the latest observed prerequisite",
                )
    stop_blocks_unaided = not (
        stop_at is None
        or (
            demonstrated is not None
            and stop_at >= demonstrated
        )
    )
    if outcome["completedUnaided"]:
        if stop_blocks_unaided:
            _fail("$.outcome.completedUnaided", "cannot be true for a paused/stopped session")
        if any(
            item["status"] not in {"OBSERVED", "DATA_GAP", "NOT_APPLICABLE"}
            for item in milestones.values()
        ):
            _fail(
                "$.outcome.completedUnaided",
                "requires every applicable milestone to be observed",
            )
        if any(
            item["helpRequested"] or item["facilitatorHelpProvided"]
            for item in milestones.values()
        ):
            _fail("$.outcome.completedUnaided", "requires no facilitator help")
        if not sync_gap_has_attempt:
            _fail(
                "$.outcome.completedUnaided",
                "sync DATA_GAP requires at least one successful authoritative attempt",
            )
        for milestone_id, deadline in UNAIDED_DEADLINES.items():
            item = milestones[milestone_id]
            if item["status"] == "OBSERVED" and item["elapsedSeconds"] > deadline:
                _fail(
                    "$.outcome.completedUnaided",
                    f"requires {milestone_id} within {deadline} seconds",
                )
        if comprehension != "CLEAR":
            _fail("$.outcome.completedUnaided", "requires CLEAR next-action comprehension")
        if comprehension_help:
            _fail(
                "$.outcome.completedUnaided",
                "requires no facilitator help during next-action comprehension",
            )
        if comprehension_help_provided:
            _fail(
                "$.outcome.completedUnaided",
                "requires no provided help during next-action comprehension",
            )
        if comprehension_elapsed > 600:
            _fail(
                "$.outcome.completedUnaided",
                "requires next-action comprehension within 600 seconds",
            )
    else:
        evidence_is_unaided = (
            not stop_blocks_unaided
            and all(
                item["status"] in {"OBSERVED", "DATA_GAP", "NOT_APPLICABLE"}
                for item in milestones.values()
            )
            and not any(
                item["helpRequested"] or item["facilitatorHelpProvided"]
                for item in milestones.values()
            )
            and sync_gap_has_attempt
            and all(
                item["status"] != "OBSERVED" or item["elapsedSeconds"] <= deadline
                for milestone_id, deadline in UNAIDED_DEADLINES.items()
                for item in (milestones[milestone_id],)
            )
            and comprehension == "CLEAR"
            and not comprehension_help
            and not comprehension_help_provided
            and comprehension_elapsed <= 600
        )
        if evidence_is_unaided:
            _fail(
                "$.outcome.completedUnaided",
                "must be true when the recorded evidence satisfies the unaided predicate",
            )


def _validate_findings(findings: Any) -> None:
    if not isinstance(findings, list) or len(findings) > 32:
        _fail("$.findings", "must be an array of at most 32 findings")
    seen: set[str] = set()
    for index, value in enumerate(findings):
        path = f"$.findings[{index}]"
        finding = _keys(value, [
            "findingCode", "stageId", "severity", "reproducible", "owner",
            "issueNumber", "evidenceDigestSha256",
        ], path)
        code = _matches(finding["findingCode"], SAFE_CODE, f"{path}.findingCode", "a sanitized finding code")
        if SENSITIVE.search(code) or IDENTIFIER_LIKE.search(code):
            _fail(f"{path}.findingCode", "must not contain sensitive or identifier-like data")
        if code in seen:
            _fail(f"{path}.findingCode", "must be unique within the session")
        seen.add(code)
        if finding["stageId"] not in {"session", *MILESTONES}:
            _fail(f"{path}.stageId", "must be session or a protocol milestone ID")
        severity = finding["severity"]
        if severity not in {"STOP", "FIX_BEFORE_EXPAND", "EXPERIMENT", "LATER"}:
            _fail(f"{path}.severity", "has an unsupported severity")
        if type(finding["reproducible"]) is not bool:
            _fail(f"{path}.reproducible", "must be a boolean")
        if finding["owner"] != "MKSEgr":
            _fail(f"{path}.owner", "must be MKSEgr")
        issue = finding["issueNumber"]
        if issue is None:
            _fail(f"{path}.issueNumber", "every finding requires a linked issue")
        _integer(issue, f"{path}.issueNumber", positive=True)
        _matches(
            finding["evidenceDigestSha256"],
            DIGEST,
            f"{path}.evidenceDigestSha256",
            "a lowercase SHA-256",
        )


def _validate_kickoff_reference(
    root: dict[str, Any],
    referenced_kickoff: Any,
    referenced_kickoff_sha256: str | None,
) -> None:
    if referenced_kickoff is None or referenced_kickoff_sha256 is None:
        _fail("$.kickoff.recordSha256", "RECORDED evidence requires --kickoff")
    try:
        kickoff_validator.validate_kickoff(referenced_kickoff, require_ready=True)
    except kickoff_validator.KickoffValidationError as error:
        _fail("$kickoff", f"referenced kickoff is invalid: {error}")
    if root["kickoff"]["recordSha256"] != referenced_kickoff_sha256:
        _fail(
            "$.kickoff.recordSha256",
            "must equal the SHA-256 of the exact referenced kickoff file",
        )

    comparisons = (
        ("$.protocol.commitSha", root["protocol"]["commitSha"], referenced_kickoff["protocol"]["commitSha"]),
        ("$.candidate.sourceSha", root["candidate"]["sourceSha"], referenced_kickoff["candidate"]["sourceSha"]),
        ("$.candidate.treeSha", root["candidate"]["treeSha"], referenced_kickoff["candidate"]["treeSha"]),
        ("$.candidate.appVersion", root["candidate"]["appVersion"], referenced_kickoff["candidate"]["appVersion"]),
        ("$.candidate.buildNumber", root["candidate"]["buildNumber"], referenced_kickoff["candidate"]["buildNumber"]),
        (
            "$.candidate.platformArtifactSha256",
            root["candidate"]["platformArtifactSha256"],
            referenced_kickoff["candidate"][root["session"]["platform"]]["artifactSha256"],
        ),
        (
            "$.kickoff.observationStartsAtUtc",
            root["kickoff"]["observationStartsAtUtc"],
            referenced_kickoff["observationWindow"]["startsAtUtc"],
        ),
        (
            "$.kickoff.observationEndsAtUtc",
            root["kickoff"]["observationEndsAtUtc"],
            referenced_kickoff["observationWindow"]["endsAtUtc"],
        ),
        (
            "$.kickoff.participantEvidenceDeleteByUtc",
            root["kickoff"]["participantEvidenceDeleteByUtc"],
            referenced_kickoff["evidence"]["participantEvidenceDeleteByUtc"],
        ),
    )
    for path, actual, expected in comparisons:
        if actual != expected:
            _fail(path, "must equal the referenced kickoff contract")


def validate_session(
    document: Any,
    *,
    require_recorded: bool = False,
    referenced_kickoff: Any = None,
    referenced_kickoff_sha256: str | None = None,
) -> None:
    root = _keys(document, [
        "schemaVersion", "recordStatus", "recordedAtUtc", "protocol",
        "candidate", "kickoff", "session", "milestones", "outcome", "findings",
        "evidence",
    ], "$")
    if root["schemaVersion"] != SCHEMA:
        _fail("$.schemaVersion", f"must be {SCHEMA}")
    if root["recordStatus"] not in {"TEMPLATE", "RECORDED"}:
        _fail("$.recordStatus", "must be TEMPLATE or RECORDED")
    if require_recorded and root["recordStatus"] != "RECORDED":
        _fail("$.recordStatus", "--require-recorded rejects a template")
    protocol = _keys(root["protocol"], ["protocolId", "commitSha"], "$.protocol")
    if protocol["protocolId"] != PROTOCOL:
        _fail("$.protocol.protocolId", f"must be {PROTOCOL}")
    candidate = _keys(root["candidate"], [
        "sourceSha", "treeSha", "appVersion", "buildNumber",
        "platformArtifactSha256",
    ], "$.candidate")
    kickoff = _keys(root["kickoff"], [
        "recordSha256", "observationStartsAtUtc", "observationEndsAtUtc",
        "participantEvidenceDeleteByUtc",
    ], "$.kickoff")
    session = _keys(root["session"], [
        "studyCode", "platform", "deviceEnvironment", "sessionDriver",
        "adultEligibilityConfirmed", "selectedLocale", "startedAtUtc",
        "endedAtUtc", "moderatorRole", "consentConfirmed",
        "withdrawalRouteExplained", "exactCandidateVerified", "stopPauseStatus",
        "stopPauseAtUtc", "withdrawalStatus", "withdrawnAtUtc",
    ], "$.session")
    if not isinstance(root["milestones"], list) or len(root["milestones"]) != len(MILESTONES):
        _fail("$.milestones", f"must contain exactly {len(MILESTONES)} entries")
    for index, value in enumerate(root["milestones"]):
        _keys(value, [
            "milestoneId", "status", "observedAtUtc", "elapsedSeconds",
            "sourceCategory", "helpRequested", "facilitatorHelpProvided",
            "gapReasonCode",
        ], f"$.milestones[{index}]")
    outcome = _keys(root["outcome"], [
        "completedUnaided", "permissionRequestShown", "permissionDecision",
        "firstDayRewardStatus", "firstDayRewardReceiptAtUtc",
        "firstDayTimeZoneOffsetMinutes", "firstDayRewardCutoffAtUtc",
        "candidateSessions", "crashFreeSessions",
        "authoritativeSyncAttempts", "successfulAuthoritativeSyncAttempts",
        "failedNonCancelledSyncAttempts",
        "applicableMandatoryMilestones", "recordedMandatoryMilestones",
        "nextActionComprehension", "nextActionSummaryCode",
        "nextActionComprehensionAtUtc",
        "nextActionComprehensionElapsedSeconds",
        "nextActionComprehensionHelpRequested",
        "nextActionComprehensionHelpProvided", "walkingAsAdventure", "companionReturn",
    ], "$.outcome")
    evidence = _keys(root["evidence"], [
        "storageCategory", "evidencePackageSha256", "redactionReviewedAtUtc",
        "redactionReviewerRole", "participantEvidenceDeleteByUtc",
        "rawEvidenceCommittedToGit",
    ], "$.evidence")
    if root["recordStatus"] == "TEMPLATE":
        _validate_template(root)
        return

    recorded_at = _utc(root["recordedAtUtc"], "$.recordedAtUtc")
    _matches(protocol["commitSha"], SHA, "$.protocol.commitSha", "a lowercase 40-hex SHA")
    _matches(candidate["sourceSha"], SHA, "$.candidate.sourceSha", "a lowercase 40-hex SHA")
    _matches(candidate["treeSha"], SHA, "$.candidate.treeSha", "a lowercase 40-hex SHA")
    _matches(candidate["appVersion"], SEMVER, "$.candidate.appVersion", "a semantic version")
    _matches(candidate["buildNumber"], BUILD, "$.candidate.buildNumber", "a positive build number string")
    _matches(candidate["platformArtifactSha256"], DIGEST, "$.candidate.platformArtifactSha256", "a lowercase SHA-256")
    _matches(kickoff["recordSha256"], DIGEST, "$.kickoff.recordSha256", "a lowercase SHA-256")
    _matches(session["studyCode"], STUDY_CODE, "$.session.studyCode", "P01 through P12")
    if session["platform"] not in {"ios", "android"}:
        _fail("$.session.platform", "must be ios or android")
    if session["deviceEnvironment"] != "physical_device":
        _fail("$.session.deviceEnvironment", "must be physical_device")
    if session["sessionDriver"] != "participant":
        _fail("$.session.sessionDriver", "must be participant")
    if session["adultEligibilityConfirmed"] is not True:
        _fail("$.session.adultEligibilityConfirmed", "must be true")
    _validate_kickoff_reference(root, referenced_kickoff, referenced_kickoff_sha256)
    kickoff_started = _utc(kickoff["observationStartsAtUtc"], "$.kickoff.observationStartsAtUtc")
    kickoff_ended = _utc(kickoff["observationEndsAtUtc"], "$.kickoff.observationEndsAtUtc")
    kickoff_delete_by = _utc(
        kickoff["participantEvidenceDeleteByUtc"],
        "$.kickoff.participantEvidenceDeleteByUtc",
    )
    if not kickoff_started < kickoff_ended < kickoff_delete_by <= kickoff_ended + timedelta(days=90):
        _fail(
            "$.kickoff",
            "must satisfy observation start < end < shared deletion deadline <= end + 90 days",
        )

    started = _utc(session["startedAtUtc"], "$.session.startedAtUtc")
    ended = _utc(session["endedAtUtc"], "$.session.endedAtUtc")
    if not started < ended <= recorded_at:
        _fail("$.session", "must satisfy startedAtUtc < endedAtUtc <= recordedAtUtc")
    if not kickoff_started <= started < ended <= kickoff_ended:
        _fail("$.session", "must be contained within the referenced kickoff observation window")
    if ended - started > timedelta(hours=4):
        _fail("$.session.endedAtUtc", "session window must not exceed four hours")
    if session["moderatorRole"] != "approved_alpha_moderator":
        _fail("$.session.moderatorRole", "must be approved_alpha_moderator")
    for key in ("consentConfirmed", "withdrawalRouteExplained", "exactCandidateVerified"):
        if session[key] is not True:
            _fail(f"$.session.{key}", "must be true before accepted session evidence")
    stop_status = session["stopPauseStatus"]
    if stop_status not in {"NOT_INVOKED", "PAUSED", "STOPPED"}:
        _fail("$.session.stopPauseStatus", "has an unsupported code")
    stop_at = None
    if stop_status == "NOT_INVOKED":
        if session["stopPauseAtUtc"] is not None:
            _fail("$.session.stopPauseAtUtc", "must be null when stop/pause was not invoked")
    else:
        stop_at = _utc(session["stopPauseAtUtc"], "$.session.stopPauseAtUtc")
        if not started <= stop_at <= recorded_at:
            _fail(
                "$.session.stopPauseAtUtc",
                "must be between session start and record finalization",
            )
    withdrawal_status = session["withdrawalStatus"]
    if withdrawal_status not in {"NOT_WITHDRAWN", "WITHDREW"}:
        _fail("$.session.withdrawalStatus", "must be NOT_WITHDRAWN or WITHDREW")
    withdrawal_at = None
    if withdrawal_status == "NOT_WITHDRAWN":
        if session["withdrawnAtUtc"] is not None:
            _fail("$.session.withdrawnAtUtc", "must be null when the participant did not withdraw")
    else:
        if stop_status != "STOPPED":
            _fail("$.session.stopPauseStatus", "participant withdrawal requires STOPPED")
        withdrawal_at = _utc(session["withdrawnAtUtc"], "$.session.withdrawnAtUtc")
        if not started <= withdrawal_at <= recorded_at:
            _fail(
                "$.session.withdrawnAtUtc",
                "must be between session start and record finalization",
            )
        if stop_at != withdrawal_at:
            _fail(
                "$.session.stopPauseAtUtc",
                "withdrawal STOPPED time must equal withdrawnAtUtc",
            )

    milestone_map = _validate_milestones(root["milestones"], started, ended)
    selected_locale = session["selectedLocale"]
    if milestone_map["locale_selected"]["status"] == "OBSERVED":
        if selected_locale not in referenced_kickoff["cohort"]["languages"]:
            _fail(
                "$.session.selectedLocale",
                "must be one of the languages approved by the referenced kickoff",
            )
    elif selected_locale is not None:
        _fail(
            "$.session.selectedLocale",
            "must be null when locale_selected is not OBSERVED",
        )
    gap_reasons = {item["gapReasonCode"] for item in milestone_map.values()}
    if stop_status == "NOT_INVOKED" and "session_stopped" in gap_reasons:
        _fail("$.session.stopPauseStatus", "session_stopped gaps require PAUSED or STOPPED")
    if "flow_blocked" in gap_reasons and stop_status != "STOPPED":
        _fail("$.session.stopPauseStatus", "flow_blocked gaps require STOPPED")
    if gap_reasons & {"session_stopped", "flow_blocked"} and stop_at > ended:
        _fail(
            "$.session.stopPauseAtUtc",
            "a stop-backed journey tail requires stop/pause during the session",
        )
    if "participant_withdrew" in gap_reasons and withdrawal_status != "WITHDREW":
        _fail(
            "$.session.withdrawalStatus",
            "participant_withdrew gaps require session-level WITHDREW evidence",
        )
    if "participant_withdrew" in gap_reasons and withdrawal_at > ended:
        _fail(
            "$.session.withdrawnAtUtc",
            "a participant-withdrew journey tail requires withdrawal during the session",
        )
    if stop_status == "STOPPED" and stop_at is not None and stop_at <= ended:
        last_observed_index = max(
            (
                index
                for index, item in enumerate(milestone_map.values())
                if item["status"] == "OBSERVED"
            ),
            default=-1,
        )
        for index, item in enumerate(milestone_map.values()):
            if item["status"] == "OBSERVED" and _utc(
                item["observedAtUtc"], f"$.milestones[{index}].observedAtUtc"
            ) > stop_at:
                _fail(f"$.milestones[{index}]", "must not be observed after final stop/pause")
            if index > last_observed_index and item["status"] != "NOT_REACHED":
                _fail(
                    f"$.milestones[{index}]",
                    "stages after the last observed pre-stop milestone must be NOT_REACHED",
                )
    if withdrawal_status == "WITHDREW":
        for index, item in enumerate(milestone_map.values()):
            if item["status"] == "OBSERVED" and _utc(
                item["observedAtUtc"], f"$.milestones[{index}].observedAtUtc"
            ) > withdrawal_at:
                _fail(f"$.milestones[{index}]", "must not be observed after withdrawal")
    _validate_outcome(
        outcome,
        milestone_map,
        stop_status,
        started,
        ended,
        recorded_at,
        withdrawal_at,
        stop_at,
    )
    if withdrawal_status == "WITHDREW":
        comprehension_at = outcome["nextActionComprehensionAtUtc"]
        if comprehension_at is not None and _utc(
            comprehension_at, "$.outcome.nextActionComprehensionAtUtc"
        ) > withdrawal_at:
            _fail(
                "$.outcome.nextActionComprehensionAtUtc",
                "must not record comprehension after withdrawal",
            )
        if withdrawal_at <= ended and any(
            outcome[key] != "DATA_GAP"
            for key in ("walkingAsAdventure", "companionReturn")
        ):
            _fail(
                "$.outcome",
                "withdrawal during the moderated session requires qualitative DATA_GAP values",
            )
    reward_cutoff = _utc(
        outcome["firstDayRewardCutoffAtUtc"],
        "$.outcome.firstDayRewardCutoffAtUtc",
    )
    if kickoff_delete_by <= reward_cutoff:
        _fail(
            "$.kickoff.participantEvidenceDeleteByUtc",
            "must be later than this session's first-day reward cutoff",
        )
    _validate_findings(root["findings"])

    if evidence["storageCategory"] not in STORAGE_CATEGORIES:
        _fail("$.evidence.storageCategory", f"must be one of {sorted(STORAGE_CATEGORIES)}")
    _matches(evidence["evidencePackageSha256"], DIGEST, "$.evidence.evidencePackageSha256", "a lowercase SHA-256")
    reviewed = _utc(evidence["redactionReviewedAtUtc"], "$.evidence.redactionReviewedAtUtc")
    if withdrawal_at is not None and reviewed < withdrawal_at:
        _fail(
            "$.evidence.redactionReviewedAtUtc",
            "must be at or after participant withdrawal",
        )
    if outcome["firstDayRewardStatus"] in {"NO", "DATA_GAP"} and reviewed < reward_cutoff:
        _fail(
            "$.evidence.redactionReviewedAtUtc",
            "resolved non-YES reward evidence must be reviewed at or after the cutoff",
        )
    if outcome["firstDayRewardStatus"] == "YES":
        reward_receipt = _utc(
            outcome["firstDayRewardReceiptAtUtc"],
            "$.outcome.firstDayRewardReceiptAtUtc",
        )
        if reward_receipt > reviewed:
            _fail(
                "$.evidence.redactionReviewedAtUtc",
                "must be at or after the authoritative reward receipt",
            )
    if evidence["redactionReviewerRole"] != "approved_redaction_reviewer":
        _fail("$.evidence.redactionReviewerRole", "must be approved_redaction_reviewer")
    delete_by = _utc(evidence["participantEvidenceDeleteByUtc"], "$.evidence.participantEvidenceDeleteByUtc")
    if delete_by != kickoff_delete_by:
        _fail(
            "$.evidence.participantEvidenceDeleteByUtc",
            "must equal the shared deletion deadline in the referenced kickoff contract",
        )
    if not ended <= reviewed <= recorded_at < delete_by:
        _fail(
            "$.evidence",
            "must satisfy ended <= redaction review <= recorded < shared deletion deadline",
        )
    if evidence["rawEvidenceCommittedToGit"] is not False:
        _fail("$.evidence.rawEvidenceCommittedToGit", "must be false")


def load_session(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=_unique_object)
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise SessionValidationError(f"cannot read strict UTF-8 JSON: {error}") from error


def _validate_session_filename(path: Path, document: dict[str, Any]) -> None:
    session_start = document["session"]["startedAtUtc"].replace("-", "").replace(":", "")
    expected = (
        f"internal-alpha-v1_{document['candidate']['sourceSha']}_"
        f"{document['session']['platform']}_{document['session']['studyCode']}_"
        f"{session_start}_session.json"
    )
    if path.name != expected:
        _fail("session filename", f"must be exactly {expected!r}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("session", type=Path)
    parser.add_argument("--kickoff", type=Path)
    parser.add_argument("--require-recorded", action="store_true")
    args = parser.parse_args(argv)
    try:
        document = load_session(args.session)
        referenced_kickoff = None
        referenced_kickoff_sha256 = None
        if args.kickoff is not None:
            referenced_kickoff = kickoff_validator.load_kickoff(args.kickoff)
            referenced_kickoff_sha256 = hashlib.sha256(args.kickoff.read_bytes()).hexdigest()
        validate_session(
            document,
            require_recorded=args.require_recorded,
            referenced_kickoff=referenced_kickoff,
            referenced_kickoff_sha256=referenced_kickoff_sha256,
        )
        if document["recordStatus"] == "RECORDED":
            _validate_session_filename(args.session, document)
    except (SessionValidationError, kickoff_validator.KickoffValidationError, OSError) as error:
        print(f"Internal-alpha session invalid: {error}", file=sys.stderr)
        return 1
    print(f"Internal-alpha session valid: {args.session}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
