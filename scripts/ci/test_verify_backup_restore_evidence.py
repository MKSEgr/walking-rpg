#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import importlib.util
import json
import subprocess
import unittest
from pathlib import Path
from typing import Any

import test_verify_stage_deployment_evidence as stage_fixture


MODULE = Path(__file__).with_name("verify_backup_restore_evidence.py")
SPEC = importlib.util.spec_from_file_location("backup_restore_evidence", MODULE)
assert SPEC and SPEC.loader
V = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(V)
ROOT = Path(__file__).resolve().parents[2]
TEMPLATE = ROOT / "docs/evidence/backup-restore-drill-template.json"
STAGE_ATTESTATION = b"protected-stage-evidence-attestation"
RESTORE_ATTESTATION = b"protected-backup-restore-attestation"


def encoded(value: dict[str, Any]) -> bytes:
    return json.dumps(value, separators=(",", ":")).encode()


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def template() -> dict[str, Any]:
    return json.loads(TEMPLATE.read_text(encoding="utf-8"))


def recorded(
    validated: bool = True,
    with_claims: bool = True,
) -> tuple[dict[str, Any], dict[str, Any] | None, bytes | None]:
    value = template()
    value.update({
        "recordStatus": "RECORDED",
        "overallStatus": "VALIDATED" if validated else "BLOCKED",
        "recordedAtUtc": "2026-09-04T12:00:00Z",
    })
    if not with_claims:
        value["backup"] = {key: None for key in V.BACKUP}
        value["backup"]["status"] = "NOT_RUN"
        value["target"] = {key: None for key in V.TARGET}
        value["target"]["status"] = "NOT_RUN"
        value["drill"] = {key: None for key in V.DRILL}
        value["drill"].update({
            "status": "BLOCKED",
            "ownerRole": "database_operations_owner",
            "nextActionDueAtUtc": "2026-09-10T12:00:00Z",
            "blockerCategory": "backup_unavailable",
            "defectIssueNumbers": [],
        })
        value["controls"] = {key: "NOT_RUN" for key in V.CONTROLS}
        value["cleanup"] = {
            "targetDisposition": "NOT_APPLICABLE",
            "targetRetentionPolicyRef": None,
            "temporaryCredentialsRevoked": True,
            "temporaryArchiveCopiesRemoved": True,
            "secretExposureDetected": False,
            "evidenceContainsPersonalData": False,
        }
        value["approval"] = {
            "status": "BLOCKED",
            "operationsOwnerRole": None,
            "approvedAtUtc": None,
        }
        return value, None, None

    stage_value, _, _ = stage_fixture.recorded()
    stage_bytes = encoded(stage_value)
    stage_source = stage_value["source"]
    value["source"] = {
        "repository": V.REPOSITORY,
        "commitSha": stage_source["commitSha"],
        "treeSha": stage_source["treeSha"],
        "image": V.IMAGE,
        "imageDigest": stage_source["imageDigest"],
        "stageEvidenceSha256": hashlib.sha256(stage_bytes).hexdigest(),
        "stageEvidenceAttestationSha256": hashlib.sha256(
            STAGE_ATTESTATION
        ).hexdigest(),
    }
    value["backup"] = {
        "status": "AVAILABLE",
        "backupId": "do-db-backup-20260904t101500z",
        "archiveSha256": "b" * 64,
        "createdAtUtc": "2026-09-04T08:00:00Z",
        "recoveryPointUtc": "2026-09-04T10:15:00Z",
        "retentionPolicyRef": "managed-postgres-pitr-v1",
        "encryptionAtRest": True,
        "pitrEnabled": True,
    }
    value["target"] = {
        "status": "RESTORED",
        "targetId": "12345678-1234-4abc-8def-1234567890ab",
        "provider": "digitalocean",
        "region": "fra",
        "isolatedFromProduction": True,
        "productionTrafficDisabled": True,
        "sourceUnchanged": True,
        "postgresVersion": "17",
        "highestFlywayVersion": V._highest_flyway(ROOT),
    }
    value["drill"] = {
        "status": "VALIDATED",
        "startedAtUtc": "2026-09-04T11:00:00Z",
        "restoreCompletedAtUtc": "2026-09-04T11:20:00Z",
        "validationCompletedAtUtc": "2026-09-04T11:40:00Z",
        "cleanupCompletedAtUtc": "2026-09-04T11:50:00Z",
        "expectedRpoSeconds": 3600,
        "observedRpoSeconds": 2700,
        "expectedRtoSeconds": 3600,
        "observedRtoSeconds": 2400,
        "ownerRole": "database_operations_owner",
        "nextActionDueAtUtc": None,
        "blockerCategory": None,
        "defectIssueNumbers": [],
    }
    value["controls"] = {key: "PASS" for key in V.CONTROLS}
    value["cleanup"] = {
        "targetDisposition": "DISPOSED",
        "targetRetentionPolicyRef": None,
        "temporaryCredentialsRevoked": True,
        "temporaryArchiveCopiesRemoved": True,
        "secretExposureDetected": False,
        "evidenceContainsPersonalData": False,
    }
    value["approval"] = {
        "status": "APPROVED",
        "operationsOwnerRole": "operations_owner",
        "approvedAtUtc": "2026-09-04T12:05:00Z",
    }
    if not validated:
        block(value, "applicationReady", "validation_failed")
    return value, stage_value, stage_bytes


def block(value: dict[str, Any], control: str, category: str) -> None:
    value["overallStatus"] = "BLOCKED"
    value["controls"][control] = "FAIL"
    value["drill"].update({
        "status": "BLOCKED",
        "nextActionDueAtUtc": "2026-09-10T12:00:00Z",
        "blockerCategory": category,
        "defectIssueNumbers": [567],
    })
    value["approval"] = {
        "status": "BLOCKED",
        "operationsOwnerRole": None,
        "approvedAtUtc": None,
    }


def validate(
    value: dict[str, Any],
    stage_value: dict[str, Any] | None,
    stage_bytes: bytes | None,
    *,
    require_validated: bool = False,
    include_stage_attestation: bool = True,
    include_restore_attestation: bool = True,
    github_state: dict[str, Any] | None = None,
    stage_verifier: Any = None,
    restore_verifier: Any = None,
) -> None:
    claims = V._has_restore_claims(value["controls"])
    V.validate(
        value,
        require_recorded=True,
        require_validated=require_validated,
        stage_evidence=stage_value,
        stage_evidence_bytes=stage_bytes,
        stage_evidence_attestation=(
            STAGE_ATTESTATION
            if claims and include_stage_attestation
            else None
        ),
        evidence_bytes=encoded(value),
        evidence_attestation=(
            RESTORE_ATTESTATION
            if claims and include_restore_attestation
            else None
        ),
        repository_root=ROOT,
        github_state=github_state or {
            "masterSha": git("rev-parse", "HEAD"),
            "successfulWorkflows": {"CI", "Release quality"},
        },
        stage_attestation_verifier=stage_verifier or (lambda *_args: None),
        evidence_attestation_verifier=restore_verifier or (lambda *_args: None),
    )


class BackupRestoreEvidenceTest(unittest.TestCase):
    def test_template_is_valid_but_not_recorded_or_validated(self) -> None:
        V.validate(template())
        with self.assertRaisesRegex(V.BackupRestoreEvidenceError, "recorded evidence"):
            V.validate(template(), require_recorded=True)
        with self.assertRaisesRegex(V.BackupRestoreEvidenceError, "RECORDED VALIDATED"):
            V.validate(template(), require_validated=True)

    def test_complete_record_passes_both_attestation_boundaries(self) -> None:
        value, stage_value, stage_bytes = recorded()
        calls: list[str] = []
        validate(
            value,
            stage_value,
            stage_bytes,
            require_validated=True,
            stage_verifier=lambda *_args: calls.append("stage"),
            restore_verifier=lambda *_args: calls.append("restore"),
        )
        self.assertEqual(calls, ["stage", "restore"])

    def test_no_run_blocker_has_no_external_claims(self) -> None:
        value, stage_value, stage_bytes = recorded(False, False)
        validate(
            value,
            stage_value,
            stage_bytes,
            include_stage_attestation=False,
            include_restore_attestation=False,
        )
        with self.assertRaisesRegex(V.BackupRestoreEvidenceError, "RECORDED VALIDATED"):
            validate(
                value,
                stage_value,
                stage_bytes,
                require_validated=True,
                include_stage_attestation=False,
                include_restore_attestation=False,
            )

    def test_stage_record_bytes_source_and_attestation_are_bound(self) -> None:
        value, stage_value, stage_bytes = recorded()
        value["source"]["stageEvidenceSha256"] = "c" * 64
        with self.assertRaisesRegex(V.BackupRestoreEvidenceError, "exactly identify"):
            validate(value, stage_value, stage_bytes)

        value, stage_value, stage_bytes = recorded()
        assert stage_value is not None
        stage_value["overallStatus"] = "BLOCKED"
        stage_bytes = encoded(stage_value)
        value["source"]["stageEvidenceSha256"] = hashlib.sha256(stage_bytes).hexdigest()
        with self.assertRaisesRegex(V.BackupRestoreEvidenceError, "RECORDED VALIDATED stage"):
            validate(value, stage_value, stage_bytes)

        value, stage_value, stage_bytes = recorded()
        value["source"]["stageEvidenceAttestationSha256"] = None
        with self.assertRaisesRegex(V.BackupRestoreEvidenceError, "exact protected stage evidence"):
            validate(
                value,
                stage_value,
                stage_bytes,
                include_stage_attestation=False,
            )

    def test_stage_must_be_current_master_with_successful_checks(self) -> None:
        value, stage_value, stage_bytes = recorded()
        with self.assertRaisesRegex(V.BackupRestoreEvidenceError, "current master"):
            validate(
                value,
                stage_value,
                stage_bytes,
                github_state={
                    "masterSha": "d" * 40,
                    "successfulWorkflows": {"CI", "Release quality"},
                },
            )
        with self.assertRaisesRegex(V.BackupRestoreEvidenceError, "Release quality"):
            validate(
                value,
                stage_value,
                stage_bytes,
                github_state={
                    "masterSha": git("rev-parse", "HEAD"),
                    "successfulWorkflows": {"CI"},
                },
            )

    def test_backup_identity_and_boolean_fields_fail_closed(self) -> None:
        value, stage_value, stage_bytes = recorded()
        value["backup"]["backupId"] = "https://private.example/backup?token=secret"
        with self.assertRaisesRegex(V.BackupRestoreEvidenceError, "non-secret reference"):
            validate(value, stage_value, stage_bytes)

        value, stage_value, stage_bytes = recorded()
        value["backup"]["retentionPolicyRef"] = "policy/../../private"
        with self.assertRaisesRegex(V.BackupRestoreEvidenceError, "non-secret reference"):
            validate(value, stage_value, stage_bytes)

        value, stage_value, stage_bytes = recorded()
        value["backup"]["archiveSha256"] = "0" * 64
        with self.assertRaisesRegex(V.BackupRestoreEvidenceError, "real lowercase SHA-256"):
            validate(value, stage_value, stage_bytes)

        value, stage_value, stage_bytes = recorded()
        value["backup"]["pitrEnabled"] = 1
        with self.assertRaisesRegex(V.BackupRestoreEvidenceError, "strict booleans"):
            validate(value, stage_value, stage_bytes)

    def test_target_identity_and_repository_flyway_are_exact(self) -> None:
        value, stage_value, stage_bytes = recorded()
        value["target"]["targetId"] = "production-db"
        with self.assertRaisesRegex(V.BackupRestoreEvidenceError, "provider UUID"):
            validate(value, stage_value, stage_bytes)

        value, stage_value, stage_bytes = recorded()
        value["target"]["highestFlywayVersion"] -= 1
        with self.assertRaisesRegex(V.BackupRestoreEvidenceError, "repository-current"):
            validate(value, stage_value, stage_bytes)

        value, stage_value, stage_bytes = recorded()
        value["target"]["highestFlywayVersion"] = True
        with self.assertRaisesRegex(V.BackupRestoreEvidenceError, "strict integer"):
            validate(value, stage_value, stage_bytes)

    def test_time_order_and_measured_recovery_targets_are_enforced(self) -> None:
        value, stage_value, stage_bytes = recorded()
        value["drill"]["validationCompletedAtUtc"] = "2026-09-04T11:10:00Z"
        with self.assertRaisesRegex(V.BackupRestoreEvidenceError, "fully ordered"):
            validate(value, stage_value, stage_bytes)

        value, stage_value, stage_bytes = recorded()
        value["drill"]["observedRtoSeconds"] = 7200
        with self.assertRaisesRegex(V.BackupRestoreEvidenceError, "ordered timestamps"):
            validate(value, stage_value, stage_bytes)

        value, stage_value, stage_bytes = recorded()
        value["drill"]["expectedRpoSeconds"] = True
        with self.assertRaisesRegex(V.BackupRestoreEvidenceError, "strict bounded"):
            validate(value, stage_value, stage_bytes)

    def test_failed_controls_require_defects_and_block_approval(self) -> None:
        value, stage_value, stage_bytes = recorded()
        del value["controls"]["roleAclValid"]
        with self.assertRaisesRegex(V.BackupRestoreEvidenceError, "keys mismatch"):
            validate(value, stage_value, stage_bytes)

        value, stage_value, stage_bytes = recorded()
        block(value, "roleAclValid", "validation_failed")
        value["drill"]["defectIssueNumbers"] = []
        with self.assertRaisesRegex(V.BackupRestoreEvidenceError, "require a defect"):
            validate(value, stage_value, stage_bytes)
        value["drill"]["defectIssueNumbers"] = [567]
        validate(value, stage_value, stage_bytes)

    def test_cleanup_and_approval_must_be_safe_and_ordered(self) -> None:
        value, stage_value, stage_bytes = recorded()
        value["cleanup"]["temporaryCredentialsRevoked"] = False
        with self.assertRaisesRegex(V.BackupRestoreEvidenceError, "APPROVED requires"):
            validate(value, stage_value, stage_bytes)

        value, stage_value, stage_bytes = recorded()
        value["cleanup"]["evidenceContainsPersonalData"] = {"subject": "secret"}
        with self.assertRaisesRegex(V.BackupRestoreEvidenceError, "strict booleans"):
            validate(value, stage_value, stage_bytes)

        value, stage_value, stage_bytes = recorded()
        value["cleanup"]["targetDisposition"] = "RETAINED_BY_POLICY"
        with self.assertRaisesRegex(V.BackupRestoreEvidenceError, "non-secret reference"):
            validate(value, stage_value, stage_bytes)

        value, stage_value, stage_bytes = recorded()
        value["approval"]["approvedAtUtc"] = "2026-09-04T11:59:59Z"
        with self.assertRaisesRegex(V.BackupRestoreEvidenceError, "must not precede"):
            validate(value, stage_value, stage_bytes)

    def test_restore_claims_require_exact_final_attestation(self) -> None:
        value, stage_value, stage_bytes = recorded()
        with self.assertRaisesRegex(V.BackupRestoreEvidenceError, "exact evidence bytes"):
            V.validate(
                value,
                stage_evidence=stage_value,
                stage_evidence_bytes=stage_bytes,
                stage_evidence_attestation=STAGE_ATTESTATION,
                repository_root=ROOT,
                github_state={
                    "masterSha": git("rev-parse", "HEAD"),
                    "successfulWorkflows": {"CI", "Release quality"},
                },
                stage_attestation_verifier=lambda *_args: None,
            )

        with self.assertRaisesRegex(V.BackupRestoreEvidenceError, "protected attestation bundle"):
            validate(
                value,
                stage_value,
                stage_bytes,
                include_restore_attestation=False,
            )

        def reject(*_args: Any) -> None:
            raise V.BackupRestoreEvidenceError("evidenceAttestation: rejected")

        with self.assertRaisesRegex(V.BackupRestoreEvidenceError, "rejected"):
            validate(
                value,
                stage_value,
                stage_bytes,
                restore_verifier=reject,
            )

    def test_duplicate_json_keys_are_rejected(self) -> None:
        with self.assertRaisesRegex(V.BackupRestoreEvidenceError, "duplicate JSON key"):
            json.loads('{"schemaVersion":"one","schemaVersion":"two"}', object_pairs_hook=V._unique)


if __name__ == "__main__":
    unittest.main()
