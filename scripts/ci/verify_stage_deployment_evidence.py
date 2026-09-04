#!/usr/bin/env python3
"""Fail-closed validator for protected DigitalOcean stage evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
import tempfile
import urllib.error
from datetime import datetime
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit

import verify_signed_candidate_evidence as signed


SCHEMA = "walking-rpg-stage-deployment-v1"
TOP = {
    "schemaVersion", "recordStatus", "overallStatus", "recordedAtUtc",
    "source", "stage", "deployment", "controls", "cleanup", "approval",
}
SOURCE = {
    "repository", "commitSha", "treeSha", "image", "imageDigest",
    "provenanceGuardBaselineSha", "publisherReceiptSha256",
    "publisherReceiptAttestationSha256",
}
STAGE = {
    "environment", "provider", "region", "publicEndpoint",
    "backendComponent", "backendPlan", "backendInstances", "postgresEngine",
    "postgresPlan", "postgresNodes",
}
DEPLOYMENT = {
    "status", "deploymentId", "previousSafeDeploymentId",
    "deployedImageDigest", "startedAtUtc", "completedAtUtc", "ownerRole",
    "nextActionDueAtUtc", "blockerCategory", "defectIssueNumbers",
}
CONTROLS = {
    "budgetApproved", "auth0ProtectedConfiguration", "immutableImageDigest",
    "publisherProvenance", "embeddedSource", "databaseCustomRole",
    "databaseTrustedSources", "databaseVerifyFull", "databaseLeastPrivilege",
    "flywayCurrent", "oidcFailClosed", "sandboxProvidersDisabled",
    "managementPrivate", "liveProbe", "readyProbe", "dbUnreadyRemoval",
    "mobileThreatControl", "alertPolicies", "alertDelivery",
    "dashboardAccess", "runtimeLogRetention", "logRedaction", "backupPitr",
    "rollbackTarget", "schemaCompatibility",
}
CLEANUP = {
    "renderedSpecRemoved", "temporaryAccessRevoked",
    "secretExposureDetected", "personalDataRetained",
}
APPROVAL = {"status", "releaseOwnerRole", "approvedAtUtc"}
PUBLISHER_RECEIPT = {
    "schemaVersion", "sourceGitSha", "sourceGitTree",
    "provenanceGuardBaselineSha", "image", "digest", "platform",
    "workflowRun", "publishedAt",
}
RESULTS = {"PASS", "FAIL", "NOT_RUN"}
BLOCKERS = {
    "billing_approval_missing", "stage_owner_unassigned", "auth0_not_ready",
    "stage_release_environment_not_ready", "publisher_receipt_unavailable",
    "digitalocean_access_unavailable", "database_unavailable",
    "logging_destination_unavailable", "alert_destination_unavailable",
    "deployment_failed", "control_failed", "cleanup_unconfirmed",
    "other_coarse",
}
SHA = re.compile(r"^[0-9a-f]{40}$")
SHA256 = re.compile(r"^[0-9a-f]{64}$")
IMAGE_DIGEST = re.compile(r"^sha256:[0-9a-f]{64}$")
UUID = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
)
UTC = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
WORKFLOW_RUN = re.compile(
    r"^https://github\.com/MKSEgr/walking-rpg/actions/runs/[1-9][0-9]{0,19}$"
)
REPOSITORY = "MKSEgr/walking-rpg"
IMAGE = "ghcr.io/mksegr/walking-rpg-backend"
PROVENANCE_BASELINE = "31027db88250e83112434db8cfcd85ed2b31fa8a"
PUBLISHER_WORKFLOW = (
    "MKSEgr/walking-rpg/.github/workflows/"
    "publish-backend-release-candidate.yml"
)
EVIDENCE_WORKFLOW = (
    "MKSEgr/walking-rpg/.github/workflows/protected-stage-evidence.yml"
)


class StageDeploymentEvidenceError(ValueError):
    pass


def _fail(path: str, message: str) -> None:
    raise StageDeploymentEvidenceError(f"{path}: {message}")


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


def _image_digest(value: Any, path: str) -> None:
    if (
        not isinstance(value, str)
        or not IMAGE_DIGEST.fullmatch(value)
        or value == "sha256:" + "0" * 64
    ):
        _fail(path, "must be a real immutable sha256 image digest")


def _unique(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise StageDeploymentEvidenceError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _decode_exact(raw: bytes, expected: Any, path: str) -> None:
    try:
        decoded = json.loads(raw, object_pairs_hook=_unique)
    except (UnicodeError, json.JSONDecodeError, StageDeploymentEvidenceError) as error:
        _fail(path, f"cannot decode exact JSON bytes: {error}")
    if decoded != expected:
        _fail(path, "supplied bytes must exactly represent the parsed record")


def _issues(value: Any, path: str) -> list[int]:
    if not isinstance(value, list) or len(value) > 50:
        _fail(path, "must be an array of at most 50 GitHub issue numbers")
    if any(type(item) is not int or item < 1 or item > 999_999_999 for item in value):
        _fail(path, "must contain bounded positive GitHub issue numbers")
    if len(value) != len(set(value)):
        _fail(path, "must not contain duplicate issue numbers")
    return value


def _public_endpoint(value: Any, path: str) -> None:
    if not isinstance(value, str) or len(value) > 253:
        _fail(path, "must be a bounded public HTTPS endpoint")
    try:
        parsed = urlsplit(value)
        port = parsed.port
    except ValueError:
        _fail(path, "must be a valid public HTTPS endpoint")
    host = parsed.hostname
    if (
        parsed.scheme != "https"
        or parsed.username is not None
        or parsed.password is not None
        or port not in {None, 443}
        or parsed.path != ""
        or parsed.query
        or parsed.fragment
        or host is None
        or host == "ondigitalocean.app"
        or not host.endswith(".ondigitalocean.app")
    ):
        _fail(path, "must be a credential-free DigitalOcean HTTPS origin")


def _attest(
    repository: str,
    commit: str,
    subject: bytes,
    bundle: bytes,
    workflow: str,
    path: str,
) -> None:
    with tempfile.TemporaryDirectory() as directory:
        subject_path = Path(directory) / "subject.json"
        bundle_path = Path(directory) / "bundle.jsonl"
        subject_path.write_bytes(subject)
        bundle_path.write_bytes(bundle)
        result = subprocess.run(
            [
                "gh", "attestation", "verify", str(subject_path),
                "--repo", repository,
                "--bundle", str(bundle_path),
                "--signer-workflow", workflow,
                "--source-digest", commit,
            ],
            text=True,
            capture_output=True,
            check=False,
        )
        if result.returncode != 0:
            _fail(path, "protected attestation verification failed")


def _source_is_empty(source: dict[str, Any]) -> bool:
    return all(value is None for value in source.values())


def _has_deployment_claims(controls: dict[str, Any]) -> bool:
    return any(value != "NOT_RUN" for value in controls.values())


def validate(
    data: Any,
    *,
    require_recorded: bool = False,
    require_validated: bool = False,
    require_attestation: bool = True,
    publisher_receipt: Any = None,
    publisher_receipt_bytes: bytes | None = None,
    publisher_receipt_attestation: bytes | None = None,
    evidence_bytes: bytes | None = None,
    evidence_attestation: bytes | None = None,
    repository_root: Path | None = None,
    github_state: dict[str, Any] | None = None,
    publisher_attestation_verifier: Any = None,
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
    stage = _object(root["stage"], "stage", STAGE)
    deployment = _object(root["deployment"], "deployment", DEPLOYMENT)
    controls = _object(root["controls"], "controls", CONTROLS)
    cleanup = _object(root["cleanup"], "cleanup", CLEANUP)
    approval = _object(root["approval"], "approval", APPROVAL)

    if record == "TEMPLATE":
        expected_deployment = {key: None for key in DEPLOYMENT}
        expected_deployment["status"] = "OWNER_INPUT_REQUIRED"
        expected_deployment["defectIssueNumbers"] = []
        if (
            overall != "OWNER_INPUT_REQUIRED"
            or root["recordedAtUtc"] is not None
            or not _source_is_empty(source)
            or any(value is not None for value in stage.values())
            or deployment != expected_deployment
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
    if stage != {
        "environment": "walking-rpg-alpha-eu",
        "provider": "digitalocean",
        "region": "fra",
        "publicEndpoint": stage["publicEndpoint"],
        "backendComponent": "backend",
        "backendPlan": "apps-s-1vcpu-1gb",
        "backendInstances": 1,
        "postgresEngine": "17",
        "postgresPlan": "standard",
        "postgresNodes": 1,
    }:
        _fail("stage", "must match the approved DigitalOcean alpha-stage shape")
    if type(stage["backendInstances"]) is not int or type(stage["postgresNodes"]) is not int:
        _fail("stage", "instance and database-node counts must be strict integers")
    if any(result not in RESULTS for result in controls.values()):
        _fail("controls", "values must be PASS, FAIL or NOT_RUN")
    has_claims = _has_deployment_claims(controls)
    defects = _issues(deployment["defectIssueNumbers"], "deployment.defectIssueNumbers")

    source_empty = _source_is_empty(source)
    published_at: datetime | None = None
    if source_empty:
        if has_claims:
            _fail("source", "deployment claims require an exact publisher receipt")
        if any(
            value is not None
            for value in (
                publisher_receipt, publisher_receipt_bytes,
                publisher_receipt_attestation,
            )
        ):
            _fail("source", "empty source must not be accompanied by publisher inputs")
    else:
        if publisher_receipt is None or publisher_receipt_bytes is None:
            _fail("source", "exact publisher receipt bytes are required")
        _decode_exact(publisher_receipt_bytes, publisher_receipt, "source.publisherReceipt")
        receipt = _object(
            publisher_receipt,
            "source.publisherReceipt",
            PUBLISHER_RECEIPT,
        )
        if receipt["schemaVersion"] != "walking-rpg-backend-image-receipt-v1":
            _fail("source.publisherReceipt.schemaVersion", "has an unsupported value")
        if receipt["image"] != IMAGE or receipt["platform"] != "linux/amd64":
            _fail("source.publisherReceipt", "must identify the approved backend image")
        if not isinstance(receipt["sourceGitSha"], str) or not SHA.fullmatch(receipt["sourceGitSha"]):
            _fail("source.publisherReceipt.sourceGitSha", "must be a lowercase commit SHA")
        if not isinstance(receipt["sourceGitTree"], str) or not SHA.fullmatch(receipt["sourceGitTree"]):
            _fail("source.publisherReceipt.sourceGitTree", "must be a lowercase tree SHA")
        if receipt["provenanceGuardBaselineSha"] != PROVENANCE_BASELINE:
            _fail("source.publisherReceipt", "must use the approved provenance baseline")
        _image_digest(receipt["digest"], "source.publisherReceipt.digest")
        if not isinstance(receipt["workflowRun"], str) or not WORKFLOW_RUN.fullmatch(receipt["workflowRun"]):
            _fail("source.publisherReceipt.workflowRun", "must identify the publisher workflow run")
        published_at = _time(receipt["publishedAt"], "source.publisherReceipt.publishedAt")
        if published_at > recorded_at:
            _fail("source.publisherReceipt.publishedAt", "must not follow recordedAtUtc")
        receipt_sha = hashlib.sha256(publisher_receipt_bytes).hexdigest()
        receipt_attestation_sha = (
            hashlib.sha256(publisher_receipt_attestation).hexdigest()
            if publisher_receipt_attestation is not None
            else None
        )
        if source != {
            "repository": REPOSITORY,
            "commitSha": receipt["sourceGitSha"],
            "treeSha": receipt["sourceGitTree"],
            "image": IMAGE,
            "imageDigest": receipt["digest"],
            "provenanceGuardBaselineSha": PROVENANCE_BASELINE,
            "publisherReceiptSha256": receipt_sha,
            "publisherReceiptAttestationSha256": receipt_attestation_sha,
        }:
            _fail("source", "must exactly identify the supplied publisher receipt")
        if publisher_receipt_attestation is None:
            _fail("source", "publisher receipt requires its protected attestation bundle")
        publisher_verifier = publisher_attestation_verifier or (
            lambda repository, commit, subject, bundle: _attest(
                repository,
                commit,
                subject,
                bundle,
                PUBLISHER_WORKFLOW,
                "source.publisherReceiptAttestation",
            )
        )
        publisher_verifier(
            REPOSITORY,
            source["commitSha"],
            publisher_receipt_bytes,
            publisher_receipt_attestation,
        )
        repo = repository_root or Path(__file__).resolve().parents[2]
        remote = signed._git(repo, "remote", "get-url", "origin")
        if remote.removesuffix(".git") not in {
            "https://github.com/MKSEgr/walking-rpg",
            "git@github.com:MKSEgr/walking-rpg",
        }:
            _fail("source.repository", "origin must be the canonical repository")
        state = github_state or signed._github_state(REPOSITORY, source["commitSha"])
        if source["commitSha"] != state.get("masterSha"):
            _fail("source.commitSha", "must equal GitHub's current master commit")
        if not {"CI", "Release quality"}.issubset(set(state.get("successfulWorkflows", []))):
            _fail("source", "current source requires successful CI and Release quality")
        actual_tree = signed._git(repo, "rev-parse", f'{source["commitSha"]}^{{tree}}')
        if source["treeSha"] != actual_tree:
            _fail("source.treeSha", "must equal the actual source tree")

    if has_claims:
        if source_empty:
            _fail("source", "deployment claims require verified source")
        _public_endpoint(stage["publicEndpoint"], "stage.publicEndpoint")
        if not isinstance(deployment["deploymentId"], str) or not UUID.fullmatch(deployment["deploymentId"]):
            _fail("deployment.deploymentId", "must be a lowercase provider UUID")
        if not isinstance(deployment["previousSafeDeploymentId"], str) or not UUID.fullmatch(deployment["previousSafeDeploymentId"]):
            _fail("deployment.previousSafeDeploymentId", "must be a lowercase provider UUID")
        if deployment["deploymentId"] == deployment["previousSafeDeploymentId"]:
            _fail("deployment", "current and previous deployment IDs must differ")
        if deployment["deployedImageDigest"] != source["imageDigest"]:
            _fail("deployment.deployedImageDigest", "must match the publisher receipt")
        started = _time(deployment["startedAtUtc"], "deployment.startedAtUtc")
        completed = _time(deployment["completedAtUtc"], "deployment.completedAtUtc")
        if completed < started or completed > recorded_at:
            _fail("deployment", "times must be ordered and finish by recordedAtUtc")
        if published_at is not None and started < published_at:
            _fail("deployment.startedAtUtc", "must not precede image publication")
    else:
        if stage["publicEndpoint"] is not None:
            _fail("stage.publicEndpoint", "NOT_RUN evidence must not claim an endpoint")
        if any(
            deployment[key] is not None
            for key in (
                "deploymentId", "previousSafeDeploymentId", "deployedImageDigest",
                "startedAtUtc", "completedAtUtc",
            )
        ):
            _fail("deployment", "NOT_RUN evidence must not retain deployment metadata")

    if deployment["status"] == "VALIDATED":
        if set(controls.values()) != {"PASS"}:
            _fail("deployment.status", "VALIDATED requires every control PASS")
        if defects:
            _fail("deployment.defectIssueNumbers", "VALIDATED must not retain defects")
        if (
            deployment["ownerRole"] != "operations_owner"
            or deployment["nextActionDueAtUtc"] is not None
            or deployment["blockerCategory"] is not None
        ):
            _fail("deployment", "VALIDATED owner/blocker fields are inconsistent")
        deployment_ready = True
    elif deployment["status"] == "BLOCKED":
        if deployment["blockerCategory"] not in BLOCKERS:
            _fail("deployment.blockerCategory", "must be an approved coarse blocker")
        expected_owner = (
            None
            if deployment["blockerCategory"] == "stage_owner_unassigned"
            else "operations_owner"
        )
        if deployment["ownerRole"] != expected_owner:
            _fail("deployment.ownerRole", "must match the blocked owner assignment")
        due_at = _time(deployment["nextActionDueAtUtc"], "deployment.nextActionDueAtUtc")
        if due_at <= recorded_at:
            _fail("deployment.nextActionDueAtUtc", "must be after recordedAtUtc")
        if set(controls.values()) == {"PASS"}:
            _fail("deployment.status", "a fully passing deployment cannot be BLOCKED")
        if not has_claims and defects:
            _fail("deployment.defectIssueNumbers", "NOT_RUN blocker must not retain defects")
        if "FAIL" in controls.values() and not defects:
            _fail("deployment.defectIssueNumbers", "failed controls require a defect issue")
        deployment_ready = False
    else:
        _fail("deployment.status", "must be VALIDATED or BLOCKED")

    if any(type(value) is not bool for value in cleanup.values()):
        _fail("cleanup", "recorded cleanup values must be strict booleans")
    safe_cleanup = cleanup == {
        "renderedSpecRemoved": True,
        "temporaryAccessRevoked": True,
        "secretExposureDetected": False,
        "personalDataRetained": False,
    }
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
    ready = deployment_ready and safe_cleanup and approval_ready
    if approval_ready and not (deployment_ready and safe_cleanup):
        _fail("approval", "APPROVED requires validated deployment and safe cleanup")
    if overall != ("VALIDATED" if ready else "BLOCKED"):
        _fail("overallStatus", "must match deployment, cleanup and approval outcomes")

    if has_claims:
        if evidence_bytes is None:
            _fail("evidenceAttestation", "exact evidence bytes are required for deployment claims")
        _decode_exact(evidence_bytes, data, "evidenceAttestation")
        if require_attestation:
            if evidence_attestation is None:
                _fail("evidenceAttestation", "protected attestation bundle is required")
            evidence_verifier = evidence_attestation_verifier or (
                lambda repository, commit, subject, bundle: _attest(
                    repository,
                    commit,
                    subject,
                    bundle,
                    EVIDENCE_WORKFLOW,
                    "evidenceAttestation",
                )
            )
            evidence_verifier(
                REPOSITORY,
                source["commitSha"],
                evidence_bytes,
                evidence_attestation,
            )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence", type=Path)
    parser.add_argument("--publisher-receipt", type=Path)
    parser.add_argument("--publisher-receipt-attestation", type=Path)
    parser.add_argument("--evidence-attestation", type=Path)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--require-recorded", action="store_true")
    mode.add_argument("--require-validated", action="store_true")
    mode.add_argument("--prepare-attestation", action="store_true")
    args = parser.parse_args(argv)
    try:
        evidence_bytes = args.evidence.read_bytes()
        evidence = json.loads(evidence_bytes, object_pairs_hook=_unique)
        receipt_bytes = args.publisher_receipt.read_bytes() if args.publisher_receipt else None
        receipt = (
            json.loads(receipt_bytes, object_pairs_hook=_unique)
            if receipt_bytes is not None
            else None
        )
        receipt_attestation = (
            args.publisher_receipt_attestation.read_bytes()
            if args.publisher_receipt_attestation
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
            publisher_receipt=receipt,
            publisher_receipt_bytes=receipt_bytes,
            publisher_receipt_attestation=receipt_attestation,
            evidence_bytes=evidence_bytes,
            evidence_attestation=evidence_attestation,
        )
        if args.prepare_attestation and not _has_deployment_claims(evidence["controls"]):
            _fail("evidenceAttestation", "there are no deployment claims to attest")
    except (
        OSError,
        UnicodeError,
        json.JSONDecodeError,
        urllib.error.URLError,
        StageDeploymentEvidenceError,
        signed.SignedCandidateError,
    ) as error:
        print(f"Stage deployment evidence invalid: {error}", file=sys.stderr)
        return 1
    if args.prepare_attestation:
        print(f"Stage deployment evidence eligible for protected attestation: {args.evidence}")
    else:
        print(f"Stage deployment evidence valid: {args.evidence}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
