#!/usr/bin/env python3
"""Fail-closed validator for physical internal-track validation evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

import verify_signed_candidate_evidence as signed


SCHEMA = "walking-rpg-internal-track-validation-v1"
TOP = {
    "schemaVersion", "recordStatus", "overallStatus", "recordedAtUtc",
    "candidate", "platforms", "cleanup", "approval",
}
CANDIDATE = {
    "repository", "signedCandidateEvidenceSha256",
    "signedCandidateEvidenceAttestationSha256", "candidateStatus",
    "sourceCommitSha", "sourceTreeSha",
}
PLATFORM = {
    "platform", "status", "applicationId", "artifactSha256", "version",
    "buildNumber", "distributionTrack", "deviceCategory", "osVersion",
    "previousVersion", "previousBuildNumber", "startedAtUtc",
    "completedAtUtc", "scenarioResults", "defectIssueNumbers", "ownerRole",
    "nextActionDueAtUtc", "blockerCategory",
}
SCENARIOS = {
    "cleanInstall", "upgrade", "launch", "authentication",
    "authoritativeHome", "migrationDataPreservation", "ownerIsolation",
    "trackVisibility", "testerAccess", "stopProcedure",
    "rollbackCommunication",
}
CLEANUP = {
    "localTestDataRemoved", "temporaryAccessRevoked",
    "secretExposureDetected", "personalDataRetained",
}
APPROVAL = {"status", "releaseOwnerRole", "approvedAtUtc"}
RESULTS = {"PASS", "FAIL", "NOT_RUN"}
BLOCKERS = {
    "candidate_not_ready", "device_owner_unassigned", "device_unavailable",
    "tester_access_unavailable", "track_visibility_failed",
    "clean_install_failed", "upgrade_failed", "launch_or_auth_failed",
    "migration_or_data_failed", "owner_isolation_failed",
    "stop_path_unconfirmed", "cleanup_unconfirmed", "other_coarse",
}
DEVICE_CATEGORIES = {"ios": "iphone_physical", "android": "android_physical"}
TRACKS = {"ios": "testflight_internal", "android": "play_internal"}
SHA = re.compile(r"^[0-9a-f]{40}$")
SHA256 = re.compile(r"^[0-9a-f]{64}$")
UTC = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
OS_VERSION = re.compile(r"^[0-9]{1,3}(?:\.[0-9]{1,3}){0,2}$")
VERSION = re.compile(r"^[0-9]+(?:\.[0-9]+){2}(?:[-+][0-9A-Za-z.-]+)?$")
BUILD = re.compile(r"^[1-9][0-9]{0,17}$")
ATTESTATION_WORKFLOW = (
    "MKSEgr/walking-rpg/.github/workflows/"
    "protected-internal-track-evidence.yml"
)


class InternalTrackEvidenceError(ValueError):
    pass


def _fail(path: str, message: str) -> None:
    raise InternalTrackEvidenceError(f"{path}: {message}")


def _object(value: Any, path: str, keys: set[str]) -> dict[str, Any]:
    if not isinstance(value, dict):
        _fail(path, "must be an object")
    missing = sorted(keys - value.keys())
    unknown = sorted(value.keys() - keys)
    if missing or unknown:
        _fail(path, f"keys mismatch; missing={missing}, unknown={unknown}")
    return value


def _time(value: Any, path: str) -> datetime:
    if not isinstance(value, str) or not UTC.fullmatch(value):
        _fail(path, "must be an exact UTC timestamp")
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        _fail(path, "must be a real UTC timestamp")


def _digest(value: Any, path: str) -> None:
    if (
        not isinstance(value, str)
        or not SHA256.fullmatch(value)
        or value == "0" * 64
    ):
        _fail(path, "must be a real lowercase SHA-256")


def _unique(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise InternalTrackEvidenceError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _decode_exact(raw: bytes, expected: Any, path: str) -> None:
    try:
        decoded = json.loads(raw, object_pairs_hook=_unique)
    except (UnicodeError, json.JSONDecodeError, InternalTrackEvidenceError) as error:
        _fail(path, f"cannot decode exact JSON bytes: {error}")
    if decoded != expected:
        _fail(path, "supplied bytes must exactly represent the parsed record")


def _verify_attestation(
    repository: str,
    commit: str,
    subject: bytes,
    bundle: bytes,
) -> None:
    import tempfile

    with tempfile.TemporaryDirectory() as directory:
        subject_path = Path(directory) / "internal-track-evidence.json"
        bundle_path = Path(directory) / "bundle.jsonl"
        subject_path.write_bytes(subject)
        bundle_path.write_bytes(bundle)
        result = subprocess.run(
            [
                "gh", "attestation", "verify", str(subject_path),
                "--repo", repository,
                "--bundle", str(bundle_path),
                "--signer-workflow", ATTESTATION_WORKFLOW,
                "--source-digest", commit,
            ],
            text=True,
            capture_output=True,
            check=False,
        )
        if result.returncode != 0:
            _fail("evidenceAttestation", "protected attestation verification failed")


def _issues(value: Any, path: str) -> list[int]:
    if not isinstance(value, list):
        _fail(path, "must be an array of GitHub issue numbers")
    if len(value) > 50:
        _fail(path, "must contain at most 50 issue numbers")
    if any(type(item) is not int or item < 1 or item > 999_999_999 for item in value):
        _fail(path, "must contain only bounded positive GitHub issue numbers")
    if len(value) != len(set(value)):
        _fail(path, "must not contain duplicate issue numbers")
    return value


def _has_run_claims(data: dict[str, Any]) -> bool:
    for platform in data.get("platforms", []):
        results = platform.get("scenarioResults") if isinstance(platform, dict) else None
        if isinstance(results, dict) and any(value != "NOT_RUN" for value in results.values()):
            return True
    return False


def validate(
    data: Any,
    *,
    require_recorded: bool = False,
    require_validated: bool = False,
    require_attestation: bool = True,
    signed_candidate: Any = None,
    signed_candidate_bytes: bytes | None = None,
    signed_candidate_attestation: bytes | None = None,
    account: Any = None,
    account_bytes: bytes | None = None,
    artifacts: dict[str, bytes] | None = None,
    artifact_receipts: dict[str, bytes] | None = None,
    evidence_bytes: bytes | None = None,
    evidence_attestation: bytes | None = None,
    repository_root: Path | None = None,
    candidate_validator: Any = None,
    evidence_attestation_verifier: Any = None,
) -> None:
    root = _object(data, "$", TOP)
    if root["schemaVersion"] != SCHEMA:
        _fail("schemaVersion", f"must equal {SCHEMA!r}")
    record = root["recordStatus"]
    overall = root["overallStatus"]
    if record not in {"TEMPLATE", "RECORDED"}:
        _fail("recordStatus", "must be TEMPLATE or RECORDED")
    if overall not in {"OWNER_INPUT_REQUIRED", "BLOCKED", "VALIDATED"}:
        _fail("overallStatus", "has an unsupported value")
    if require_recorded and record != "RECORDED":
        _fail("recordStatus", "recorded evidence is required")
    if require_validated and (record != "RECORDED" or overall != "VALIDATED"):
        _fail("overallStatus", "RECORDED VALIDATED evidence is required")

    candidate = _object(root["candidate"], "candidate", CANDIDATE)
    cleanup = _object(root["cleanup"], "cleanup", CLEANUP)
    approval = _object(root["approval"], "approval", APPROVAL)
    platforms = root["platforms"]
    if not isinstance(platforms, list):
        _fail("platforms", "must be an array")

    if record == "TEMPLATE":
        expected_candidate = {key: None for key in CANDIDATE}
        expected_approval = {
            "status": "OWNER_INPUT_REQUIRED",
            "releaseOwnerRole": None,
            "approvedAtUtc": None,
        }
        if (
            overall != "OWNER_INPUT_REQUIRED"
            or root["recordedAtUtc"] is not None
            or candidate != expected_candidate
            or platforms
            or any(value is not None for value in cleanup.values())
            or approval != expected_approval
        ):
            _fail("$", "committed TEMPLATE must remain empty")
        return

    recorded_at = _time(root["recordedAtUtc"], "recordedAtUtc")
    if signed_candidate is None or signed_candidate_bytes is None:
        _fail("candidate", "exact signed-candidate evidence bytes are required")
    _decode_exact(signed_candidate_bytes, signed_candidate, "candidate")
    candidate_sha = hashlib.sha256(signed_candidate_bytes).hexdigest()
    if candidate["signedCandidateEvidenceSha256"] != candidate_sha:
        _fail("candidate.signedCandidateEvidenceSha256", "must match supplied signed-candidate bytes")
    candidate_attestation_sha = (
        hashlib.sha256(signed_candidate_attestation).hexdigest()
        if signed_candidate_attestation is not None
        else None
    )
    if candidate["signedCandidateEvidenceAttestationSha256"] != candidate_attestation_sha:
        _fail(
            "candidate.signedCandidateEvidenceAttestationSha256",
            "must match the supplied signed-candidate attestation bundle",
        )

    if not isinstance(signed_candidate, dict):
        _fail("candidate", "signed-candidate evidence must be an object")
    signed_source = signed_candidate.get("source")
    signed_platforms = signed_candidate.get("platforms")
    if not isinstance(signed_source, dict) or not isinstance(signed_platforms, list):
        _fail("candidate", "signed-candidate evidence has no source/platform records")
    candidate_status = signed_candidate.get("overallStatus")
    if signed_candidate.get("recordStatus") != "RECORDED" or candidate_status not in {"READY", "BLOCKED"}:
        _fail("candidate", "signed-candidate evidence must be RECORDED READY or BLOCKED")
    if any(
        isinstance(item, dict) and item.get("status") == "READY"
        for item in signed_platforms
    ) and signed_candidate_attestation is None:
        _fail("candidate", "READY signed-candidate claims require their attestation bundle")
    if candidate != {
        "repository": signed_source.get("repository"),
        "signedCandidateEvidenceSha256": candidate_sha,
        "signedCandidateEvidenceAttestationSha256": candidate_attestation_sha,
        "candidateStatus": candidate_status,
        "sourceCommitSha": signed_source.get("commitSha"),
        "sourceTreeSha": signed_source.get("treeSha"),
    }:
        _fail("candidate", "must exactly identify the supplied signed-candidate record")
    if candidate["repository"] != "MKSEgr/walking-rpg":
        _fail("candidate.repository", "must identify the approved repository")
    if not isinstance(candidate["sourceCommitSha"], str) or not SHA.fullmatch(candidate["sourceCommitSha"]):
        _fail("candidate.sourceCommitSha", "must be a lowercase commit SHA")
    if not isinstance(candidate["sourceTreeSha"], str) or not SHA.fullmatch(candidate["sourceTreeSha"]):
        _fail("candidate.sourceTreeSha", "must be a lowercase tree SHA")

    validator = candidate_validator or signed.validate
    validator(
        signed_candidate,
        require_recorded=True,
        require_ready=candidate_status == "READY",
        account=account,
        account_sha256=(hashlib.sha256(account_bytes).hexdigest() if account_bytes else None),
        repository_root=repository_root,
        artifacts=artifacts,
        receipts=artifact_receipts,
        evidence_bytes=signed_candidate_bytes,
        evidence_receipt=signed_candidate_attestation,
    )

    if len(platforms) != 2:
        _fail("platforms", "must contain exactly iOS and Android")
    signed_by_platform: dict[str, dict[str, Any]] = {}
    for item in signed_platforms:
        if isinstance(item, dict) and item.get("platform") in {"ios", "android"}:
            signed_by_platform[item["platform"]] = item
    if set(signed_by_platform) != {"ios", "android"}:
        _fail("candidate.platforms", "must contain exactly iOS and Android")

    seen: set[str] = set()
    all_platforms_validated = True
    for index, raw in enumerate(platforms):
        path = f"platforms[{index}]"
        item = _object(raw, path, PLATFORM)
        platform = item["platform"]
        if platform not in {"ios", "android"} or platform in seen:
            _fail(f"{path}.platform", "must uniquely identify ios or android")
        seen.add(platform)
        signed_item = signed_by_platform[platform]
        expected_binding = {
            "applicationId": signed_item.get("applicationId"),
            "artifactSha256": signed_item.get("artifactSha256"),
            "version": signed_item.get("version"),
            "buildNumber": signed_item.get("buildNumber"),
            "distributionTrack": signed_item.get("distributionTrack"),
        }
        for key, expected in expected_binding.items():
            if item[key] != expected:
                _fail(f"{path}.{key}", "must match the signed-candidate platform")
        if signed_item.get("status") == "READY":
            _digest(item["artifactSha256"], f"{path}.artifactSha256")
            if item["distributionTrack"] != TRACKS[platform]:
                _fail(f"{path}.distributionTrack", "must match the exact internal track")
            if not isinstance(item["version"], str) or len(item["version"]) > 64 or not VERSION.fullmatch(item["version"]):
                _fail(f"{path}.version", "must use the safe candidate version format")
            if not isinstance(item["buildNumber"], str) or not BUILD.fullmatch(item["buildNumber"]):
                _fail(f"{path}.buildNumber", "must use the safe candidate build format")
        elif signed_item.get("status") == "BLOCKED":
            if any(item[key] is not None for key in ("artifactSha256", "version", "buildNumber", "distributionTrack")):
                _fail(path, "a BLOCKED candidate must not gain artifact metadata")
        else:
            _fail("candidate.platforms", "platform status must be READY or BLOCKED")

        results = _object(item["scenarioResults"], f"{path}.scenarioResults", SCENARIOS)
        if any(result not in RESULTS for result in results.values()):
            _fail(f"{path}.scenarioResults", "values must be PASS, FAIL or NOT_RUN")
        defects = _issues(item["defectIssueNumbers"], f"{path}.defectIssueNumbers")
        has_run = any(result != "NOT_RUN" for result in results.values())
        run_values = (
            item["deviceCategory"], item["osVersion"], item["startedAtUtc"],
            item["completedAtUtc"],
        )
        if has_run:
            if candidate_status != "READY" or signed_item.get("status") != "READY":
                _fail(path, "physical claims require a READY signed candidate")
            if item["deviceCategory"] != DEVICE_CATEGORIES[platform]:
                _fail(f"{path}.deviceCategory", "must use the approved coarse physical-device category")
            if not isinstance(item["osVersion"], str) or not OS_VERSION.fullmatch(item["osVersion"]):
                _fail(f"{path}.osVersion", "must be a bounded numeric OS version")
            started = _time(item["startedAtUtc"], f"{path}.startedAtUtc")
            completed = _time(item["completedAtUtc"], f"{path}.completedAtUtc")
            if completed < started or completed > recorded_at:
                _fail(path, "run times must be ordered and finish by recordedAtUtc")
        elif any(value is not None for value in run_values):
            _fail(path, "NOT_RUN evidence must not retain device or run metadata")

        if results["upgrade"] != "NOT_RUN":
            if not isinstance(item["previousVersion"], str) or len(item["previousVersion"]) > 64 or not VERSION.fullmatch(item["previousVersion"]):
                _fail(f"{path}.previousVersion", "must use the safe version format")
            if not isinstance(item["previousBuildNumber"], str) or not BUILD.fullmatch(item["previousBuildNumber"]):
                _fail(f"{path}.previousBuildNumber", "must use the safe build format")
            if int(item["previousBuildNumber"]) >= int(item["buildNumber"]):
                _fail(f"{path}.previousBuildNumber", "must precede the candidate build")
        elif item["previousVersion"] is not None or item["previousBuildNumber"] is not None:
            _fail(path, "an unrun upgrade must not retain a previous build tuple")

        if item["status"] == "VALIDATED":
            if candidate_status != "READY" or signed_item.get("status") != "READY" or set(results.values()) != {"PASS"}:
                _fail(path, "VALIDATED requires a READY candidate and every scenario PASS")
            if defects:
                _fail(f"{path}.defectIssueNumbers", "VALIDATED must not retain unresolved defects")
            if item["ownerRole"] != "release_validator" or item["nextActionDueAtUtc"] is not None or item["blockerCategory"] is not None:
                _fail(path, "VALIDATED owner/blocker fields are inconsistent")
        elif item["status"] == "BLOCKED":
            all_platforms_validated = False
            if item["blockerCategory"] not in BLOCKERS:
                _fail(f"{path}.blockerCategory", "must be an approved coarse blocker")
            expected_owner = None if item["blockerCategory"] == "device_owner_unassigned" else "release_validator"
            if item["ownerRole"] != expected_owner:
                _fail(f"{path}.ownerRole", "must match the blocked owner assignment")
            due_at = _time(item["nextActionDueAtUtc"], f"{path}.nextActionDueAtUtc")
            if due_at <= recorded_at:
                _fail(f"{path}.nextActionDueAtUtc", "must be after recordedAtUtc")
            if set(results.values()) == {"PASS"}:
                _fail(path, "a fully passing run cannot be marked BLOCKED")
            if signed_item.get("status") == "BLOCKED":
                if item["blockerCategory"] != "candidate_not_ready" or has_run:
                    _fail(path, "a BLOCKED candidate requires candidate_not_ready with no run claims")
            elif item["blockerCategory"] == "candidate_not_ready" and candidate_status != "BLOCKED":
                _fail(path, "candidate_not_ready cannot describe a READY candidate")
            if candidate_status == "BLOCKED" and (
                item["blockerCategory"] != "candidate_not_ready" or has_run
            ):
                _fail(path, "a BLOCKED candidate requires candidate_not_ready with no run claims")
            if not has_run and (defects or item["previousVersion"] is not None or item["previousBuildNumber"] is not None):
                _fail(path, "an unrun blocker must not retain defects or previous build metadata")
            if "FAIL" in results.values() and not defects:
                _fail(f"{path}.defectIssueNumbers", "failed scenarios require a defect issue")
        else:
            _fail(f"{path}.status", "must be VALIDATED or BLOCKED")

    if any(type(value) is not bool for value in cleanup.values()):
        _fail("cleanup", "recorded cleanup values must be strict booleans")
    safe_cleanup = cleanup == {
        "localTestDataRemoved": True,
        "temporaryAccessRevoked": True,
        "secretExposureDetected": False,
        "personalDataRetained": False,
    }
    if approval == {
        "status": "APPROVED",
        "releaseOwnerRole": "release_owner",
        "approvedAtUtc": approval["approvedAtUtc"],
    } and approval["approvedAtUtc"] is not None:
        approved_at = _time(approval["approvedAtUtc"], "approval.approvedAtUtc")
        if approved_at < recorded_at:
            _fail("approval.approvedAtUtc", "must not precede recording")
        approval_ready = True
    elif approval == {
        "status": "BLOCKED",
        "releaseOwnerRole": None,
        "approvedAtUtc": None,
    }:
        approval_ready = False
    else:
        _fail("approval", "must be the exact APPROVED or BLOCKED shape")

    ready = all_platforms_validated and safe_cleanup and approval_ready
    if approval_ready and not (all_platforms_validated and safe_cleanup):
        _fail("approval", "APPROVED requires both validated platforms and safe cleanup")
    if overall != ("VALIDATED" if ready else "BLOCKED"):
        _fail("overallStatus", "must match platform, cleanup and approval outcomes")

    if _has_run_claims(root):
        if evidence_bytes is None:
            _fail("evidenceAttestation", "exact recorded evidence bytes are required for run claims")
        _decode_exact(evidence_bytes, data, "evidenceAttestation")
        if require_attestation:
            if evidence_attestation is None:
                _fail("evidenceAttestation", "protected attestation bundle is required for run claims")
            verifier = evidence_attestation_verifier or _verify_attestation
            verifier(
                candidate["repository"],
                candidate["sourceCommitSha"],
                evidence_bytes,
                evidence_attestation,
            )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence", type=Path)
    parser.add_argument("--signed-candidate", type=Path)
    parser.add_argument("--signed-candidate-attestation", type=Path)
    parser.add_argument("--account-readiness", type=Path)
    parser.add_argument("--ios-artifact", type=Path)
    parser.add_argument("--android-artifact", type=Path)
    parser.add_argument("--ios-artifact-attestation", type=Path)
    parser.add_argument("--android-artifact-attestation", type=Path)
    parser.add_argument("--evidence-attestation", type=Path)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--require-recorded", action="store_true")
    mode.add_argument("--require-validated", action="store_true")
    mode.add_argument("--prepare-attestation", action="store_true")
    args = parser.parse_args(argv)
    try:
        evidence_bytes = args.evidence.read_bytes()
        evidence = json.loads(evidence_bytes, object_pairs_hook=_unique)
        candidate_bytes = args.signed_candidate.read_bytes() if args.signed_candidate else None
        candidate = (
            json.loads(candidate_bytes, object_pairs_hook=_unique)
            if candidate_bytes is not None
            else None
        )
        account_bytes = args.account_readiness.read_bytes() if args.account_readiness else None
        account = (
            json.loads(account_bytes, object_pairs_hook=_unique)
            if account_bytes is not None
            else None
        )
        candidate_attestation = (
            args.signed_candidate_attestation.read_bytes()
            if args.signed_candidate_attestation
            else None
        )
        artifacts = {
            platform: path.read_bytes()
            for platform, path in {
                "ios": args.ios_artifact,
                "android": args.android_artifact,
            }.items()
            if path
        }
        receipts = {
            platform: path.read_bytes()
            for platform, path in {
                "ios": args.ios_artifact_attestation,
                "android": args.android_artifact_attestation,
            }.items()
            if path
        }
        evidence_attestation = (
            args.evidence_attestation.read_bytes() if args.evidence_attestation else None
        )
        validate(
            evidence,
            require_recorded=args.require_recorded or args.prepare_attestation,
            require_validated=args.require_validated,
            require_attestation=not args.prepare_attestation,
            signed_candidate=candidate,
            signed_candidate_bytes=candidate_bytes,
            signed_candidate_attestation=candidate_attestation,
            account=account,
            account_bytes=account_bytes,
            artifacts=artifacts,
            artifact_receipts=receipts,
            evidence_bytes=evidence_bytes,
            evidence_attestation=evidence_attestation,
        )
        if args.prepare_attestation and not _has_run_claims(evidence):
            _fail("evidenceAttestation", "there are no external run claims to attest")
    except (
        OSError,
        UnicodeError,
        json.JSONDecodeError,
        InternalTrackEvidenceError,
        signed.SignedCandidateError,
    ) as error:
        print(f"Internal-track evidence invalid: {error}", file=sys.stderr)
        return 1
    if args.prepare_attestation:
        print(f"Internal-track evidence eligible for protected attestation: {args.evidence}")
    else:
        print(f"Internal-track evidence valid: {args.evidence}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
