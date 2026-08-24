#!/usr/bin/env python3
"""Fail-closed validator for the internal-alpha kickoff record."""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any


SCHEMA_VERSION = "walking-rpg-internal-alpha-kickoff-v1"
PROTOCOL_ID = "walking-rpg-internal-alpha-v1"
REDACTION_POLICY = "walking-rpg-evidence-redaction-v1"
OWNER = "MKSEgr"

TOP_LEVEL_KEYS = {
    "schemaVersion",
    "recordStatus",
    "recordedAtUtc",
    "approvedAtUtc",
    "protocol",
    "candidate",
    "owners",
    "observationWindow",
    "cohort",
    "evidence",
    "gates",
}
PROTOCOL_KEYS = {"protocolId", "commitSha"}
CANDIDATE_KEYS = {
    "sourceSha",
    "treeSha",
    "appVersion",
    "buildNumber",
    "ios",
    "android",
    "backend",
    "contentVersion",
    "remoteConfigVersion",
}
PLATFORM_KEYS = {"bundleId", "artifactSha256", "distributionTrack"}
ANDROID_KEYS = {"applicationId", "artifactSha256", "distributionTrack"}
BACKEND_KEYS = {
    "imageDigest",
    "deploymentReceiptSha256",
    "stageEnvironment",
}
OWNER_KEYS = {"productOwner", "releaseOwner", "cohortOwner", "supportOwner"}
WINDOW_KEYS = {"startsAtUtc", "endsAtUtc", "supportUntilUtc"}
COHORT_KEYS = {
    "plannedParticipants",
    "minimumIosParticipants",
    "minimumAndroidParticipants",
    "geography",
    "languages",
    "registrationDefaultLanguage",
}
EVIDENCE_KEYS = {
    "storageCategory",
    "redactionPolicy",
    "participantEvidenceDeleteByUtc",
    "supportChannelCategory",
}
GATE_KEYS = {
    "gateId",
    "status",
    "checkedAtUtc",
    "evidenceCategory",
    "evidenceDigestSha256",
}

GATE_ORDER = (
    "physical_activity",
    "identity_lifecycle",
    "protected_stage",
    "product_flow",
    "application_identity",
    "signed_candidate",
    "distribution",
    "operations",
    "research_safety",
    "observability",
)
STORAGE_CATEGORIES = {
    "approved_internal_evidence",
    "encrypted_project_storage",
    "approved_research_workspace",
}
SUPPORT_CATEGORIES = {"approved_private_channel"}

LOWER_SHA = re.compile(r"^[0-9a-f]{40}$")
SHA256 = re.compile(r"^[0-9a-f]{64}$")
IMAGE_DIGEST = re.compile(r"^sha256:[0-9a-f]{64}$")
UTC_TIMESTAMP = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
SEMVER = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?$")
BUILD_NUMBER = re.compile(r"^[1-9][0-9]{0,8}$")
APP_ID = re.compile(r"^[A-Za-z][A-Za-z0-9]*(?:\.[A-Za-z0-9_-]+){2,}$")
SAFE_VERSION = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")
SAFE_SLUG = re.compile(r"^[a-z][a-z0-9_-]{1,63}$")
SENSITIVE_WORD = re.compile(
    r"(?i)\b(?:token|secret|password|bearer|subject|serial|imei|"
    r"device\s+id|user\s+id|account\s+id|installation\s+id)\b"
)


class KickoffValidationError(ValueError):
    """Raised when kickoff content is unsafe or structurally invalid."""


def _fail(path: str, message: str) -> None:
    raise KickoffValidationError(f"{path}: {message}")


def _object(value: Any, path: str, keys: set[str]) -> dict[str, Any]:
    if not isinstance(value, dict):
        _fail(path, "must be an object")
    actual = set(value)
    if actual != keys:
        _fail(
            path,
            f"exact keys required; missing={sorted(keys - actual)}, "
            f"unknown={sorted(actual - keys)}",
        )
    return value


def _utc(value: Any, path: str) -> datetime:
    if not isinstance(value, str) or not UTC_TIMESTAMP.fullmatch(value):
        _fail(path, "must be RFC-3339 UTC with whole seconds")
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        _fail(path, f"invalid UTC timestamp: {error}")


def _matches(value: Any, path: str, pattern: re.Pattern[str], description: str) -> str:
    if not isinstance(value, str) or not pattern.fullmatch(value):
        _fail(path, f"must be {description}")
    return value


def _safe_version(value: Any, path: str) -> str:
    result = _matches(value, path, SAFE_VERSION, "a version token of at most 64 characters")
    normalized = re.sub(r"[_.-]+", " ", result)
    if SENSITIVE_WORD.search(normalized):
        _fail(path, "must not contain a credential or sensitive identifier field")
    return result


def _safe_slug(value: Any, path: str, description: str) -> str:
    result = _matches(value, path, SAFE_SLUG, description)
    if SENSITIVE_WORD.search(re.sub(r"[_-]+", " ", result)):
        _fail(path, "must not contain a credential or sensitive identifier field")
    return result


def _safe_app_id(value: Any, path: str, description: str) -> str:
    result = _matches(value, path, APP_ID, description)
    if SENSITIVE_WORD.search(re.sub(r"[._-]+", " ", result)):
        _fail(path, "must not contain a credential or sensitive identifier field")
    return result


def _template_nulls(value: dict[str, Any], path: str) -> None:
    for key, item in value.items():
        if item is not None:
            _fail(f"{path}.{key}", "must be null in the committed template")


def _validate_candidate(candidate: Any, record_status: str) -> None:
    data = _object(candidate, "candidate", CANDIDATE_KEYS)
    ios = _object(data["ios"], "candidate.ios", PLATFORM_KEYS)
    android = _object(data["android"], "candidate.android", ANDROID_KEYS)
    backend = _object(data["backend"], "candidate.backend", BACKEND_KEYS)
    if record_status == "TEMPLATE":
        scalar = {key: data[key] for key in CANDIDATE_KEYS - {"ios", "android", "backend"}}
        _template_nulls(scalar, "candidate")
        _template_nulls(ios, "candidate.ios")
        _template_nulls(android, "candidate.android")
        _template_nulls(backend, "candidate.backend")
        return

    _matches(data["sourceSha"], "candidate.sourceSha", LOWER_SHA, "a lowercase 40-hex SHA")
    _matches(data["treeSha"], "candidate.treeSha", LOWER_SHA, "a lowercase 40-hex SHA")
    _matches(data["appVersion"], "candidate.appVersion", SEMVER, "a semantic version")
    _matches(data["buildNumber"], "candidate.buildNumber", BUILD_NUMBER, "a positive build number")
    _safe_app_id(ios["bundleId"], "candidate.ios.bundleId", "a reverse-domain bundle ID")
    _safe_app_id(
        android["applicationId"],
        "candidate.android.applicationId",
        "a reverse-domain application ID",
    )
    for path, platform in (("candidate.ios", ios), ("candidate.android", android)):
        _matches(platform["artifactSha256"], f"{path}.artifactSha256", SHA256, "a lowercase SHA-256")
        _safe_slug(platform["distributionTrack"], f"{path}.distributionTrack", "a sanitized track slug")
    _matches(backend["imageDigest"], "candidate.backend.imageDigest", IMAGE_DIGEST, "a sha256 OCI digest")
    _matches(
        backend["deploymentReceiptSha256"],
        "candidate.backend.deploymentReceiptSha256",
        SHA256,
        "a lowercase SHA-256",
    )
    _safe_slug(
        backend["stageEnvironment"],
        "candidate.backend.stageEnvironment",
        "a sanitized stage slug",
    )
    _safe_version(data["contentVersion"], "candidate.contentVersion")
    _safe_version(data["remoteConfigVersion"], "candidate.remoteConfigVersion")


def _validate_fixed_contract(root: dict[str, Any]) -> None:
    protocol = _object(root["protocol"], "protocol", PROTOCOL_KEYS)
    if protocol["protocolId"] != PROTOCOL_ID:
        _fail("protocol.protocolId", f"must equal {PROTOCOL_ID!r}")
    owners = _object(root["owners"], "owners", OWNER_KEYS)
    for key, value in owners.items():
        if value != OWNER:
            _fail(f"owners.{key}", f"must equal the approved owner {OWNER!r}")
    cohort = _object(root["cohort"], "cohort", COHORT_KEYS)
    expected = {
        "plannedParticipants": 12,
        "minimumIosParticipants": 4,
        "minimumAndroidParticipants": 4,
        "geography": "RU",
        "languages": ["ru", "en"],
        "registrationDefaultLanguage": "ru",
    }
    for key, value in expected.items():
        if cohort[key] != value:
            _fail(f"cohort.{key}", f"must equal the approved value {value!r}")


def _validate_template(root: dict[str, Any]) -> None:
    for key in ("recordedAtUtc", "approvedAtUtc"):
        if root[key] is not None:
            _fail(key, "must be null in the committed template")
    protocol = root["protocol"]
    if protocol["commitSha"] is not None:
        _fail("protocol.commitSha", "must be null in the committed template")
    window = _object(root["observationWindow"], "observationWindow", WINDOW_KEYS)
    _template_nulls(window, "observationWindow")
    evidence = _object(root["evidence"], "evidence", EVIDENCE_KEYS)
    if evidence["redactionPolicy"] != REDACTION_POLICY:
        _fail("evidence.redactionPolicy", f"must equal {REDACTION_POLICY!r}")
    _template_nulls(
        {key: evidence[key] for key in EVIDENCE_KEYS - {"redactionPolicy"}},
        "evidence",
    )


def _validate_ready(root: dict[str, Any]) -> datetime:
    recorded = _utc(root["recordedAtUtc"], "recordedAtUtc")
    approved = _utc(root["approvedAtUtc"], "approvedAtUtc")
    if approved < recorded:
        _fail("approvedAtUtc", "must not precede recordedAtUtc")
    _matches(root["protocol"]["commitSha"], "protocol.commitSha", LOWER_SHA, "a lowercase 40-hex SHA")

    window = _object(root["observationWindow"], "observationWindow", WINDOW_KEYS)
    starts = _utc(window["startsAtUtc"], "observationWindow.startsAtUtc")
    ends = _utc(window["endsAtUtc"], "observationWindow.endsAtUtc")
    support_until = _utc(window["supportUntilUtc"], "observationWindow.supportUntilUtc")
    if not approved < starts < ends <= support_until:
        _fail("observationWindow", "must satisfy approved < starts < ends <= supportUntil")
    if support_until < ends + timedelta(hours=1):
        _fail("observationWindow.supportUntilUtc", "must cover at least one hour after the session window")

    evidence = _object(root["evidence"], "evidence", EVIDENCE_KEYS)
    if evidence["redactionPolicy"] != REDACTION_POLICY:
        _fail("evidence.redactionPolicy", f"must equal {REDACTION_POLICY!r}")
    if evidence["storageCategory"] not in STORAGE_CATEGORIES:
        _fail("evidence.storageCategory", f"must be one of {sorted(STORAGE_CATEGORIES)}")
    if evidence["supportChannelCategory"] not in SUPPORT_CATEGORIES:
        _fail("evidence.supportChannelCategory", "must identify an approved private channel category")
    delete_by = _utc(
        evidence["participantEvidenceDeleteByUtc"],
        "evidence.participantEvidenceDeleteByUtc",
    )
    if not ends < delete_by <= ends + timedelta(days=90):
        _fail("evidence.participantEvidenceDeleteByUtc", "must be after the window and no more than 90 days later")
    return approved


def _validate_gates(gates: Any, record_status: str, approved: datetime | None) -> None:
    if not isinstance(gates, list):
        _fail("gates", "must be an array")
    ids = [gate.get("gateId") if isinstance(gate, dict) else None for gate in gates]
    if ids != list(GATE_ORDER):
        _fail("gates", f"must contain every mandatory gate once in order {list(GATE_ORDER)}")
    for index, gate in enumerate(gates):
        path = f"gates[{index}]"
        data = _object(gate, path, GATE_KEYS)
        if record_status == "TEMPLATE":
            if data["status"] != "OWNER_INPUT_REQUIRED":
                _fail(f"{path}.status", "template gate must remain OWNER_INPUT_REQUIRED")
            for key in ("checkedAtUtc", "evidenceCategory", "evidenceDigestSha256"):
                if data[key] is not None:
                    _fail(f"{path}.{key}", "must be null in the committed template")
            continue
        if data["status"] != "PASS":
            _fail(f"{path}.status", "READY record requires PASS for every gate")
        checked = _utc(data["checkedAtUtc"], f"{path}.checkedAtUtc")
        if approved is not None and checked > approved:
            _fail(f"{path}.checkedAtUtc", "must not be later than owner approval")
        if data["evidenceCategory"] not in STORAGE_CATEGORIES:
            _fail(f"{path}.evidenceCategory", f"must be one of {sorted(STORAGE_CATEGORIES)}")
        _matches(
            data["evidenceDigestSha256"],
            f"{path}.evidenceDigestSha256",
            SHA256,
            "a lowercase SHA-256",
        )


def validate_kickoff(data: Any, *, require_ready: bool = False) -> None:
    root = _object(data, "$", TOP_LEVEL_KEYS)
    if root["schemaVersion"] != SCHEMA_VERSION:
        _fail("schemaVersion", f"must equal {SCHEMA_VERSION!r}")
    record_status = root["recordStatus"]
    if record_status not in {"TEMPLATE", "READY"}:
        _fail("recordStatus", "must be TEMPLATE or READY")
    if require_ready and record_status != "READY":
        _fail("recordStatus", "--require-ready rejects a template")

    _validate_fixed_contract(root)
    _validate_candidate(root["candidate"], record_status)
    if record_status == "TEMPLATE":
        _validate_template(root)
        approved = None
    else:
        approved = _validate_ready(root)
    _validate_gates(root["gates"], record_status, approved)


def _unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise KickoffValidationError(f"duplicate JSON object key: {key}")
        result[key] = value
    return result


def load_kickoff(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=_unique_object)
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise KickoffValidationError(f"cannot read strict UTF-8 JSON: {error}") from error


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("kickoff", type=Path)
    parser.add_argument(
        "--require-ready",
        action="store_true",
        help="reject TEMPLATE and require a fully approved READY record",
    )
    args = parser.parse_args(argv)
    try:
        validate_kickoff(load_kickoff(args.kickoff), require_ready=args.require_ready)
    except KickoffValidationError as error:
        print(f"Internal-alpha kickoff invalid: {error}", file=sys.stderr)
        return 1
    print(f"Internal-alpha kickoff valid: {args.kickoff}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
