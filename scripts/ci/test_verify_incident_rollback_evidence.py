#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import subprocess
import unittest
from pathlib import Path
from typing import Any

import test_verify_backup_restore_evidence as restore_fixture


MODULE = Path(__file__).with_name("verify_incident_rollback_evidence.py")
SPEC = importlib.util.spec_from_file_location("incident_rollback_evidence", MODULE)
assert SPEC and SPEC.loader
V = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(V)
ROOT = Path(__file__).resolve().parents[2]
TEMPLATE = ROOT / "docs/evidence/incident-rollback-drill-template.json"
STAGE_ATTESTATION = restore_fixture.STAGE_ATTESTATION
RESTORE_ATTESTATION = restore_fixture.RESTORE_ATTESTATION
PUBLISHER_ATTESTATION = b"protected-rollback-publisher-attestation"
INCIDENT_ATTESTATION = b"protected-incident-rollback-attestation"
_ROLLBACK_SOURCE: tuple[str, str] | None = None


def encoded(value: dict[str, Any]) -> bytes:
    return json.dumps(value, separators=(",", ":")).encode()


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def template() -> dict[str, Any]:
    return json.loads(TEMPLATE.read_text(encoding="utf-8"))


def rollback_source() -> tuple[str, str]:
    global _ROLLBACK_SOURCE
    if _ROLLBACK_SOURCE is None:
        tree = subprocess.check_output(
            ["git", "mktree"], cwd=ROOT, input="", text=True
        ).strip()
        env = {
            **os.environ,
            "GIT_AUTHOR_NAME": "walking-rpg fixture",
            "GIT_AUTHOR_EMAIL": "fixture@example.invalid",
            "GIT_AUTHOR_DATE": "2000-01-01T00:00:00Z",
            "GIT_COMMITTER_NAME": "walking-rpg fixture",
            "GIT_COMMITTER_EMAIL": "fixture@example.invalid",
            "GIT_COMMITTER_DATE": "2000-01-01T00:00:00Z",
        }
        source = subprocess.check_output(
            ["git", "commit-tree", tree, "-m", "fixture rollback source"],
            cwd=ROOT,
            env=env,
            text=True,
        ).strip()
        _ROLLBACK_SOURCE = source, tree
    return _ROLLBACK_SOURCE


def rollback_receipt() -> dict[str, Any]:
    source, tree = rollback_source()
    return {
        "schemaVersion": "walking-rpg-backend-image-receipt-v1",
        "sourceGitSha": source,
        "sourceGitTree": tree,
        "provenanceGuardBaselineSha": V.stage.PROVENANCE_BASELINE,
        "image": V.IMAGE,
        "digest": "sha256:" + "c" * 64,
        "platform": "linux/amd64",
        "workflowRun": "https://github.com/MKSEgr/walking-rpg/actions/runs/33861298302",
        "publishedAt": "2026-09-04T12:30:00Z",
    }


def recorded(
    validated: bool = True,
    with_claims: bool = True,
) -> tuple[
    dict[str, Any], dict[str, Any] | None, bytes | None,
    dict[str, Any] | None, bytes | None, dict[str, Any] | None, bytes | None,
]:
    value = template()
    value.update({
        "recordStatus": "RECORDED",
        "overallStatus": "VALIDATED" if validated else "BLOCKED",
        "recordedAtUtc": "2026-09-04T14:00:00Z",
    })
    if not with_claims:
        value["rollback"] = {key: None for key in V.ROLLBACK}
        value["rollback"]["status"] = "NOT_RUN"
        value["incident"] = {key: None for key in V.INCIDENT}
        value["incident"].update({
            "status": "BLOCKED",
            "incidentOwnerRole": "incident_owner",
            "nextActionDueAtUtc": "2026-09-10T14:00:00Z",
            "blockerCategory": "rollback_target_unavailable",
            "defectIssueNumbers": [],
        })
        value["controls"] = {key: "NOT_RUN" for key in V.CONTROLS}
        value["cleanup"] = {
            "failureInjectionRemoved": True,
            "riskyConfigDisabled": True,
            "temporaryAccessRevoked": True,
            "secretExposureDetected": False,
            "evidenceContainsPersonalData": False,
        }
        value["approval"] = {
            "status": "BLOCKED",
            "releaseOwnerRole": None,
            "approvedAtUtc": None,
        }
        return value, None, None, None, None, None, None

    restore_value, stage_value, stage_bytes = restore_fixture.recorded()
    assert stage_value is not None and stage_bytes is not None
    restore_bytes = encoded(restore_value)
    receipt = rollback_receipt()
    receipt_bytes = encoded(receipt)
    stage_source = stage_value["source"]
    stage_deployment = stage_value["deployment"]
    value["source"] = {
        "repository": V.REPOSITORY,
        "commitSha": stage_source["commitSha"],
        "treeSha": stage_source["treeSha"],
        "image": V.IMAGE,
        "imageDigest": stage_source["imageDigest"],
        "stageEvidenceSha256": hashlib.sha256(stage_bytes).hexdigest(),
        "stageEvidenceAttestationSha256": hashlib.sha256(STAGE_ATTESTATION).hexdigest(),
        "restoreEvidenceSha256": hashlib.sha256(restore_bytes).hexdigest(),
        "restoreEvidenceAttestationSha256": hashlib.sha256(RESTORE_ATTESTATION).hexdigest(),
        "rollbackPublisherReceiptSha256": hashlib.sha256(receipt_bytes).hexdigest(),
        "rollbackPublisherReceiptAttestationSha256": hashlib.sha256(PUBLISHER_ATTESTATION).hexdigest(),
    }
    value["rollback"] = {
        "status": "COMPLETED",
        "beforeDeploymentId": stage_deployment["deploymentId"],
        "rollbackDeploymentId": stage_deployment["previousSafeDeploymentId"],
        "beforeSourceSha": stage_source["commitSha"],
        "beforeTreeSha": stage_source["treeSha"],
        "beforeImageDigest": stage_source["imageDigest"],
        "rollbackSourceSha": receipt["sourceGitSha"],
        "rollbackTreeSha": receipt["sourceGitTree"],
        "rollbackImageDigest": receipt["digest"],
    }
    value["incident"] = {
        "status": "VALIDATED",
        "incidentId": "incident-drill-20260904-01",
        "scenario": "backend_readiness_failure",
        "scope": "CONTROLLED_STAGE",
        "startedAtUtc": "2026-09-04T13:00:00Z",
        "detectedAtUtc": "2026-09-04T13:01:00Z",
        "acknowledgedAtUtc": "2026-09-04T13:03:00Z",
        "stopDecidedAtUtc": "2026-09-04T13:05:00Z",
        "rollbackStartedAtUtc": "2026-09-04T13:10:00Z",
        "rollbackCompletedAtUtc": "2026-09-04T13:20:00Z",
        "validationCompletedAtUtc": "2026-09-04T13:30:00Z",
        "expectedDetectionSeconds": 120,
        "observedDetectionSeconds": 60,
        "expectedRtoSeconds": 2400,
        "observedRtoSeconds": 1800,
        "incidentOwnerRole": "incident_owner",
        "stopAuthorityRole": "release_owner",
        "nextActionDueAtUtc": None,
        "blockerCategory": None,
        "defectIssueNumbers": [],
    }
    value["controls"] = {key: "PASS" for key in V.CONTROLS}
    value["cleanup"] = {
        "failureInjectionRemoved": True,
        "riskyConfigDisabled": True,
        "temporaryAccessRevoked": True,
        "secretExposureDetected": False,
        "evidenceContainsPersonalData": False,
    }
    value["approval"] = {
        "status": "APPROVED",
        "releaseOwnerRole": "release_owner",
        "approvedAtUtc": "2026-09-04T14:05:00Z",
    }
    if not validated:
        block(value, "authentication", "validation_failed")
    return (
        value, stage_value, stage_bytes, restore_value, restore_bytes,
        receipt, receipt_bytes,
    )


def block(value: dict[str, Any], control: str, category: str) -> None:
    value["overallStatus"] = "BLOCKED"
    value["controls"][control] = "FAIL"
    value["incident"].update({
        "status": "BLOCKED",
        "nextActionDueAtUtc": "2026-09-10T14:00:00Z",
        "blockerCategory": category,
        "defectIssueNumbers": [569],
    })
    value["approval"] = {
        "status": "BLOCKED",
        "releaseOwnerRole": None,
        "approvedAtUtc": None,
    }


def validate(
    value: dict[str, Any],
    stage_value: dict[str, Any] | None,
    stage_bytes: bytes | None,
    restore_value: dict[str, Any] | None,
    restore_bytes: bytes | None,
    receipt: dict[str, Any] | None,
    receipt_bytes: bytes | None,
    *,
    require_validated: bool = False,
    include_stage_attestation: bool = True,
    include_restore_attestation: bool = True,
    include_publisher_attestation: bool = True,
    include_incident_attestation: bool = True,
    github_state: dict[str, Any] | None = None,
    stage_verifier: Any = None,
    restore_verifier: Any = None,
    publisher_verifier: Any = None,
    incident_verifier: Any = None,
) -> None:
    claims = V._has_incident_claims(value["controls"])
    V.validate(
        value,
        require_recorded=True,
        require_validated=require_validated,
        stage_evidence=stage_value,
        stage_evidence_bytes=stage_bytes,
        stage_evidence_attestation=(
            STAGE_ATTESTATION if claims and include_stage_attestation else None
        ),
        restore_evidence=restore_value,
        restore_evidence_bytes=restore_bytes,
        restore_evidence_attestation=(
            RESTORE_ATTESTATION if claims and include_restore_attestation else None
        ),
        rollback_receipt=receipt,
        rollback_receipt_bytes=receipt_bytes,
        rollback_receipt_attestation=(
            PUBLISHER_ATTESTATION if claims and include_publisher_attestation else None
        ),
        evidence_bytes=encoded(value),
        evidence_attestation=(
            INCIDENT_ATTESTATION if claims and include_incident_attestation else None
        ),
        repository_root=ROOT,
        github_state=github_state or {
            "masterSha": git("rev-parse", "HEAD"),
            "successfulWorkflows": {"CI", "Release quality"},
        },
        stage_attestation_verifier=stage_verifier or (lambda *_args: None),
        restore_attestation_verifier=restore_verifier or (lambda *_args: None),
        rollback_receipt_attestation_verifier=publisher_verifier or (lambda *_args: None),
        evidence_attestation_verifier=incident_verifier or (lambda *_args: None),
    )


class IncidentRollbackEvidenceTest(unittest.TestCase):
    def test_template_is_valid_but_not_recorded_or_validated(self) -> None:
        V.validate(template())
        with self.assertRaisesRegex(V.IncidentRollbackEvidenceError, "recorded evidence"):
            V.validate(template(), require_recorded=True)
        with self.assertRaisesRegex(V.IncidentRollbackEvidenceError, "RECORDED VALIDATED"):
            V.validate(template(), require_validated=True)

    def test_complete_record_passes_all_attestation_boundaries(self) -> None:
        values = recorded()
        calls: list[str] = []
        validate(
            *values,
            require_validated=True,
            stage_verifier=lambda *_args: calls.append("stage"),
            restore_verifier=lambda *_args: calls.append("restore"),
            publisher_verifier=lambda *_args: calls.append("publisher"),
            incident_verifier=lambda *_args: calls.append("incident"),
        )
        self.assertEqual(calls, ["stage", "restore", "publisher", "incident"])

    def test_no_run_blocker_has_no_external_claims(self) -> None:
        values = recorded(False, False)
        validate(
            *values,
            include_stage_attestation=False,
            include_restore_attestation=False,
            include_publisher_attestation=False,
            include_incident_attestation=False,
        )
        with self.assertRaisesRegex(V.IncidentRollbackEvidenceError, "RECORDED VALIDATED"):
            validate(
                *values,
                require_validated=True,
                include_stage_attestation=False,
                include_restore_attestation=False,
                include_publisher_attestation=False,
                include_incident_attestation=False,
            )

    def test_stage_and_restore_evidence_are_exactly_bound(self) -> None:
        values = list(recorded())
        values[0]["source"]["restoreEvidenceSha256"] = "d" * 64
        with self.assertRaisesRegex(V.IncidentRollbackEvidenceError, "exactly identify"):
            validate(*values)

        values = list(recorded())
        assert values[3] is not None
        values[3]["overallStatus"] = "BLOCKED"
        values[4] = encoded(values[3])
        values[0]["source"]["restoreEvidenceSha256"] = hashlib.sha256(values[4]).hexdigest()
        with self.assertRaisesRegex(V.restore.BackupRestoreEvidenceError, "RECORDED VALIDATED"):
            validate(*values)

    def test_all_upstream_attestations_are_required(self) -> None:
        values = recorded()
        with self.assertRaisesRegex(V.IncidentRollbackEvidenceError, "full protected provenance"):
            validate(*values, include_stage_attestation=False)
        with self.assertRaisesRegex(V.IncidentRollbackEvidenceError, "full protected provenance"):
            validate(*values, include_restore_attestation=False)
        with self.assertRaisesRegex(V.IncidentRollbackEvidenceError, "full protected provenance"):
            validate(*values, include_publisher_attestation=False)

    def test_rollback_receipt_and_actual_tree_are_bound(self) -> None:
        values = list(recorded())
        assert values[5] is not None
        values[5]["sourceGitTree"] = "e" * 40
        values[6] = encoded(values[5])
        values[0]["source"]["rollbackPublisherReceiptSha256"] = hashlib.sha256(values[6]).hexdigest()
        values[0]["rollback"]["rollbackTreeSha"] = values[5]["sourceGitTree"]
        with self.assertRaisesRegex(V.IncidentRollbackEvidenceError, "actual source tree"):
            validate(*values)

        values = list(recorded())
        assert values[5] is not None
        values[5]["digest"] = values[0]["source"]["imageDigest"]
        values[6] = encoded(values[5])
        values[0]["source"]["rollbackPublisherReceiptSha256"] = hashlib.sha256(values[6]).hexdigest()
        values[0]["rollback"]["rollbackImageDigest"] = values[5]["digest"]
        with self.assertRaisesRegex(V.IncidentRollbackEvidenceError, "must differ"):
            validate(*values)

    def test_deployment_identities_are_exact(self) -> None:
        values = list(recorded())
        values[0]["rollback"]["beforeDeploymentId"] = values[0]["rollback"]["rollbackDeploymentId"]
        with self.assertRaisesRegex(V.IncidentRollbackEvidenceError, "exactly bind"):
            validate(*values)

        values = list(recorded())
        values[0]["rollback"]["rollbackDeploymentId"] = "production"
        with self.assertRaisesRegex(V.IncidentRollbackEvidenceError, "exactly bind"):
            validate(*values)

    def test_scenario_reference_and_timestamps_fail_closed(self) -> None:
        values = list(recorded())
        values[0]["incident"]["incidentId"] = "https://private.example/?token=secret"
        with self.assertRaisesRegex(V.IncidentRollbackEvidenceError, "non-secret reference"):
            validate(*values)

        values = list(recorded())
        values[0]["incident"]["scenario"] = "production_outage"
        with self.assertRaisesRegex(V.IncidentRollbackEvidenceError, "controlled-stage scenario"):
            validate(*values)

        values = list(recorded())
        values[0]["incident"]["rollbackStartedAtUtc"] = "2026-09-04T13:02:00Z"
        with self.assertRaisesRegex(V.IncidentRollbackEvidenceError, "fully ordered"):
            validate(*values)

        values = list(recorded())
        assert values[3] is not None
        values[3]["approval"]["approvedAtUtc"] = "2026-09-04T13:30:00Z"
        values[4] = encoded(values[3])
        values[0]["source"]["restoreEvidenceSha256"] = hashlib.sha256(values[4]).hexdigest()
        with self.assertRaisesRegex(V.IncidentRollbackEvidenceError, "fully ordered"):
            validate(*values)

    def test_measured_detection_and_rto_are_reconciled(self) -> None:
        values = list(recorded())
        values[0]["incident"]["observedDetectionSeconds"] = 61
        with self.assertRaisesRegex(V.IncidentRollbackEvidenceError, "ordered timestamps"):
            validate(*values)

        values = list(recorded())
        values[0]["incident"]["observedRtoSeconds"] = 3000
        with self.assertRaisesRegex(V.IncidentRollbackEvidenceError, "ordered timestamps"):
            validate(*values)

        values = list(recorded())
        values[0]["incident"]["expectedRtoSeconds"] = True
        with self.assertRaisesRegex(V.IncidentRollbackEvidenceError, "strict bounded"):
            validate(*values)

    def test_failed_controls_require_defects(self) -> None:
        values = list(recorded())
        del values[0]["controls"]["schemaCompatible"]
        with self.assertRaisesRegex(V.IncidentRollbackEvidenceError, "keys mismatch"):
            validate(*values)

        values = list(recorded())
        block(values[0], "schemaCompatible", "validation_failed")
        values[0]["incident"]["defectIssueNumbers"] = []
        with self.assertRaisesRegex(V.IncidentRollbackEvidenceError, "require a defect"):
            validate(*values)
        values[0]["incident"]["defectIssueNumbers"] = [569]
        validate(*values)

    def test_cleanup_and_approval_are_safe_and_ordered(self) -> None:
        values = list(recorded())
        values[0]["cleanup"]["failureInjectionRemoved"] = False
        with self.assertRaisesRegex(V.IncidentRollbackEvidenceError, "APPROVED requires"):
            validate(*values)

        values = list(recorded())
        values[0]["cleanup"]["evidenceContainsPersonalData"] = {"subject": "secret"}
        with self.assertRaisesRegex(V.IncidentRollbackEvidenceError, "strict booleans"):
            validate(*values)

        values = list(recorded())
        values[0]["approval"]["approvedAtUtc"] = "2026-09-04T13:59:59Z"
        with self.assertRaisesRegex(V.IncidentRollbackEvidenceError, "must not precede"):
            validate(*values)

    def test_incident_claims_require_exact_final_attestation(self) -> None:
        values = recorded()
        with self.assertRaisesRegex(V.IncidentRollbackEvidenceError, "protected attestation bundle"):
            validate(*values, include_incident_attestation=False)

        def reject(*_args: Any) -> None:
            raise V.IncidentRollbackEvidenceError("evidenceAttestation: rejected")

        with self.assertRaisesRegex(V.IncidentRollbackEvidenceError, "rejected"):
            validate(*values, incident_verifier=reject)

    def test_duplicate_json_keys_are_rejected(self) -> None:
        with self.assertRaisesRegex(V.IncidentRollbackEvidenceError, "duplicate JSON key"):
            json.loads('{"schemaVersion":"one","schemaVersion":"two"}', object_pairs_hook=V._unique)


if __name__ == "__main__":
    unittest.main()
