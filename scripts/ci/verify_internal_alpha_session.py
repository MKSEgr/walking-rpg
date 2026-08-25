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
STORAGE_CATEGORIES = {
    "approved_internal_evidence",
    "encrypted_project_storage",
    "approved_research_workspace",
}


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
            "sourceCategory", "helpRequested", "gapReasonCode",
        ], path)
        expected_id = MILESTONES[index]
        if milestone["milestoneId"] != expected_id:
            _fail(f"{path}.milestoneId", f"must be {expected_id!r}")
        status = milestone["status"]
        if status == "OBSERVED":
            if not_reached:
                _fail(path, "an OBSERVED milestone cannot follow NOT_REACHED")
            observed = _utc(milestone["observedAtUtc"], f"{path}.observedAtUtc")
            if not started <= observed <= ended or observed < previous_time:
                _fail(f"{path}.observedAtUtc", "must be ordered within the session window")
            elapsed = _integer(milestone["elapsedSeconds"], f"{path}.elapsedSeconds")
            if elapsed != int((observed - started).total_seconds()):
                _fail(f"{path}.elapsedSeconds", "must exactly equal observedAtUtc - startedAtUtc")
            if milestone["sourceCategory"] != SOURCES[expected_id]:
                _fail(f"{path}.sourceCategory", f"must be {SOURCES[expected_id]!r}")
            if type(milestone["helpRequested"]) is not bool:
                _fail(f"{path}.helpRequested", "must be a boolean")
            if milestone["gapReasonCode"] is not None:
                _fail(f"{path}.gapReasonCode", "must be null when OBSERVED")
            previous_time = observed
        elif status in GAP_CODES:
            for key in ("observedAtUtc", "elapsedSeconds", "sourceCategory", "helpRequested"):
                if milestone[key] is not None:
                    _fail(f"{path}.{key}", f"must be null when {status}")
            if milestone["gapReasonCode"] not in GAP_CODES[status]:
                _fail(
                    f"{path}.gapReasonCode",
                    f"must be one of {sorted(GAP_CODES[status])}",
                )
            if status == "NOT_REACHED":
                not_reached = True
        else:
            _fail(f"{path}.status", "must be OBSERVED, DATA_GAP or NOT_REACHED")
        result[expected_id] = milestone
    return result


def _validate_outcome(
    outcome: dict[str, Any],
    milestones: dict[str, dict[str, Any]],
    stop_status: str,
    started: datetime,
    ended: datetime,
) -> None:
    boolean_fields = ("completedUnaided", "permissionRequestShown")
    for key in boolean_fields:
        if type(outcome[key]) is not bool:
            _fail(f"$.outcome.{key}", "must be a boolean")
    permission = outcome["permissionDecision"]
    if outcome["permissionRequestShown"]:
        if permission not in {"GRANTED", "DENIED"}:
            _fail("$.outcome.permissionDecision", "shown request requires GRANTED or DENIED")
        if milestones["permission_decision"]["status"] != "OBSERVED":
            _fail("$.outcome.permissionRequestShown", "requires an observed permission milestone")
    elif permission != "NOT_APPLICABLE":
        _fail("$.outcome.permissionDecision", "unshown request requires NOT_APPLICABLE")
    if outcome["firstDayRewardStatus"] not in {"YES", "NO", "DATA_GAP"}:
        _fail("$.outcome.firstDayRewardStatus", "must be YES, NO or DATA_GAP")

    candidate_sessions = _integer(outcome["candidateSessions"], "$.outcome.candidateSessions", positive=True)
    crash_free = _integer(outcome["crashFreeSessions"], "$.outcome.crashFreeSessions")
    sync_attempts = _integer(outcome["authoritativeSyncAttempts"], "$.outcome.authoritativeSyncAttempts")
    failed_syncs = _integer(
        outcome["failedNonCancelledSyncAttempts"],
        "$.outcome.failedNonCancelledSyncAttempts",
    )
    applicable = _integer(outcome["applicableMandatoryMilestones"], "$.outcome.applicableMandatoryMilestones")
    recorded = _integer(outcome["recordedMandatoryMilestones"], "$.outcome.recordedMandatoryMilestones")
    if crash_free > candidate_sessions:
        _fail("$.outcome.crashFreeSessions", "must not exceed candidateSessions")
    if failed_syncs > sync_attempts:
        _fail("$.outcome.failedNonCancelledSyncAttempts", "must not exceed authoritativeSyncAttempts")
    actual_applicable = next(
        (
            index
            for index, item in enumerate(milestones.values())
            if item["status"] == "NOT_REACHED"
        ),
        len(MILESTONES),
    )
    if applicable != actual_applicable:
        _fail(
            "$.outcome.applicableMandatoryMilestones",
            "must equal the milestone count before the first NOT_REACHED stage",
        )
    if recorded > applicable:
        _fail("$.outcome.recordedMandatoryMilestones", "must not exceed applicableMandatoryMilestones")
    actual_recorded = sum(item["status"] == "OBSERVED" for item in milestones.values())
    if recorded != actual_recorded:
        _fail("$.outcome.recordedMandatoryMilestones", "must equal the observed milestone count")

    comprehension = outcome["nextActionComprehension"]
    if comprehension not in {"CLEAR", "PARTIAL", "UNCLEAR", "DATA_GAP"}:
        _fail("$.outcome.nextActionComprehension", "has an unsupported code")
    comprehension_at = outcome["nextActionComprehensionAtUtc"]
    comprehension_elapsed = outcome["nextActionComprehensionElapsedSeconds"]
    if comprehension == "DATA_GAP":
        if comprehension_at is not None or comprehension_elapsed is not None:
            _fail(
                "$.outcome.nextActionComprehension",
                "DATA_GAP requires null comprehension timestamp and elapsed seconds",
            )
    else:
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
    for key in ("walkingAsAdventure", "companionReturn"):
        if outcome[key] not in {"YES", "PARTIAL", "NO", "DATA_GAP"}:
            _fail(f"$.outcome.{key}", "has an unsupported code")

    if (
        outcome["firstDayRewardStatus"] == "YES"
        and milestones["first_event_resolved"]["status"] != "OBSERVED"
    ):
        _fail(
            "$.outcome.firstDayRewardStatus",
            "YES requires an observed authoritative event resolution/reward receipt",
        )
    if outcome["completedUnaided"]:
        if stop_status != "NOT_INVOKED":
            _fail("$.outcome.completedUnaided", "cannot be true for a paused/stopped session")
        if any(item["status"] != "OBSERVED" for item in milestones.values()):
            _fail("$.outcome.completedUnaided", "requires every milestone to be observed")
        if any(item["helpRequested"] for item in milestones.values()):
            _fail("$.outcome.completedUnaided", "requires no facilitator help")
        if milestones["result_ack"]["elapsedSeconds"] > 600:
            _fail("$.outcome.completedUnaided", "requires result ACK within 600 seconds")
        if comprehension != "CLEAR":
            _fail("$.outcome.completedUnaided", "requires CLEAR next-action comprehension")
        if comprehension_elapsed > 600:
            _fail(
                "$.outcome.completedUnaided",
                "requires next-action comprehension within 600 seconds",
            )
        if outcome["firstDayRewardStatus"] != "YES":
            _fail("$.outcome.completedUnaided", "requires a confirmed first-day reward")


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
        if issue is not None:
            _integer(issue, f"{path}.issueNumber", positive=True)
        if severity in {"STOP", "FIX_BEFORE_EXPAND"} and issue is None:
            _fail(f"{path}.issueNumber", "STOP/FIX_BEFORE_EXPAND requires a linked issue")
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
        "studyCode", "platform", "startedAtUtc", "endedAtUtc", "moderatorRole",
        "consentConfirmed", "withdrawalRouteExplained", "exactCandidateVerified",
        "stopPauseStatus",
    ], "$.session")
    if not isinstance(root["milestones"], list) or len(root["milestones"]) != len(MILESTONES):
        _fail("$.milestones", f"must contain exactly {len(MILESTONES)} entries")
    for index, value in enumerate(root["milestones"]):
        _keys(value, [
            "milestoneId", "status", "observedAtUtc", "elapsedSeconds",
            "sourceCategory", "helpRequested", "gapReasonCode",
        ], f"$.milestones[{index}]")
    outcome = _keys(root["outcome"], [
        "completedUnaided", "permissionRequestShown", "permissionDecision",
        "firstDayRewardStatus", "candidateSessions", "crashFreeSessions",
        "authoritativeSyncAttempts", "failedNonCancelledSyncAttempts",
        "applicableMandatoryMilestones", "recordedMandatoryMilestones",
        "nextActionComprehension", "nextActionComprehensionAtUtc",
        "nextActionComprehensionElapsedSeconds", "walkingAsAdventure",
        "companionReturn",
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

    milestone_map = _validate_milestones(root["milestones"], started, ended)
    gap_reasons = {item["gapReasonCode"] for item in milestone_map.values()}
    if stop_status == "NOT_INVOKED" and "session_stopped" in gap_reasons:
        _fail("$.session.stopPauseStatus", "session_stopped gaps require PAUSED or STOPPED")
    if "participant_withdrew" in gap_reasons and stop_status != "STOPPED":
        _fail(
            "$.session.stopPauseStatus",
            "participant_withdrew gaps require STOPPED",
        )
    _validate_outcome(outcome, milestone_map, stop_status, started, ended)
    _validate_findings(root["findings"])

    if evidence["storageCategory"] not in STORAGE_CATEGORIES:
        _fail("$.evidence.storageCategory", f"must be one of {sorted(STORAGE_CATEGORIES)}")
    _matches(evidence["evidencePackageSha256"], DIGEST, "$.evidence.evidencePackageSha256", "a lowercase SHA-256")
    reviewed = _utc(evidence["redactionReviewedAtUtc"], "$.evidence.redactionReviewedAtUtc")
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


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("session", type=Path)
    parser.add_argument("--kickoff", type=Path)
    parser.add_argument("--require-recorded", action="store_true")
    args = parser.parse_args(argv)
    try:
        referenced_kickoff = None
        referenced_kickoff_sha256 = None
        if args.kickoff is not None:
            referenced_kickoff = kickoff_validator.load_kickoff(args.kickoff)
            referenced_kickoff_sha256 = hashlib.sha256(args.kickoff.read_bytes()).hexdigest()
        validate_session(
            load_session(args.session),
            require_recorded=args.require_recorded,
            referenced_kickoff=referenced_kickoff,
            referenced_kickoff_sha256=referenced_kickoff_sha256,
        )
    except (SessionValidationError, kickoff_validator.KickoffValidationError, OSError) as error:
        print(f"Internal-alpha session invalid: {error}", file=sys.stderr)
        return 1
    print(f"Internal-alpha session valid: {args.session}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
