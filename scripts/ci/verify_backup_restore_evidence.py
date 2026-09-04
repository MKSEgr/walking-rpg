#!/usr/bin/env python3
"""Fail-closed validator for protected PostgreSQL backup/restore evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import urllib.error
from datetime import datetime
from pathlib import Path
from typing import Any

import verify_stage_deployment_evidence as stage


SCHEMA = "walking-rpg-protected-backup-restore-v1"
TOP = {
    "schemaVersion", "recordStatus", "overallStatus", "recordedAtUtc",
    "source", "backup", "target", "drill", "controls", "cleanup",
    "approval",
}
SOURCE = {
    "repository", "commitSha", "treeSha", "image", "imageDigest",
    "stageEvidenceSha256", "stageEvidenceAttestationSha256",
}
BACKUP = {
    "status", "backupId", "archiveSha256", "createdAtUtc",
    "recoveryPointUtc", "retentionPolicyRef", "encryptionAtRest",
    "pitrEnabled",
}
TARGET = {
    "status", "targetId", "provider", "region", "isolatedFromProduction",
    "productionTrafficDisabled", "sourceUnchanged", "postgresVersion",
    "highestFlywayVersion",
}
DRILL = {
    "status", "startedAtUtc", "restoreCompletedAtUtc",
    "validationCompletedAtUtc", "cleanupCompletedAtUtc",
    "expectedRpoSeconds", "observedRpoSeconds", "expectedRtoSeconds",
    "observedRtoSeconds", "ownerRole", "nextActionDueAtUtc",
    "blockerCategory", "defectIssueNumbers",
}
CONTROLS = {
    "ownerApproved", "protectedSecretAccess", "noSensitiveEvidence",
    "archiveChecksumVerified", "backupEncrypted", "targetEmpty", "targetIsolated",
    "restoreExitZero", "flywayHistoryCurrent", "expectedSchemasPresent",
    "applicationTablesPresent", "rowCountControlsMatch",
    "invariantHashControlsMatch", "sequencesValid", "applicationReady",
    "smokeReadOnly", "roleAclValid", "pitrVerified", "sourceUnchanged",
    "noProductionTraffic", "rpoWithinTarget", "rtoWithinTarget",
}
CLEANUP = {
    "targetDisposition", "targetRetentionPolicyRef", "temporaryCredentialsRevoked",
    "temporaryArchiveCopiesRemoved", "secretExposureDetected",
    "evidenceContainsPersonalData",
}
APPROVAL = {"status", "operationsOwnerRole", "approvedAtUtc"}
RESULTS = {"PASS", "FAIL", "NOT_RUN"}
BLOCKERS = {
    "operations_owner_unassigned", "stage_evidence_unavailable",
    "stage_not_validated", "backup_unavailable",
    "restore_target_unavailable", "restore_failed", "validation_failed",
    "rpo_exceeded", "rto_exceeded", "cleanup_unconfirmed",
    "other_coarse",
}
PRE_RUN_BLOCKERS = {
    "operations_owner_unassigned", "stage_evidence_unavailable",
    "stage_not_validated", "backup_unavailable",
    "restore_target_unavailable", "other_coarse",
}
REPOSITORY = stage.REPOSITORY
IMAGE = stage.IMAGE
STAGE_WORKFLOW = stage.EVIDENCE_WORKFLOW
EVIDENCE_WORKFLOW = (
    "MKSEgr/walking-rpg/.github/workflows/"
    "protected-backup-restore-evidence.yml"
)
SHA = re.compile(r"^[0-9a-f]{40}$")
SHA256 = re.compile(r"^[0-9a-f]{64}$")
IMAGE_DIGEST = re.compile(r"^sha256:[0-9a-f]{64}$")
UUID = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
)
REFERENCE = re.compile(r"^[a-z0-9][a-z0-9._/-]{2,127}$")
UTC = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")


class BackupRestoreEvidenceError(ValueError):
    pass


def _fail(path: str, message: str) -> None:
    raise BackupRestoreEvidenceError(f"{path}: {message}")


def _object(value: Any, path: str, keys: set[str]) -> dict[str, Any]:
    if not isinstance(value, dict):
        _fail(path, "must be an object")
    missing = sorted(keys - value.keys())
    unknown = sorted(value.keys() - keys)
    if missing or unknown:
        _fail(path, f"keys mismatch; missing={missing}, unknown={unknown}")
    return value


def _unique(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise BackupRestoreEvidenceError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _decode_exact(raw: bytes, expected: Any, path: str) -> None:
    try:
        decoded = json.loads(raw, object_pairs_hook=_unique)
    except (UnicodeError, json.JSONDecodeError, BackupRestoreEvidenceError) as error:
        _fail(path, f"cannot decode exact JSON bytes: {error}")
    if decoded != expected:
        _fail(path, "supplied bytes must exactly represent the parsed record")


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


def _reference(value: Any, path: str) -> None:
    if (
        not isinstance(value, str)
        or not REFERENCE.fullmatch(value)
        or ".." in value
        or "//" in value
        or value.endswith(("/", ".", "-", "_"))
    ):
        _fail(path, "must be a bounded non-secret reference")


def _seconds(value: Any, path: str) -> int:
    if type(value) is not int or value < 1 or value > 31_536_000:
        _fail(path, "must be a strict bounded positive integer")
    return value


def _issues(value: Any, path: str) -> list[int]:
    if not isinstance(value, list) or len(value) > 50:
        _fail(path, "must be an array of at most 50 GitHub issue numbers")
    if any(type(item) is not int or item < 1 or item > 999_999_999 for item in value):
        _fail(path, "must contain bounded positive GitHub issue numbers")
    if len(value) != len(set(value)):
        _fail(path, "must not contain duplicate issue numbers")
    return value


def _highest_flyway(repository_root: Path) -> int:
    migrations = repository_root / "backend/src/main/resources/db/migration"
    versions = []
    for path in migrations.glob("V*__*.sql"):
        match = re.fullmatch(r"V([1-9][0-9]*)__.+\.sql", path.name)
        if match:
            versions.append(int(match.group(1)))
    if not versions:
        _fail("target.highestFlywayVersion", "repository has no Flyway migrations")
    return max(versions)


def _source_is_empty(source: dict[str, Any]) -> bool:
    return all(value is None for value in source.values())


def _has_restore_claims(controls: dict[str, Any]) -> bool:
    return any(value != "NOT_RUN" for value in controls.values())


def _validate_attested_stage(
    data: Any,
    raw: bytes,
    attestation: bytes,
    *,
    repository_root: Path,
    github_state: dict[str, Any] | None,
    attestation_verifier: Any,
) -> tuple[dict[str, Any], datetime]:
    _decode_exact(raw, data, "source.stageEvidence")
    root = _object(data, "source.stageEvidence", stage.TOP)
    if (
        root["schemaVersion"] != stage.SCHEMA
        or root["recordStatus"] != "RECORDED"
        or root["overallStatus"] != "VALIDATED"
    ):
        _fail("source.stageEvidence", "must be a RECORDED VALIDATED stage record")
    recorded_at = _time(root["recordedAtUtc"], "source.stageEvidence.recordedAtUtc")
    source = _object(root["source"], "source.stageEvidence.source", stage.SOURCE)
    stage_shape = _object(root["stage"], "source.stageEvidence.stage", stage.STAGE)
    deployment = _object(
        root["deployment"], "source.stageEvidence.deployment", stage.DEPLOYMENT
    )
    controls = _object(
        root["controls"], "source.stageEvidence.controls", stage.CONTROLS
    )
    cleanup = _object(root["cleanup"], "source.stageEvidence.cleanup", stage.CLEANUP)
    approval = _object(
        root["approval"], "source.stageEvidence.approval", stage.APPROVAL
    )
    if (
        source["repository"] != REPOSITORY
        or not isinstance(source["commitSha"], str)
        or not SHA.fullmatch(source["commitSha"])
        or not isinstance(source["treeSha"], str)
        or not SHA.fullmatch(source["treeSha"])
        or source["image"] != IMAGE
        or not isinstance(source["imageDigest"], str)
        or not IMAGE_DIGEST.fullmatch(source["imageDigest"])
    ):
        _fail("source.stageEvidence.source", "must identify the approved immutable source")
    if stage_shape != {
        "environment": "walking-rpg-alpha-eu",
        "provider": "digitalocean",
        "region": "fra",
        "publicEndpoint": stage_shape["publicEndpoint"],
        "backendComponent": "backend",
        "backendPlan": "apps-s-1vcpu-1gb",
        "backendInstances": 1,
        "postgresEngine": "17",
        "postgresPlan": "standard",
        "postgresNodes": 1,
    }:
        _fail("source.stageEvidence.stage", "must match the approved stage shape")
    try:
        stage._public_endpoint(
            stage_shape["publicEndpoint"], "source.stageEvidence.stage.publicEndpoint"
        )
    except stage.StageDeploymentEvidenceError as error:
        _fail("source.stageEvidence.stage.publicEndpoint", str(error))
    if (
        deployment["status"] != "VALIDATED"
        or deployment["deployedImageDigest"] != source["imageDigest"]
        or deployment["defectIssueNumbers"] != []
        or set(controls.values()) != {"PASS"}
        or cleanup != {
            "renderedSpecRemoved": True,
            "temporaryAccessRevoked": True,
            "secretExposureDetected": False,
            "personalDataRetained": False,
        }
        or approval["status"] != "APPROVED"
        or approval["releaseOwnerRole"] != "release_owner"
    ):
        _fail("source.stageEvidence", "validated stage outcomes are incomplete")

    verifier = attestation_verifier or (
        lambda repository, commit, subject, bundle: stage._attest(
            repository,
            commit,
            subject,
            bundle,
            STAGE_WORKFLOW,
            "source.stageEvidenceAttestation",
        )
    )
    verifier(REPOSITORY, source["commitSha"], raw, attestation)

    remote = stage.signed._git(repository_root, "remote", "get-url", "origin")
    if remote.removesuffix(".git") not in {
        "https://github.com/MKSEgr/walking-rpg",
        "git@github.com:MKSEgr/walking-rpg",
    }:
        _fail("source.repository", "origin must be the canonical repository")
    state = github_state or stage.signed._github_state(REPOSITORY, source["commitSha"])
    if source["commitSha"] != state.get("masterSha"):
        _fail("source.commitSha", "must equal GitHub's current master commit")
    if not {"CI", "Release quality"}.issubset(
        set(state.get("successfulWorkflows", []))
    ):
        _fail("source", "current source requires successful CI and Release quality")
    actual_tree = stage.signed._git(
        repository_root, "rev-parse", f'{source["commitSha"]}^{{tree}}'
    )
    if source["treeSha"] != actual_tree:
        _fail("source.treeSha", "must equal the actual source tree")
    return source, recorded_at


def validate(
    data: Any,
    *,
    require_recorded: bool = False,
    require_validated: bool = False,
    require_attestation: bool = True,
    stage_evidence: Any = None,
    stage_evidence_bytes: bytes | None = None,
    stage_evidence_attestation: bytes | None = None,
    evidence_bytes: bytes | None = None,
    evidence_attestation: bytes | None = None,
    repository_root: Path | None = None,
    github_state: dict[str, Any] | None = None,
    stage_attestation_verifier: Any = None,
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

    source = _object(root["source"], "source", SOURCE)
    backup = _object(root["backup"], "backup", BACKUP)
    target = _object(root["target"], "target", TARGET)
    drill = _object(root["drill"], "drill", DRILL)
    controls = _object(root["controls"], "controls", CONTROLS)
    cleanup = _object(root["cleanup"], "cleanup", CLEANUP)
    approval = _object(root["approval"], "approval", APPROVAL)

    if record == "TEMPLATE":
        expected_backup = {key: None for key in BACKUP}
        expected_backup["status"] = "OWNER_INPUT_REQUIRED"
        expected_target = {key: None for key in TARGET}
        expected_target["status"] = "OWNER_INPUT_REQUIRED"
        expected_drill = {key: None for key in DRILL}
        expected_drill["status"] = "OWNER_INPUT_REQUIRED"
        expected_drill["defectIssueNumbers"] = []
        if (
            overall != "OWNER_INPUT_REQUIRED"
            or root["recordedAtUtc"] is not None
            or not _source_is_empty(source)
            or backup != expected_backup
            or target != expected_target
            or drill != expected_drill
            or any(value is not None for value in controls.values())
            or any(value is not None for value in cleanup.values())
            or approval != {
                "status": "OWNER_INPUT_REQUIRED",
                "operationsOwnerRole": None,
                "approvedAtUtc": None,
            }
        ):
            _fail("$", "committed TEMPLATE must remain empty")
        return

    recorded_at = _time(root["recordedAtUtc"], "recordedAtUtc")
    if any(result not in RESULTS for result in controls.values()):
        _fail("controls", "values must be PASS, FAIL or NOT_RUN")
    has_claims = _has_restore_claims(controls)
    defects = _issues(drill["defectIssueNumbers"], "drill.defectIssueNumbers")
    source_empty = _source_is_empty(source)

    if not has_claims:
        empty_backup = {key: None for key in BACKUP}
        empty_backup["status"] = "NOT_RUN"
        empty_target = {key: None for key in TARGET}
        empty_target["status"] = "NOT_RUN"
        if not source_empty or any(
            value is not None
            for value in (
                stage_evidence, stage_evidence_bytes,
                stage_evidence_attestation, evidence_attestation,
            )
        ):
            _fail("source", "NOT_RUN evidence must not carry external evidence inputs")
        if backup != empty_backup or target != empty_target:
            _fail("$", "NOT_RUN evidence must not retain backup or target metadata")
        if any(
            drill[key] is not None
            for key in (
                "startedAtUtc", "restoreCompletedAtUtc",
                "validationCompletedAtUtc", "cleanupCompletedAtUtc",
                "expectedRpoSeconds", "observedRpoSeconds",
                "expectedRtoSeconds", "observedRtoSeconds",
            )
        ):
            _fail("drill", "NOT_RUN evidence must not retain drill measurements")
        if drill["status"] != "BLOCKED" or defects:
            _fail("drill", "NOT_RUN evidence must be a defect-free BLOCKED handoff")
        if drill["blockerCategory"] not in PRE_RUN_BLOCKERS:
            _fail("drill.blockerCategory", "must identify a pre-run blocker")
        expected_owner = (
            None
            if drill["blockerCategory"] == "operations_owner_unassigned"
            else "database_operations_owner"
        )
        if drill["ownerRole"] != expected_owner:
            _fail("drill.ownerRole", "must match the blocked owner assignment")
        due_at = _time(drill["nextActionDueAtUtc"], "drill.nextActionDueAtUtc")
        if due_at <= recorded_at:
            _fail("drill.nextActionDueAtUtc", "must be after recordedAtUtc")
        if cleanup != {
            "targetDisposition": "NOT_APPLICABLE",
            "targetRetentionPolicyRef": None,
            "temporaryCredentialsRevoked": True,
            "temporaryArchiveCopiesRemoved": True,
            "secretExposureDetected": False,
            "evidenceContainsPersonalData": False,
        }:
            _fail("cleanup", "NOT_RUN cleanup must be the exact safe shape")
        if approval != {
            "status": "BLOCKED",
            "operationsOwnerRole": None,
            "approvedAtUtc": None,
        } or overall != "BLOCKED":
            _fail("$", "NOT_RUN evidence cannot be approved or validated")
        return

    if source_empty:
        _fail("source", "restore claims require validated stage source")
    if (
        stage_evidence is None
        or stage_evidence_bytes is None
        or stage_evidence_attestation is None
    ):
        _fail("source", "restore claims require exact protected stage evidence")
    repo = repository_root or Path(__file__).resolve().parents[2]
    stage_source, stage_recorded_at = _validate_attested_stage(
        stage_evidence,
        stage_evidence_bytes,
        stage_evidence_attestation,
        repository_root=repo,
        github_state=github_state,
        attestation_verifier=stage_attestation_verifier,
    )
    expected_source = {
        "repository": REPOSITORY,
        "commitSha": stage_source["commitSha"],
        "treeSha": stage_source["treeSha"],
        "image": IMAGE,
        "imageDigest": stage_source["imageDigest"],
        "stageEvidenceSha256": hashlib.sha256(stage_evidence_bytes).hexdigest(),
        "stageEvidenceAttestationSha256": hashlib.sha256(
            stage_evidence_attestation
        ).hexdigest(),
    }
    if source != expected_source:
        _fail("source", "must exactly identify the protected stage evidence")

    if backup["status"] != "AVAILABLE":
        _fail("backup.status", "restore claims require an AVAILABLE backup")
    _reference(backup["backupId"], "backup.backupId")
    _digest(backup["archiveSha256"], "backup.archiveSha256")
    _reference(backup["retentionPolicyRef"], "backup.retentionPolicyRef")
    if type(backup["encryptionAtRest"]) is not bool or type(backup["pitrEnabled"]) is not bool:
        _fail("backup", "encryption and PITR values must be strict booleans")
    backup_created = _time(backup["createdAtUtc"], "backup.createdAtUtc")
    recovery_point = _time(backup["recoveryPointUtc"], "backup.recoveryPointUtc")

    if target["status"] not in {"RESTORED", "FAILED"}:
        _fail("target.status", "must be RESTORED or FAILED")
    if not isinstance(target["targetId"], str) or not UUID.fullmatch(target["targetId"]):
        _fail("target.targetId", "must be a lowercase provider UUID")
    if target["provider"] != "digitalocean" or target["region"] != "fra":
        _fail("target", "must identify the isolated DigitalOcean Frankfurt target")
    for key in (
        "isolatedFromProduction", "productionTrafficDisabled", "sourceUnchanged"
    ):
        if type(target[key]) is not bool:
            _fail(f"target.{key}", "must be a strict boolean")
    if target["postgresVersion"] != "17":
        _fail("target.postgresVersion", "must equal the approved PostgreSQL version")
    if type(target["highestFlywayVersion"]) is not int:
        _fail("target.highestFlywayVersion", "must be a strict integer")
    if target["highestFlywayVersion"] != _highest_flyway(repo):
        _fail("target.highestFlywayVersion", "must equal repository-current Flyway")

    started = _time(drill["startedAtUtc"], "drill.startedAtUtc")
    restored = _time(drill["restoreCompletedAtUtc"], "drill.restoreCompletedAtUtc")
    validated = _time(
        drill["validationCompletedAtUtc"], "drill.validationCompletedAtUtc"
    )
    cleaned = _time(drill["cleanupCompletedAtUtc"], "drill.cleanupCompletedAtUtc")
    if not (
        backup_created <= recovery_point <= started
        and stage_recorded_at <= started <= restored <= validated <= cleaned <= recorded_at
    ):
        _fail("drill", "backup, stage and drill timestamps must be fully ordered")
    expected_rpo = _seconds(drill["expectedRpoSeconds"], "drill.expectedRpoSeconds")
    observed_rpo = _seconds(drill["observedRpoSeconds"], "drill.observedRpoSeconds")
    expected_rto = _seconds(drill["expectedRtoSeconds"], "drill.expectedRtoSeconds")
    observed_rto = _seconds(drill["observedRtoSeconds"], "drill.observedRtoSeconds")
    measured_rpo = int((started - recovery_point).total_seconds())
    measured_rto = int((validated - started).total_seconds())
    if observed_rpo != measured_rpo:
        _fail("drill.observedRpoSeconds", "must equal the ordered timestamps")
    if observed_rto != measured_rto:
        _fail("drill.observedRtoSeconds", "must equal the ordered timestamps")
    expected_rpo_result = "PASS" if observed_rpo <= expected_rpo else "FAIL"
    expected_rto_result = "PASS" if observed_rto <= expected_rto else "FAIL"
    if controls["rpoWithinTarget"] != expected_rpo_result:
        _fail("controls.rpoWithinTarget", "must match the measured RPO")
    if controls["rtoWithinTarget"] != expected_rto_result:
        _fail("controls.rtoWithinTarget", "must match the measured RTO")
    expected_boolean_controls = {
        "targetIsolated": target["isolatedFromProduction"],
        "noProductionTraffic": target["productionTrafficDisabled"],
        "sourceUnchanged": target["sourceUnchanged"],
        "pitrVerified": backup["pitrEnabled"],
        "backupEncrypted": backup["encryptionAtRest"],
    }
    for key, passed in expected_boolean_controls.items():
        if controls[key] != ("PASS" if passed else "FAIL"):
            _fail(f"controls.{key}", "must match the recorded protected outcome")
    if controls["restoreExitZero"] != (
        "PASS" if target["status"] == "RESTORED" else "FAIL"
    ):
        _fail("controls.restoreExitZero", "must match target restore status")

    if any(
        type(value) is not bool
        for key, value in cleanup.items()
        if key not in {"targetDisposition", "targetRetentionPolicyRef"}
    ):
        _fail("cleanup", "cleanup outcomes must be strict booleans")
    if cleanup["targetDisposition"] not in {"DISPOSED", "RETAINED_BY_POLICY"}:
        _fail("cleanup.targetDisposition", "must record disposal or protected retention")
    if cleanup["targetDisposition"] == "DISPOSED":
        if cleanup["targetRetentionPolicyRef"] is not None:
            _fail("cleanup.targetRetentionPolicyRef", "must be null after disposal")
    else:
        _reference(
            cleanup["targetRetentionPolicyRef"],
            "cleanup.targetRetentionPolicyRef",
        )
    safe_cleanup = (
        cleanup["temporaryCredentialsRevoked"] is True
        and cleanup["temporaryArchiveCopiesRemoved"] is True
        and cleanup["secretExposureDetected"] is False
        and cleanup["evidenceContainsPersonalData"] is False
    )

    if drill["status"] == "VALIDATED":
        if set(controls.values()) != {"PASS"}:
            _fail("drill.status", "VALIDATED requires every control PASS")
        if not backup["encryptionAtRest"] or defects:
            _fail("drill", "VALIDATED requires encryption and no defects")
        if (
            drill["ownerRole"] != "database_operations_owner"
            or drill["nextActionDueAtUtc"] is not None
            or drill["blockerCategory"] is not None
        ):
            _fail("drill", "VALIDATED owner/blocker fields are inconsistent")
        drill_ready = True
    elif drill["status"] == "BLOCKED":
        if drill["blockerCategory"] not in BLOCKERS:
            _fail("drill.blockerCategory", "must identify an approved coarse blocker")
        expected_owner = (
            None
            if drill["blockerCategory"] == "operations_owner_unassigned"
            else "database_operations_owner"
        )
        if drill["ownerRole"] != expected_owner:
            _fail("drill.ownerRole", "must match the blocked owner assignment")
        due_at = _time(drill["nextActionDueAtUtc"], "drill.nextActionDueAtUtc")
        if due_at <= recorded_at:
            _fail("drill.nextActionDueAtUtc", "must be after recordedAtUtc")
        if set(controls.values()) == {"PASS"} and backup["encryptionAtRest"]:
            _fail("drill.status", "a fully passing drill cannot be BLOCKED")
        if "FAIL" in controls.values() and not defects:
            _fail("drill.defectIssueNumbers", "failed controls require a defect issue")
        drill_ready = False
    else:
        _fail("drill.status", "must be VALIDATED or BLOCKED")

    if (
        approval["status"] == "APPROVED"
        and approval["operationsOwnerRole"] == "operations_owner"
        and approval["approvedAtUtc"] is not None
    ):
        approved_at = _time(approval["approvedAtUtc"], "approval.approvedAtUtc")
        if approved_at < recorded_at:
            _fail("approval.approvedAtUtc", "must not precede recording")
        approval_ready = True
    elif approval == {
        "status": "BLOCKED",
        "operationsOwnerRole": None,
        "approvedAtUtc": None,
    }:
        approval_ready = False
    else:
        _fail("approval", "must be the exact APPROVED or BLOCKED shape")
    ready = drill_ready and safe_cleanup and approval_ready
    if approval_ready and not (drill_ready and safe_cleanup):
        _fail("approval", "APPROVED requires a validated drill and safe cleanup")
    if overall != ("VALIDATED" if ready else "BLOCKED"):
        _fail("overallStatus", "must match drill, cleanup and approval outcomes")

    if evidence_bytes is None:
        _fail("evidenceAttestation", "exact evidence bytes are required for restore claims")
    _decode_exact(evidence_bytes, data, "evidenceAttestation")
    if require_attestation:
        if evidence_attestation is None:
            _fail("evidenceAttestation", "protected attestation bundle is required")
        verifier = evidence_attestation_verifier or (
            lambda repository, commit, subject, bundle: stage._attest(
                repository,
                commit,
                subject,
                bundle,
                EVIDENCE_WORKFLOW,
                "evidenceAttestation",
            )
        )
        verifier(REPOSITORY, source["commitSha"], evidence_bytes, evidence_attestation)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence", type=Path)
    parser.add_argument("--stage-evidence", type=Path)
    parser.add_argument("--stage-evidence-attestation", type=Path)
    parser.add_argument("--evidence-attestation", type=Path)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--require-recorded", action="store_true")
    mode.add_argument("--require-validated", action="store_true")
    mode.add_argument("--prepare-attestation", action="store_true")
    args = parser.parse_args(argv)
    try:
        evidence_bytes = args.evidence.read_bytes()
        evidence = json.loads(evidence_bytes, object_pairs_hook=_unique)
        stage_bytes = args.stage_evidence.read_bytes() if args.stage_evidence else None
        stage_evidence = (
            json.loads(stage_bytes, object_pairs_hook=_unique)
            if stage_bytes is not None
            else None
        )
        stage_attestation = (
            args.stage_evidence_attestation.read_bytes()
            if args.stage_evidence_attestation
            else None
        )
        evidence_attestation = (
            args.evidence_attestation.read_bytes() if args.evidence_attestation else None
        )
        validate(
            evidence,
            require_recorded=args.require_recorded or args.prepare_attestation,
            require_validated=args.require_validated,
            require_attestation=not args.prepare_attestation,
            stage_evidence=stage_evidence,
            stage_evidence_bytes=stage_bytes,
            stage_evidence_attestation=stage_attestation,
            evidence_bytes=evidence_bytes,
            evidence_attestation=evidence_attestation,
        )
        if args.prepare_attestation and not _has_restore_claims(evidence["controls"]):
            _fail("evidenceAttestation", "there are no restore claims to attest")
    except (
        OSError,
        UnicodeError,
        json.JSONDecodeError,
        urllib.error.URLError,
        BackupRestoreEvidenceError,
        stage.StageDeploymentEvidenceError,
        stage.signed.SignedCandidateError,
    ) as error:
        print(f"Backup restore evidence invalid: {error}", file=sys.stderr)
        return 1
    if args.prepare_attestation:
        print(f"Backup restore evidence eligible for protected attestation: {args.evidence}")
    else:
        print(f"Backup restore evidence valid: {args.evidence}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
