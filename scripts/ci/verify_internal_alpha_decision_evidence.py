#!/usr/bin/env python3
"""Cross-check an internal-alpha decision against exact participant evidence."""

from __future__ import annotations

import argparse
import hashlib
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import verify_internal_alpha_decision as decision_validator
import verify_internal_alpha_kickoff as kickoff_validator
import verify_internal_alpha_session as session_validator


PACKAGE_DOMAIN = "walking-rpg-internal-alpha-evidence-v1"


class BundleValidationError(ValueError):
    pass


def _fail(path: str, message: str) -> None:
    raise BundleValidationError(f"{path}: {message}")


def _utc(value: str) -> datetime:
    return datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ").replace(
        tzinfo=timezone.utc
    )


def _read(path: Path) -> bytes:
    try:
        return path.read_bytes()
    except OSError as error:
        raise BundleValidationError(f"{path}: cannot read evidence ({error})") from error


def _load_sessions(
    session_paths: list[Path],
) -> list[tuple[str, Path, dict[str, Any], bytes]]:
    records: list[tuple[str, Path, dict[str, Any], bytes]] = []
    seen_codes: set[str] = set()
    for path in session_paths:
        try:
            document = session_validator.load_session(path)
        except session_validator.SessionValidationError as error:
            raise BundleValidationError(str(error)) from error
        if not isinstance(document, dict) or not isinstance(document.get("session"), dict):
            _fail(str(path), "must contain a session object")
        code = document["session"].get("studyCode")
        if not isinstance(code, str):
            _fail(str(path), "must contain a string study code")
        if code in seen_codes:
            _fail("sessions", f"duplicate study code {code!r}")
        seen_codes.add(code)
        records.append((code, path, document, _read(path)))
    return records


def _package_digest(
    kickoff_bytes: bytes,
    records: list[tuple[str, Path, dict[str, Any], bytes]],
) -> str:
    digest = hashlib.sha256()
    digest.update(f"{PACKAGE_DOMAIN}\n".encode())
    digest.update(f"kickoff:{hashlib.sha256(kickoff_bytes).hexdigest()}\n".encode())
    for code, _path, _document, raw in sorted(records, key=lambda item: item[0]):
        digest.update(f"session:{code}:{hashlib.sha256(raw).hexdigest()}\n".encode())
    return digest.hexdigest()


def evidence_package_sha256(kickoff_path: Path, session_paths: list[Path]) -> str:
    """Return the deterministic digest used by the decision record."""
    return _package_digest(_read(kickoff_path), _load_sessions(session_paths))


def _metric(status: str, numerator: int, denominator: int) -> tuple[str, int, int]:
    return status, numerator, denominator


def _derived_metrics(
    records: list[tuple[str, Path, dict[str, Any], bytes]],
) -> dict[str, tuple[str, int | None, int | None]]:
    sessions = [item[2] for item in records]
    if not sessions:
        return {
            name: ("DATA_GAP", None, None)
            for name in decision_validator.METRIC_NAMES
        }
    unaided = sum(item["outcome"]["completedUnaided"] for item in sessions)

    permission_shown = [
        item for item in sessions if item["outcome"]["permissionRequestShown"]
    ]
    permission_unknown = any(
        item["outcome"]["permissionDecision"] in {"DATA_GAP", "NOT_REACHED"}
        for item in permission_shown
    )
    if not permission_shown or permission_unknown:
        permission: tuple[str, int | None, int | None] = ("DATA_GAP", None, None)
    else:
        permission = _metric(
            "MEASURED",
            sum(
                item["outcome"]["permissionDecision"] == "GRANTED"
                for item in permission_shown
            ),
            len(permission_shown),
        )

    reward_statuses = [item["outcome"]["firstDayRewardStatus"] for item in sessions]
    if any(status in {"PENDING", "DATA_GAP"} for status in reward_statuses):
        reward: tuple[str, int | None, int | None] = ("DATA_GAP", None, None)
    else:
        reward = _metric(
            "MEASURED",
            sum(status == "YES" for status in reward_statuses),
            len(reward_statuses),
        )

    candidate_sessions = sum(
        item["outcome"]["candidateSessions"] for item in sessions
    )
    crash_free_sessions = sum(
        item["outcome"]["crashFreeSessions"] for item in sessions
    )
    sync_attempts = sum(
        item["outcome"]["authoritativeSyncAttempts"] for item in sessions
    )
    sync_failures = sum(
        item["outcome"]["failedNonCancelledSyncAttempts"] for item in sessions
    )
    instrumentation_participants = [
        item
        for item in sessions
        if item["outcome"]["applicableMandatoryMilestones"]
    ]
    sync = (
        _metric("MEASURED", sync_failures, sync_attempts)
        if sync_attempts
        else ("DATA_GAP", None, None)
    )
    instrumentation = (
        _metric(
            "MEASURED",
            sum(
                item["outcome"]["recordedMandatoryMilestones"]
                == item["outcome"]["applicableMandatoryMilestones"]
                for item in instrumentation_participants
            ),
            len(instrumentation_participants),
        )
        if instrumentation_participants
        else ("DATA_GAP", None, None)
    )
    return {
        "unaidedFirstTenMinutes": _metric("MEASURED", unaided, len(sessions)),
        "stepPermissionAcceptance": permission,
        "firstDayReward": reward,
        "crashFreeSessions": _metric(
            "MEASURED", crash_free_sessions, candidate_sessions
        ),
        "syncErrorRate": sync,
        "instrumentationCoverage": instrumentation,
    }


def _compare_metric(
    name: str,
    decision_metric: dict[str, Any],
    derived: tuple[str, int | None, int | None],
) -> None:
    status, numerator, denominator = derived
    if decision_metric["status"] != status:
        _fail(
            f"$.metrics.{name}.status",
            f"must be {status} for the supplied participant records",
        )
    if status == "MEASURED" and (
        decision_metric["numerator"], decision_metric["denominator"]
    ) != (numerator, denominator):
        _fail(
            f"$.metrics.{name}",
            f"must equal derived counts {numerator}/{denominator}",
        )


def _derived_finding_counts(sessions: list[dict[str, Any]]) -> dict[str, int]:
    severity_by_issue: dict[int, str] = {}
    for session in sessions:
        for finding in session["findings"]:
            issue = finding["issueNumber"]
            severity = finding["severity"]
            previous = severity_by_issue.setdefault(issue, severity)
            if previous != severity:
                _fail(
                    "$.findings",
                    f"issue {issue} has conflicting severities {previous} and {severity}",
                )
    names = {
        "STOP": "stopCount",
        "FIX_BEFORE_EXPAND": "fixBeforeExpandCount",
        "EXPERIMENT": "experimentCount",
        "LATER": "laterCount",
    }
    return {
        decision_name: sum(
            severity == session_severity
            for severity in severity_by_issue.values()
        )
        for session_severity, decision_name in names.items()
    }


def _completed(session: dict[str, Any]) -> bool:
    milestones = {
        item["milestoneId"]: item for item in session["milestones"]
    }
    return (
        milestones["result_ack"]["status"] == "OBSERVED"
        and session["outcome"]["nextActionComprehension"] != "DATA_GAP"
    )


def _validated_evidence(
    kickoff_path: Path,
    session_paths: list[Path],
) -> tuple[
    dict[str, Any],
    bytes,
    str,
    list[tuple[str, Path, dict[str, Any], bytes]],
]:
    try:
        kickoff = kickoff_validator.load_kickoff(kickoff_path)
        kickoff_validator.validate_kickoff(kickoff, require_ready=True)
    except kickoff_validator.KickoffValidationError as error:
        raise BundleValidationError(str(error)) from error

    kickoff_bytes = _read(kickoff_path)
    kickoff_sha = hashlib.sha256(kickoff_bytes).hexdigest()
    records = _load_sessions(session_paths)
    for code, path, session, _raw in records:
        try:
            session_validator.validate_session(
                session,
                require_recorded=True,
                referenced_kickoff=kickoff,
                referenced_kickoff_sha256=kickoff_sha,
            )
            session_validator._validate_session_filename(path, session)
        except (
            session_validator.SessionValidationError,
            kickoff_validator.KickoffValidationError,
        ) as error:
            raise BundleValidationError(f"{code}: {error}") from error
    return kickoff, kickoff_bytes, kickoff_sha, records


def validate_bundle(
    decision_path: Path,
    kickoff_path: Path,
    session_paths: list[Path],
) -> str:
    try:
        decision = decision_validator._load(decision_path)
        decision_validator.validate(decision, require_decided=True)
    except decision_validator.ContractError as error:
        raise BundleValidationError(str(error)) from error

    kickoff, kickoff_bytes, kickoff_sha, records = _validated_evidence(
        kickoff_path, session_paths
    )

    candidate = decision["candidate"]
    if decision["protocol"]["commitSha"] != kickoff["protocol"]["commitSha"]:
        _fail("$.protocol.commitSha", "must match the READY kickoff")
    for name in ("sourceSha", "treeSha"):
        if candidate[name] != kickoff["candidate"][name]:
            _fail(f"$.candidate.{name}", "must match the READY kickoff")
    if candidate["kickoffRecordSha256"] != kickoff_sha:
        _fail("$.candidate.kickoffRecordSha256", "must hash the exact kickoff bytes")

    package_sha = _package_digest(kickoff_bytes, records)
    if candidate["alphaEvidencePackageSha256"] != package_sha:
        _fail(
            "$.candidate.alphaEvidencePackageSha256",
            "must bind the exact kickoff and ordered participant-record digests",
        )

    sessions = [item[2] for item in records]
    evidence_dependent_rationales = {
        "threshold_miss",
        "focused_comprehension_gap",
        "core_value_not_supported",
    }
    if (
        not sessions
        and decision["decision"]["rationaleCode"] in evidence_dependent_rationales
    ):
        _fail(
            "$.decision.rationaleCode",
            "requires at least one participant-session record",
        )
    rationale = decision["decision"]["rationaleCode"]
    if rationale == "focused_comprehension_gap" and not any(
        item["outcome"]["nextActionComprehension"] in {"PARTIAL", "UNCLEAR"}
        for item in sessions
    ):
        _fail(
            "$.decision.rationaleCode",
            "requires a PARTIAL or UNCLEAR session comprehension outcome",
        )
    if rationale == "core_value_not_supported":
        walking_not_supported = (
            any(
                item["outcome"]["walkingAsAdventure"] == "NO"
                for item in sessions
            )
            and decision["qualitative"]["walkingAsAdventureSupported"] is False
        )
        companion_not_supported = (
            any(
                item["outcome"]["companionReturn"] == "NO"
                for item in sessions
            )
            and decision["qualitative"]["companionReturnSupported"] is False
        )
        if not walking_not_supported and not companion_not_supported:
            _fail(
                "$.decision.rationaleCode",
                "requires a negative signal matching its reviewed qualitative gate",
            )
    cohort = decision["cohort"]
    derived_cohort = {
        "started": len(sessions),
        "completed": sum(_completed(item) for item in sessions),
        "iosRealUsers": sum(item["session"]["platform"] == "ios" for item in sessions),
        "androidRealUsers": sum(
            item["session"]["platform"] == "android" for item in sessions
        ),
        "stoppedOrPaused": sum(
            item["session"]["stopPauseStatus"] != "NOT_INVOKED"
            for item in sessions
        ),
    }
    for name, expected in derived_cohort.items():
        if cohort[name] != expected:
            _fail(f"$.cohort.{name}", f"must equal derived count {expected}")

    session_withdrawals = sum(
        item["session"]["withdrawalStatus"] == "WITHDREW" for item in sessions
    )
    if cohort["withdrawn"] < session_withdrawals:
        _fail(
            "$.cohort.withdrawn",
            f"must include at least {session_withdrawals} session withdrawals",
        )

    for name, expected in _derived_finding_counts(sessions).items():
        if decision["findings"][name] < expected:
            _fail(
                f"$.findings.{name}",
                f"must include at least {expected} session-derived issues",
            )

    kickoff_approved = _utc(kickoff["approvedAtUtc"])
    if _utc(decision["recordedAtUtc"]) < kickoff_approved:
        _fail("$.recordedAtUtc", "must not precede READY kickoff approval")
    evidence_delete_by = _utc(
        kickoff["evidence"]["participantEvidenceDeleteByUtc"]
    )
    confirmation_at = _utc(decision["decision"]["confirmationAtUtc"])
    if confirmation_at >= evidence_delete_by:
        _fail(
            "$.decision.confirmationAtUtc",
            "must precede the participant-evidence deletion deadline",
        )
    if sessions:
        latest_session = max(_utc(item["recordedAtUtc"]) for item in sessions)
        if _utc(decision["recordedAtUtc"]) < latest_session:
            _fail("$.recordedAtUtc", "must not precede any participant record")

    derived_metrics = _derived_metrics(records)
    if decision["decision"]["rationaleCode"] == "threshold_miss":
        has_threshold_miss = any(
            status == "MEASURED"
            and numerator is not None
            and denominator is not None
            and not decision_validator._passes(name, numerator, denominator)
            for name, (status, numerator, denominator) in derived_metrics.items()
        )
        if not has_threshold_miss:
            _fail(
                "$.decision.rationaleCode",
                "threshold_miss requires a failed derived approved threshold",
            )

    for name, derived in derived_metrics.items():
        _compare_metric(name, decision["metrics"][name], derived)
    return package_sha


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("decision", nargs="?", type=Path)
    parser.add_argument("--kickoff", required=True, type=Path)
    parser.add_argument("--session", action="append", type=Path, default=[])
    parser.add_argument("--print-package-sha256", action="store_true")
    args = parser.parse_args(argv)
    try:
        if args.print_package_sha256:
            if args.decision is not None:
                parser.error("omit decision when using --print-package-sha256")
            _kickoff, kickoff_bytes, _kickoff_sha, records = _validated_evidence(
                args.kickoff, args.session
            )
            package_sha = _package_digest(kickoff_bytes, records)
            print(f"internal-alpha evidence package sha256: {package_sha}")
            return 0
        if args.decision is None:
            parser.error("decision is required unless --print-package-sha256 is used")
        package_sha = validate_bundle(args.decision, args.kickoff, args.session)
    except (BundleValidationError, OSError, ValueError) as error:
        print(f"internal-alpha decision evidence invalid: {error}", file=sys.stderr)
        return 1
    print(f"internal-alpha decision evidence valid: {package_sha}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
