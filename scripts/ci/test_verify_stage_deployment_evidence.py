#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import importlib.util
import json
import subprocess
import unittest
from pathlib import Path
from typing import Any


MODULE = Path(__file__).with_name("verify_stage_deployment_evidence.py")
SPEC = importlib.util.spec_from_file_location("stage_deployment_evidence", MODULE)
assert SPEC and SPEC.loader
V = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(V)
ROOT = Path(__file__).resolve().parents[2]
TEMPLATE = ROOT / "docs/evidence/digitalocean-stage-deployment-template.json"
PUBLISHER_ATTESTATION = b"protected-publisher-receipt-attestation"
EVIDENCE_ATTESTATION = b"protected-stage-evidence-attestation"


def encoded(value: dict[str, Any]) -> bytes:
    return json.dumps(value, separators=(",", ":")).encode()


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def template() -> dict[str, Any]:
    return json.loads(TEMPLATE.read_text(encoding="utf-8"))


def receipt() -> dict[str, Any]:
    return {
        "schemaVersion": "walking-rpg-backend-image-receipt-v1",
        "sourceGitSha": git("rev-parse", "HEAD"),
        "sourceGitTree": git("rev-parse", "HEAD^{tree}"),
        "provenanceGuardBaselineSha": V.PROVENANCE_BASELINE,
        "image": V.IMAGE,
        "digest": "sha256:" + "a" * 64,
        "platform": "linux/amd64",
        "workflowRun": "https://github.com/MKSEgr/walking-rpg/actions/runs/33845027634",
        "publishedAt": "2026-09-04T08:00:00Z",
    }


def recorded(validated: bool = True, with_source: bool | None = None) -> tuple[dict[str, Any], dict[str, Any] | None, bytes | None]:
    value = template()
    value.update({
        "recordStatus": "RECORDED",
        "overallStatus": "VALIDATED" if validated else "BLOCKED",
        "recordedAtUtc": "2026-09-04T10:30:00Z",
    })
    use_source = validated if with_source is None else with_source
    receipt_value = receipt() if use_source else None
    receipt_bytes = encoded(receipt_value) if receipt_value is not None else None
    value["source"] = (
        {
            "repository": V.REPOSITORY,
            "commitSha": receipt_value["sourceGitSha"],
            "treeSha": receipt_value["sourceGitTree"],
            "image": receipt_value["image"],
            "imageDigest": receipt_value["digest"],
            "provenanceGuardBaselineSha": receipt_value["provenanceGuardBaselineSha"],
            "publisherReceiptSha256": hashlib.sha256(receipt_bytes).hexdigest(),
            "publisherReceiptAttestationSha256": hashlib.sha256(PUBLISHER_ATTESTATION).hexdigest(),
        }
        if receipt_value is not None and receipt_bytes is not None
        else {key: None for key in V.SOURCE}
    )
    value["stage"] = {
        "environment": "walking-rpg-alpha-eu",
        "provider": "digitalocean",
        "region": "fra",
        "publicEndpoint": (
            "https://walking-rpg-alpha-eu-a1b2c.ondigitalocean.app"
            if validated
            else None
        ),
        "backendComponent": "backend",
        "backendPlan": "apps-s-1vcpu-1gb",
        "backendInstances": 1,
        "postgresEngine": "17",
        "postgresPlan": "standard",
        "postgresNodes": 1,
    }
    value["controls"] = {
        key: ("PASS" if validated else "NOT_RUN") for key in V.CONTROLS
    }
    value["deployment"] = {
        "status": "VALIDATED" if validated else "BLOCKED",
        "deploymentId": (
            "12345678-1234-4abc-8def-1234567890ab" if validated else None
        ),
        "previousSafeDeploymentId": (
            "abcdef01-2345-4abc-8def-1234567890ab" if validated else None
        ),
        "deployedImageDigest": value["source"]["imageDigest"] if validated else None,
        "startedAtUtc": "2026-09-04T09:00:00Z" if validated else None,
        "completedAtUtc": "2026-09-04T10:00:00Z" if validated else None,
        "ownerRole": "operations_owner",
        "nextActionDueAtUtc": None if validated else "2026-09-10T10:00:00Z",
        "blockerCategory": None if validated else "digitalocean_access_unavailable",
        "defectIssueNumbers": [],
    }
    value["cleanup"] = {
        "renderedSpecRemoved": True,
        "temporaryAccessRevoked": True,
        "secretExposureDetected": False,
        "personalDataRetained": False,
    }
    value["approval"] = (
        {
            "status": "APPROVED",
            "releaseOwnerRole": "release_owner",
            "approvedAtUtc": "2026-09-04T11:00:00Z",
        }
        if validated
        else {
            "status": "BLOCKED",
            "releaseOwnerRole": None,
            "approvedAtUtc": None,
        }
    )
    return value, receipt_value, receipt_bytes


def validate(
    value: dict[str, Any],
    receipt_value: dict[str, Any] | None,
    receipt_bytes: bytes | None,
    *,
    require_validated: bool = False,
    include_publisher_attestation: bool = True,
    include_evidence_attestation: bool = True,
    github_state: dict[str, Any] | None = None,
    publisher_verifier: Any = None,
    evidence_verifier: Any = None,
) -> None:
    source_present = not V._source_is_empty(value["source"])
    V.validate(
        value,
        require_recorded=True,
        require_validated=require_validated,
        publisher_receipt=receipt_value,
        publisher_receipt_bytes=receipt_bytes,
        publisher_receipt_attestation=(
            PUBLISHER_ATTESTATION
            if source_present and include_publisher_attestation
            else None
        ),
        evidence_bytes=encoded(value),
        evidence_attestation=(
            EVIDENCE_ATTESTATION if include_evidence_attestation else None
        ),
        repository_root=ROOT,
        github_state=github_state or {
            "masterSha": git("rev-parse", "HEAD"),
            "successfulWorkflows": {"CI", "Release quality"},
        },
        publisher_attestation_verifier=(
            publisher_verifier or (lambda *_args: None)
        ),
        evidence_attestation_verifier=(
            evidence_verifier or (lambda *_args: None)
        ),
    )


class StageDeploymentEvidenceTest(unittest.TestCase):
    def test_template_is_valid_but_not_recorded_or_validated(self) -> None:
        V.validate(template())
        with self.assertRaisesRegex(V.StageDeploymentEvidenceError, "recorded evidence"):
            V.validate(template(), require_recorded=True)
        with self.assertRaisesRegex(V.StageDeploymentEvidenceError, "RECORDED VALIDATED"):
            V.validate(template(), require_validated=True)

    def test_complete_stage_record_passes_both_attestation_boundaries(self) -> None:
        value, receipt_value, receipt_bytes = recorded()
        calls: list[str] = []
        validate(
            value,
            receipt_value,
            receipt_bytes,
            require_validated=True,
            publisher_verifier=lambda *_args: calls.append("publisher"),
            evidence_verifier=lambda *_args: calls.append("evidence"),
        )
        self.assertEqual(calls, ["publisher", "evidence"])

    def test_no_run_blocker_is_recorded_without_external_claims(self) -> None:
        value, receipt_value, receipt_bytes = recorded(False)
        validate(value, receipt_value, receipt_bytes, include_evidence_attestation=False)
        with self.assertRaisesRegex(V.StageDeploymentEvidenceError, "RECORDED VALIDATED"):
            validate(
                value,
                receipt_value,
                receipt_bytes,
                require_validated=True,
                include_evidence_attestation=False,
            )

    def test_publisher_receipt_bytes_and_source_tuple_are_bound(self) -> None:
        value, receipt_value, receipt_bytes = recorded()
        value["source"]["publisherReceiptSha256"] = "b" * 64
        with self.assertRaisesRegex(V.StageDeploymentEvidenceError, "exactly identify"):
            validate(value, receipt_value, receipt_bytes)

        value, receipt_value, receipt_bytes = recorded()
        value["source"]["treeSha"] = "c" * 40
        with self.assertRaisesRegex(V.StageDeploymentEvidenceError, "exactly identify"):
            validate(value, receipt_value, receipt_bytes)

        value, receipt_value, _ = recorded()
        assert receipt_value is not None
        receipt_value["sourceGitTree"] = "c" * 40
        receipt_bytes = encoded(receipt_value)
        value["source"]["treeSha"] = receipt_value["sourceGitTree"]
        value["source"]["publisherReceiptSha256"] = hashlib.sha256(receipt_bytes).hexdigest()
        with self.assertRaisesRegex(V.StageDeploymentEvidenceError, "actual source tree"):
            validate(value, receipt_value, receipt_bytes)

        value, receipt_value, receipt_bytes = recorded()
        value["deployment"]["deployedImageDigest"] = "sha256:" + "d" * 64
        with self.assertRaisesRegex(V.StageDeploymentEvidenceError, "publisher receipt"):
            validate(value, receipt_value, receipt_bytes)

    def test_publisher_attestation_and_current_master_are_required(self) -> None:
        value, receipt_value, receipt_bytes = recorded()
        value["source"]["publisherReceiptAttestationSha256"] = None
        with self.assertRaisesRegex(V.StageDeploymentEvidenceError, "requires its protected attestation"):
            validate(
                value,
                receipt_value,
                receipt_bytes,
                include_publisher_attestation=False,
            )

        value, receipt_value, receipt_bytes = recorded()
        with self.assertRaisesRegex(V.StageDeploymentEvidenceError, "current master"):
            validate(
                value,
                receipt_value,
                receipt_bytes,
                github_state={
                    "masterSha": "e" * 40,
                    "successfulWorkflows": {"CI", "Release quality"},
                },
            )

    def test_endpoint_is_public_credential_free_and_digitalocean_only(self) -> None:
        for unsafe in (
            "https://user:token@walking-rpg.ondigitalocean.app",
            "https://walking-rpg.ondigitalocean.app/?token=secret",
            "https://walking-rpg.ondigitalocean.app/",
            "https://127.0.0.1",
            "https://walking-rpg.example.com",
        ):
            value, receipt_value, receipt_bytes = recorded()
            value["stage"]["publicEndpoint"] = unsafe
            with self.assertRaisesRegex(V.StageDeploymentEvidenceError, "DigitalOcean HTTPS origin"):
                validate(value, receipt_value, receipt_bytes)

    def test_controls_are_complete_and_failures_require_defects(self) -> None:
        value, receipt_value, receipt_bytes = recorded()
        del value["controls"]["databaseVerifyFull"]
        with self.assertRaisesRegex(V.StageDeploymentEvidenceError, "keys mismatch"):
            validate(value, receipt_value, receipt_bytes)

        value, receipt_value, receipt_bytes = recorded()
        value["overallStatus"] = "BLOCKED"
        value["deployment"].update({
            "status": "BLOCKED",
            "nextActionDueAtUtc": "2026-09-10T10:00:00Z",
            "blockerCategory": "control_failed",
        })
        value["approval"] = {
            "status": "BLOCKED",
            "releaseOwnerRole": None,
            "approvedAtUtc": None,
        }
        value["controls"]["databaseLeastPrivilege"] = "FAIL"
        with self.assertRaisesRegex(V.StageDeploymentEvidenceError, "failed controls require a defect"):
            validate(value, receipt_value, receipt_bytes)
        value["deployment"]["defectIssueNumbers"] = [566]
        validate(value, receipt_value, receipt_bytes)

    def test_deployment_identity_and_times_fail_closed(self) -> None:
        value, receipt_value, receipt_bytes = recorded()
        value["deployment"]["deploymentId"] = value["deployment"]["previousSafeDeploymentId"]
        with self.assertRaisesRegex(V.StageDeploymentEvidenceError, "must differ"):
            validate(value, receipt_value, receipt_bytes)

        value, receipt_value, receipt_bytes = recorded()
        value["deployment"]["startedAtUtc"] = "2026-09-04T07:00:00Z"
        with self.assertRaisesRegex(V.StageDeploymentEvidenceError, "must not precede image publication"):
            validate(value, receipt_value, receipt_bytes)

        value, receipt_value, receipt_bytes = recorded()
        value["deployment"]["completedAtUtc"] = "2026-09-04T12:00:00Z"
        with self.assertRaisesRegex(V.StageDeploymentEvidenceError, "finish by recordedAtUtc"):
            validate(value, receipt_value, receipt_bytes)

        value, receipt_value, _ = recorded()
        assert receipt_value is not None
        receipt_value["publishedAt"] = "2026-09-04T12:00:00Z"
        receipt_bytes = encoded(receipt_value)
        value["source"]["publisherReceiptSha256"] = hashlib.sha256(receipt_bytes).hexdigest()
        with self.assertRaisesRegex(V.StageDeploymentEvidenceError, "must not follow recordedAtUtc"):
            validate(value, receipt_value, receipt_bytes)

    def test_cleanup_and_approval_shapes_reject_sensitive_values(self) -> None:
        value, receipt_value, receipt_bytes = recorded()
        value["cleanup"]["temporaryAccessRevoked"] = {"token": "secret"}
        value["overallStatus"] = "BLOCKED"
        value["approval"] = {
            "status": "BLOCKED",
            "releaseOwnerRole": None,
            "approvedAtUtc": None,
        }
        with self.assertRaisesRegex(V.StageDeploymentEvidenceError, "strict booleans"):
            validate(value, receipt_value, receipt_bytes)

        value, receipt_value, receipt_bytes = recorded()
        value["approval"]["approvedAtUtc"] = "2026-09-04T09:30:00Z"
        with self.assertRaisesRegex(V.StageDeploymentEvidenceError, "must not precede recording"):
            validate(value, receipt_value, receipt_bytes)

        value, receipt_value, receipt_bytes = recorded()
        value["stage"]["backendInstances"] = True
        with self.assertRaisesRegex(V.StageDeploymentEvidenceError, "strict integers"):
            validate(value, receipt_value, receipt_bytes)

    def test_deployment_claims_require_exact_protected_attestation(self) -> None:
        value, receipt_value, receipt_bytes = recorded()
        with self.assertRaisesRegex(V.StageDeploymentEvidenceError, "exact evidence bytes"):
            V.validate(
                value,
                publisher_receipt=receipt_value,
                publisher_receipt_bytes=receipt_bytes,
                publisher_receipt_attestation=PUBLISHER_ATTESTATION,
                repository_root=ROOT,
                github_state={
                    "masterSha": git("rev-parse", "HEAD"),
                    "successfulWorkflows": {"CI", "Release quality"},
                },
                publisher_attestation_verifier=lambda *_args: None,
            )

        with self.assertRaisesRegex(V.StageDeploymentEvidenceError, "protected attestation bundle"):
            validate(
                value,
                receipt_value,
                receipt_bytes,
                include_evidence_attestation=False,
            )

        def reject(*_args: Any) -> None:
            raise V.StageDeploymentEvidenceError("evidenceAttestation: rejected")

        with self.assertRaisesRegex(V.StageDeploymentEvidenceError, "rejected"):
            validate(
                value,
                receipt_value,
                receipt_bytes,
                evidence_verifier=reject,
            )


if __name__ == "__main__":
    unittest.main()
