#!/usr/bin/env python3
"""Fail-closed validator for protected stage incident/rollback evidence."""

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

import verify_backup_restore_evidence as restore


stage = restore.stage
SCHEMA = "walking-rpg-protected-incident-rollback-v1"
TOP = {
    "schemaVersion", "recordStatus", "overallStatus", "recordedAtUtc",
    "source", "rollback", "incident", "controls", "cleanup", "approval",
}
SOURCE = {
    "repository", "commitSha", "treeSha", "image", "imageDigest",
    "stageEvidenceSha256", "stageEvidenceAttestationSha256",
    "restoreEvidenceSha256", "restoreEvidenceAttestationSha256",
    "rollbackPublisherReceiptSha256",
    "rollbackPublisherReceiptAttestationSha256",
}
ROLLBACK = {
    "status", "beforeDeploymentId", "rollbackDeploymentId",
    "beforeSourceSha", "beforeTreeSha", "beforeImageDigest",
    "rollbackSourceSha", "rollbackTreeSha", "rollbackImageDigest",
}
INCIDENT = {
    "status", "incidentId", "scenario", "scope", "startedAtUtc",
    "detectedAtUtc", "acknowledgedAtUtc", "stopDecidedAtUtc",
    "rollbackStartedAtUtc", "rollbackCompletedAtUtc",
    "validationCompletedAtUtc", "expectedDetectionSeconds",
    "observedDetectionSeconds", "expectedRtoSeconds", "observedRtoSeconds",
    "incidentOwnerRole", "stopAuthorityRole", "nextActionDueAtUtc",
    "blockerCategory", "defectIssueNumbers",
}
CONTROLS = {
    "drillApproved", "controlledStageOnly", "failureInjectionBounded",
    "alertDelivered", "alertPayloadRedacted", "ownerAcknowledged",
    "stopAuthorityExercised", "rolloutStopped",
    "rollbackTargetPreverified", "schemaCompatible", "rollbackExitZero",
    "liveProbe", "readyProbe", "authentication", "homeRead",
    "activitySyncRead", "managementPrivate", "noProductionTraffic",
    "restoreFallbackAvailable", "communicationsRecorded", "followUpsFiled",
    "detectionWithinTarget", "rtoWithinTarget",
}
CLEANUP = {
    "failureInjectionRemoved", "riskyConfigDisabled",
    "temporaryAccessRevoked", "secretExposureDetected",
    "evidenceContainsPersonalData",
}
APPROVAL = {"status", "releaseOwnerRole", "approvedAtUtc"}
RESULTS = {"PASS", "FAIL", "NOT_RUN"}
SCENARIOS = {
    "backend_readiness_failure", "auth_dependency_failure",
    "config_regression", "content_activation_guard",
}
BLOCKERS = {
    "incident_owner_unassigned", "stage_evidence_unavailable",
    "restore_evidence_unavailable", "rollback_target_unavailable",
    "failure_injection_not_approved", "alert_failed", "rollback_failed",
    "validation_failed", "detection_target_missed", "rto_missed",
    "cleanup_unconfirmed", "other_coarse",
}
PRE_RUN_BLOCKERS = {
    "incident_owner_unassigned", "stage_evidence_unavailable",
    "restore_evidence_unavailable", "rollback_target_unavailable",
    "failure_injection_not_approved", "other_coarse",
}
REPOSITORY = stage.REPOSITORY
IMAGE = stage.IMAGE
PUBLISHER_WORKFLOW = stage.PUBLISHER_WORKFLOW
EVIDENCE_WORKFLOW = (
    "MKSEgr/walking-rpg/.github/workflows/"
    "protected-incident-rollback-evidence.yml"
)
SHA = re.compile(r"^[0-9a-f]{40}$")
SHA256 = re.compile(r"^[0-9a-f]{64}$")
IMAGE_DIGEST = re.compile(r"^sha256:[0-9a-f]{64}$")
UUID = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
)
REFERENCE = re.compile(r"^[a-z0-9][a-z0-9._/-]{2,127}$")
UTC = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")


class IncidentRollbackEvidenceError(ValueError):
    pass


def _fail(path: str, message: str) -> None:
    raise IncidentRollbackEvidenceError(f"{path}: {message}")


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
            raise IncidentRollbackEvidenceError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _decode_exact(raw: bytes, expected: Any, path: str) -> None:
    try:
        decoded = json.loads(raw, object_pairs_hook=_unique)
    except (UnicodeError, json.JSONDecodeError, IncidentRollbackEvidenceError) as error:
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


def _seconds(value: Any, path: str) -> int:
    if type(value) is not int or value < 1 or value > 604_800:
        _fail(path, "must be a strict bounded positive integer")
    return value


def _reference(value: Any, path: str) -> None:
    if (
        not isinstance(value, str)
        or not REFERENCE.fullmatch(value)
        or ".." in value
        or "//" in value
        or value.endswith(("/", ".", "-", "_"))
    ):
        _fail(path, "must be a bounded non-secret reference")


def _issues(value: Any, path: str) -> list[int]:
    if not isinstance(value, list) or len(value) > 50:
        _fail(path, "must be an array of at most 50 GitHub issue numbers")
    if any(type(item) is not int or item < 1 or item > 999_999_999 for item in value):
        _fail(path, "must contain bounded positive GitHub issue numbers")
    if len(value) != len(set(value)):
        _fail(path, "must not contain duplicate issue numbers")
    return value


def _source_is_empty(source: dict[str, Any]) -> bool:
    return all(value is None for value in source.values())


def _has_incident_claims(controls: dict[str, Any]) -> bool:
    return any(value != "NOT_RUN" for value in controls.values())


def _validate_rollback_receipt(
    receipt: Any,
    raw: bytes,
    attestation: bytes,
    *,
    repository_root: Path,
    attestation_verifier: Any,
) -> tuple[dict[str, Any], datetime]:
    _decode_exact(raw, receipt, "source.rollbackPublisherReceipt")
    value = _object(
        receipt,
        "source.rollbackPublisherReceipt",
        stage.PUBLISHER_RECEIPT,
    )
    if value["schemaVersion"] != "walking-rpg-backend-image-receipt-v1":
        _fail("source.rollbackPublisherReceipt.schemaVersion", "is unsupported")
    if value["image"] != IMAGE or value["platform"] != "linux/amd64":
        _fail("source.rollbackPublisherReceipt", "must identify the approved backend image")
    if not isinstance(value["sourceGitSha"], str) or not SHA.fullmatch(value["sourceGitSha"]):
        _fail("source.rollbackPublisherReceipt.sourceGitSha", "must be a lowercase commit SHA")
    if not isinstance(value["sourceGitTree"], str) or not SHA.fullmatch(value["sourceGitTree"]):
        _fail("source.rollbackPublisherReceipt.sourceGitTree", "must be a lowercase tree SHA")
    if value["provenanceGuardBaselineSha"] != stage.PROVENANCE_BASELINE:
        _fail("source.rollbackPublisherReceipt", "must use the approved provenance baseline")
    if (
        not isinstance(value["digest"], str)
        or not IMAGE_DIGEST.fullmatch(value["digest"])
        or value["digest"] == "sha256:" + "0" * 64
    ):
        _fail("source.rollbackPublisherReceipt.digest", "must be an immutable image digest")
    if not isinstance(value["workflowRun"], str) or not stage.WORKFLOW_RUN.fullmatch(value["workflowRun"]):
        _fail("source.rollbackPublisherReceipt.workflowRun", "must identify the publisher run")
    published_at = _time(
        value["publishedAt"], "source.rollbackPublisherReceipt.publishedAt"
    )
    verifier = attestation_verifier or (
        lambda repository, commit, subject, bundle: stage._attest(
            repository,
            commit,
            subject,
            bundle,
            PUBLISHER_WORKFLOW,
            "source.rollbackPublisherReceiptAttestation",
        )
    )
    verifier(REPOSITORY, value["sourceGitSha"], raw, attestation)
    actual_tree = stage.signed._git(
        repository_root, "rev-parse", f'{value["sourceGitSha"]}^{{tree}}'
    )
    if value["sourceGitTree"] != actual_tree:
        _fail("source.rollbackPublisherReceipt.sourceGitTree", "must equal the actual source tree")
    return value, published_at


def validate(
    data: Any,
    *,
    require_recorded: bool = False,
    require_validated: bool = False,
    require_attestation: bool = True,
    stage_evidence: Any = None,
    stage_evidence_bytes: bytes | None = None,
    stage_evidence_attestation: bytes | None = None,
    restore_evidence: Any = None,
    restore_evidence_bytes: bytes | None = None,
    restore_evidence_attestation: bytes | None = None,
    rollback_receipt: Any = None,
    rollback_receipt_bytes: bytes | None = None,
    rollback_receipt_attestation: bytes | None = None,
    evidence_bytes: bytes | None = None,
    evidence_attestation: bytes | None = None,
    repository_root: Path | None = None,
    github_state: dict[str, Any] | None = None,
    stage_attestation_verifier: Any = None,
    restore_attestation_verifier: Any = None,
    rollback_receipt_attestation_verifier: Any = None,
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
    rollback = _object(root["rollback"], "rollback", ROLLBACK)
    incident = _object(root["incident"], "incident", INCIDENT)
    controls = _object(root["controls"], "controls", CONTROLS)
    cleanup = _object(root["cleanup"], "cleanup", CLEANUP)
    approval = _object(root["approval"], "approval", APPROVAL)

    if record == "TEMPLATE":
        expected_rollback = {key: None for key in ROLLBACK}
        expected_rollback["status"] = "OWNER_INPUT_REQUIRED"
        expected_incident = {key: None for key in INCIDENT}
        expected_incident["status"] = "OWNER_INPUT_REQUIRED"
        expected_incident["defectIssueNumbers"] = []
        if (
            overall != "OWNER_INPUT_REQUIRED"
            or root["recordedAtUtc"] is not None
            or not _source_is_empty(source)
            or rollback != expected_rollback
            or incident != expected_incident
            or any(value is not None for value in controls.values())
            or any(value is not None for value in cleanup.values())
            or approval != {
                "status": "OWNER_INPUT_REQUIRED",
                "releaseOwnerRole": None,
                "approvedAtUtc": None,
            }
        ):
            _fail("$", "committed TEMPLATE must remain empty")
        return

    recorded_at = _time(root["recordedAtUtc"], "recordedAtUtc")
    if any(result not in RESULTS for result in controls.values()):
        _fail("controls", "values must be PASS, FAIL or NOT_RUN")
    has_claims = _has_incident_claims(controls)
    defects = _issues(incident["defectIssueNumbers"], "incident.defectIssueNumbers")

    if not has_claims:
        empty_rollback = {key: None for key in ROLLBACK}
        empty_rollback["status"] = "NOT_RUN"
        external_inputs = (
            stage_evidence, stage_evidence_bytes, stage_evidence_attestation,
            restore_evidence, restore_evidence_bytes,
            restore_evidence_attestation, rollback_receipt,
            rollback_receipt_bytes, rollback_receipt_attestation,
            evidence_attestation,
        )
        if not _source_is_empty(source) or any(value is not None for value in external_inputs):
            _fail("source", "NOT_RUN evidence must not carry external evidence inputs")
        if rollback != empty_rollback:
            _fail("rollback", "NOT_RUN evidence must not retain deployment metadata")
        measured_fields = {
            "incidentId", "scenario", "scope", "startedAtUtc", "detectedAtUtc",
            "acknowledgedAtUtc", "stopDecidedAtUtc", "rollbackStartedAtUtc",
            "rollbackCompletedAtUtc", "validationCompletedAtUtc",
            "expectedDetectionSeconds", "observedDetectionSeconds",
            "expectedRtoSeconds", "observedRtoSeconds",
        }
        if any(incident[key] is not None for key in measured_fields):
            _fail("incident", "NOT_RUN evidence must not retain incident measurements")
        if incident["status"] != "BLOCKED" or defects:
            _fail("incident", "NOT_RUN evidence must be a defect-free BLOCKED handoff")
        if incident["blockerCategory"] not in PRE_RUN_BLOCKERS:
            _fail("incident.blockerCategory", "must identify a pre-run blocker")
        owner = (
            None
            if incident["blockerCategory"] == "incident_owner_unassigned"
            else "incident_owner"
        )
        if incident["incidentOwnerRole"] != owner or incident["stopAuthorityRole"] is not None:
            _fail("incident", "NOT_RUN owner roles must match the blocker")
        due_at = _time(incident["nextActionDueAtUtc"], "incident.nextActionDueAtUtc")
        if due_at <= recorded_at:
            _fail("incident.nextActionDueAtUtc", "must be after recordedAtUtc")
        if cleanup != {
            "failureInjectionRemoved": True,
            "riskyConfigDisabled": True,
            "temporaryAccessRevoked": True,
            "secretExposureDetected": False,
            "evidenceContainsPersonalData": False,
        }:
            _fail("cleanup", "NOT_RUN cleanup must be the exact safe shape")
        if approval != {
            "status": "BLOCKED",
            "releaseOwnerRole": None,
            "approvedAtUtc": None,
        } or overall != "BLOCKED":
            _fail("$", "NOT_RUN evidence cannot be approved or validated")
        return

    required_inputs = (
        stage_evidence, stage_evidence_bytes, stage_evidence_attestation,
        restore_evidence, restore_evidence_bytes,
        restore_evidence_attestation, rollback_receipt,
        rollback_receipt_bytes, rollback_receipt_attestation,
    )
    if _source_is_empty(source) or any(value is None for value in required_inputs):
        _fail("source", "incident claims require the full protected provenance chain")
    repo = repository_root or Path(__file__).resolve().parents[2]
    restore.validate(
        restore_evidence,
        require_recorded=True,
        require_validated=True,
        stage_evidence=stage_evidence,
        stage_evidence_bytes=stage_evidence_bytes,
        stage_evidence_attestation=stage_evidence_attestation,
        evidence_bytes=restore_evidence_bytes,
        evidence_attestation=restore_evidence_attestation,
        repository_root=repo,
        github_state=github_state,
        stage_attestation_verifier=stage_attestation_verifier,
        evidence_attestation_verifier=restore_attestation_verifier,
    )
    receipt, receipt_published_at = _validate_rollback_receipt(
        rollback_receipt,
        rollback_receipt_bytes,
        rollback_receipt_attestation,
        repository_root=repo,
        attestation_verifier=rollback_receipt_attestation_verifier,
    )
    stage_source = _object(stage_evidence["source"], "source.stage", stage.SOURCE)
    stage_deployment = _object(
        stage_evidence["deployment"], "source.stage.deployment", stage.DEPLOYMENT
    )
    restore_source = _object(
        restore_evidence["source"], "source.restore", restore.SOURCE
    )
    if restore_source["stageEvidenceSha256"] != hashlib.sha256(stage_evidence_bytes).hexdigest():
        _fail("source.restoreEvidence", "must bind the supplied stage bytes")
    if restore_source["stageEvidenceAttestationSha256"] != hashlib.sha256(stage_evidence_attestation).hexdigest():
        _fail("source.restoreEvidence", "must bind the supplied stage attestation")
    expected_source = {
        "repository": REPOSITORY,
        "commitSha": stage_source["commitSha"],
        "treeSha": stage_source["treeSha"],
        "image": IMAGE,
        "imageDigest": stage_source["imageDigest"],
        "stageEvidenceSha256": hashlib.sha256(stage_evidence_bytes).hexdigest(),
        "stageEvidenceAttestationSha256": hashlib.sha256(stage_evidence_attestation).hexdigest(),
        "restoreEvidenceSha256": hashlib.sha256(restore_evidence_bytes).hexdigest(),
        "restoreEvidenceAttestationSha256": hashlib.sha256(restore_evidence_attestation).hexdigest(),
        "rollbackPublisherReceiptSha256": hashlib.sha256(rollback_receipt_bytes).hexdigest(),
        "rollbackPublisherReceiptAttestationSha256": hashlib.sha256(rollback_receipt_attestation).hexdigest(),
    }
    if source != expected_source:
        _fail("source", "must exactly identify the protected provenance chain")

    expected_rollback = {
        "status": rollback["status"],
        "beforeDeploymentId": stage_deployment["deploymentId"],
        "rollbackDeploymentId": stage_deployment["previousSafeDeploymentId"],
        "beforeSourceSha": stage_source["commitSha"],
        "beforeTreeSha": stage_source["treeSha"],
        "beforeImageDigest": stage_source["imageDigest"],
        "rollbackSourceSha": receipt["sourceGitSha"],
        "rollbackTreeSha": receipt["sourceGitTree"],
        "rollbackImageDigest": receipt["digest"],
    }
    if rollback != expected_rollback:
        _fail("rollback", "must exactly bind current and previous deployments")
    if rollback["status"] not in {"COMPLETED", "FAILED"}:
        _fail("rollback.status", "must be COMPLETED or FAILED")
    for key in ("beforeDeploymentId", "rollbackDeploymentId"):
        if not isinstance(rollback[key], str) or not UUID.fullmatch(rollback[key]):
            _fail(f"rollback.{key}", "must be a lowercase provider UUID")
    if (
        rollback["beforeDeploymentId"] == rollback["rollbackDeploymentId"]
        or rollback["beforeSourceSha"] == rollback["rollbackSourceSha"]
        or rollback["beforeImageDigest"] == rollback["rollbackImageDigest"]
    ):
        _fail("rollback", "previous deployment, source and image must differ")

    _reference(incident["incidentId"], "incident.incidentId")
    if incident["scenario"] not in SCENARIOS or incident["scope"] != "CONTROLLED_STAGE":
        _fail("incident", "must identify an approved controlled-stage scenario")
    started = _time(incident["startedAtUtc"], "incident.startedAtUtc")
    detected = _time(incident["detectedAtUtc"], "incident.detectedAtUtc")
    acknowledged = _time(incident["acknowledgedAtUtc"], "incident.acknowledgedAtUtc")
    stopped = _time(incident["stopDecidedAtUtc"], "incident.stopDecidedAtUtc")
    rollback_started = _time(incident["rollbackStartedAtUtc"], "incident.rollbackStartedAtUtc")
    rollback_completed = _time(incident["rollbackCompletedAtUtc"], "incident.rollbackCompletedAtUtc")
    validated = _time(incident["validationCompletedAtUtc"], "incident.validationCompletedAtUtc")
    restore_recorded_at = _time(
        restore_evidence["recordedAtUtc"], "source.restore.recordedAtUtc"
    )
    stage_approved_at = _time(
        stage_evidence["approval"]["approvedAtUtc"],
        "source.stage.approval.approvedAtUtc",
    )
    restore_approved_at = _time(
        restore_evidence["approval"]["approvedAtUtc"],
        "source.restore.approval.approvedAtUtc",
    )
    if not (
        restore_recorded_at <= started
        and stage_approved_at <= started
        and restore_approved_at <= started
        and receipt_published_at <= started
        and started <= detected <= acknowledged <= stopped
        <= rollback_started <= rollback_completed <= validated <= recorded_at
    ):
        _fail("incident", "provenance and incident timestamps must be fully ordered")
    expected_detection = _seconds(
        incident["expectedDetectionSeconds"], "incident.expectedDetectionSeconds"
    )
    observed_detection = _seconds(
        incident["observedDetectionSeconds"], "incident.observedDetectionSeconds"
    )
    expected_rto = _seconds(incident["expectedRtoSeconds"], "incident.expectedRtoSeconds")
    observed_rto = _seconds(incident["observedRtoSeconds"], "incident.observedRtoSeconds")
    if observed_detection != int((detected - started).total_seconds()):
        _fail("incident.observedDetectionSeconds", "must equal the ordered timestamps")
    if observed_rto != int((validated - started).total_seconds()):
        _fail("incident.observedRtoSeconds", "must equal the ordered timestamps")
    expected_detection_result = "PASS" if observed_detection <= expected_detection else "FAIL"
    expected_rto_result = "PASS" if observed_rto <= expected_rto else "FAIL"
    if controls["detectionWithinTarget"] != expected_detection_result:
        _fail("controls.detectionWithinTarget", "must match measured detection time")
    if controls["rtoWithinTarget"] != expected_rto_result:
        _fail("controls.rtoWithinTarget", "must match measured RTO")
    if controls["rollbackExitZero"] != (
        "PASS" if rollback["status"] == "COMPLETED" else "FAIL"
    ):
        _fail("controls.rollbackExitZero", "must match rollback status")
    if controls["controlledStageOnly"] != "PASS" or controls["restoreFallbackAvailable"] != "PASS":
        _fail("controls", "must confirm controlled scope and validated restore fallback")

    if any(type(value) is not bool for value in cleanup.values()):
        _fail("cleanup", "cleanup outcomes must be strict booleans")
    safe_cleanup = cleanup == {
        "failureInjectionRemoved": True,
        "riskyConfigDisabled": True,
        "temporaryAccessRevoked": True,
        "secretExposureDetected": False,
        "evidenceContainsPersonalData": False,
    }
    if incident["status"] == "VALIDATED":
        if set(controls.values()) != {"PASS"} or defects:
            _fail("incident.status", "VALIDATED requires all controls PASS and no defects")
        if (
            incident["incidentOwnerRole"] != "incident_owner"
            or incident["stopAuthorityRole"] != "release_owner"
            or incident["nextActionDueAtUtc"] is not None
            or incident["blockerCategory"] is not None
        ):
            _fail("incident", "VALIDATED owner/blocker fields are inconsistent")
        incident_ready = True
    elif incident["status"] == "BLOCKED":
        if incident["blockerCategory"] not in BLOCKERS:
            _fail("incident.blockerCategory", "must identify an approved coarse blocker")
        owner = (
            None
            if incident["blockerCategory"] == "incident_owner_unassigned"
            else "incident_owner"
        )
        if incident["incidentOwnerRole"] != owner or incident["stopAuthorityRole"] != "release_owner":
            _fail("incident", "BLOCKED owner roles are inconsistent")
        due_at = _time(incident["nextActionDueAtUtc"], "incident.nextActionDueAtUtc")
        if due_at <= recorded_at:
            _fail("incident.nextActionDueAtUtc", "must be after recordedAtUtc")
        if set(controls.values()) == {"PASS"}:
            _fail("incident.status", "a fully passing incident drill cannot be BLOCKED")
        if "FAIL" in controls.values() and not defects:
            _fail("incident.defectIssueNumbers", "failed controls require a defect issue")
        incident_ready = False
    else:
        _fail("incident.status", "must be VALIDATED or BLOCKED")

    if (
        approval["status"] == "APPROVED"
        and approval["releaseOwnerRole"] == "release_owner"
        and approval["approvedAtUtc"] is not None
    ):
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
    ready = incident_ready and safe_cleanup and approval_ready
    if approval_ready and not (incident_ready and safe_cleanup):
        _fail("approval", "APPROVED requires a validated drill and safe cleanup")
    if overall != ("VALIDATED" if ready else "BLOCKED"):
        _fail("overallStatus", "must match incident, cleanup and approval outcomes")

    if evidence_bytes is None:
        _fail("evidenceAttestation", "exact evidence bytes are required for incident claims")
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
    parser.add_argument("--restore-evidence", type=Path)
    parser.add_argument("--restore-evidence-attestation", type=Path)
    parser.add_argument("--rollback-receipt", type=Path)
    parser.add_argument("--rollback-receipt-attestation", type=Path)
    parser.add_argument("--evidence-attestation", type=Path)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--require-recorded", action="store_true")
    mode.add_argument("--require-validated", action="store_true")
    mode.add_argument("--prepare-attestation", action="store_true")
    args = parser.parse_args(argv)
    try:
        evidence_bytes = args.evidence.read_bytes()
        evidence = json.loads(evidence_bytes, object_pairs_hook=_unique)

        def load(path: Path | None) -> tuple[Any, bytes | None]:
            raw = path.read_bytes() if path else None
            return (
                json.loads(raw, object_pairs_hook=_unique) if raw is not None else None,
                raw,
            )

        stage_evidence, stage_bytes = load(args.stage_evidence)
        restore_evidence, restore_bytes = load(args.restore_evidence)
        rollback_receipt, rollback_bytes = load(args.rollback_receipt)
        stage_attestation = (
            args.stage_evidence_attestation.read_bytes()
            if args.stage_evidence_attestation else None
        )
        restore_attestation = (
            args.restore_evidence_attestation.read_bytes()
            if args.restore_evidence_attestation else None
        )
        rollback_attestation = (
            args.rollback_receipt_attestation.read_bytes()
            if args.rollback_receipt_attestation else None
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
            restore_evidence=restore_evidence,
            restore_evidence_bytes=restore_bytes,
            restore_evidence_attestation=restore_attestation,
            rollback_receipt=rollback_receipt,
            rollback_receipt_bytes=rollback_bytes,
            rollback_receipt_attestation=rollback_attestation,
            evidence_bytes=evidence_bytes,
            evidence_attestation=evidence_attestation,
        )
        if args.prepare_attestation and not _has_incident_claims(evidence["controls"]):
            _fail("evidenceAttestation", "there are no incident claims to attest")
    except (
        OSError, UnicodeError, json.JSONDecodeError, urllib.error.URLError,
        IncidentRollbackEvidenceError, restore.BackupRestoreEvidenceError,
        stage.StageDeploymentEvidenceError, stage.signed.SignedCandidateError,
    ) as error:
        print(f"Incident rollback evidence invalid: {error}", file=sys.stderr)
        return 1
    if args.prepare_attestation:
        print(f"Incident rollback evidence eligible for protected attestation: {args.evidence}")
    else:
        print(f"Incident rollback evidence valid: {args.evidence}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
