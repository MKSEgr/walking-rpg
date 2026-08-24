#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("verify_internal_alpha_kickoff.py")
SPEC = importlib.util.spec_from_file_location("internal_alpha_kickoff", MODULE_PATH)
assert SPEC and SPEC.loader
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)

ROOT = Path(__file__).resolve().parents[2]
TEMPLATE_PATH = ROOT / "docs/evidence/internal-alpha-kickoff-template.json"


def template() -> dict:
    return json.loads(TEMPLATE_PATH.read_text(encoding="utf-8"))


def ready() -> dict:
    data = template()
    data.update(
        {
            "recordStatus": "READY",
            "recordedAtUtc": "2026-08-24T09:00:00Z",
            "approvedAtUtc": "2026-08-24T10:00:00Z",
        }
    )
    data["protocol"]["commitSha"] = "a" * 40
    data["candidate"].update(
        {
            "sourceSha": "b" * 40,
            "treeSha": "c" * 40,
            "appVersion": "0.1.1",
            "buildNumber": "2",
            "contentVersion": "chapter-1-v2",
            "remoteConfigVersion": "alpha-v1",
        }
    )
    data["candidate"]["ios"] = {
        "bundleId": "app.walkingrpg.stage",
        "artifactSha256": "d" * 64,
        "distributionTrack": "testflight_internal",
    }
    data["candidate"]["android"] = {
        "applicationId": "app.walkingrpg.stage",
        "artifactSha256": "e" * 64,
        "distributionTrack": "play_internal",
    }
    data["candidate"]["backend"] = {
        "imageDigest": "sha256:" + "f" * 64,
        "deploymentReceiptSha256": "1" * 64,
        "stageEnvironment": "walking-rpg-alpha-eu",
    }
    data["observationWindow"] = {
        "startsAtUtc": "2026-08-24T11:00:00Z",
        "endsAtUtc": "2026-08-24T13:00:00Z",
        "supportUntilUtc": "2026-08-24T14:00:00Z",
    }
    data["evidence"] = {
        "storageCategory": "approved_internal_evidence",
        "redactionPolicy": VALIDATOR.REDACTION_POLICY,
        "participantEvidenceDeleteByUtc": "2026-11-20T13:00:00Z",
        "supportChannelCategory": "approved_private_channel",
    }
    for index, gate in enumerate(data["gates"]):
        gate.update(
            {
                "status": "PASS",
                "checkedAtUtc": "2026-08-24T09:30:00Z",
                "evidenceCategory": "approved_internal_evidence",
                "evidenceDigestSha256": format(index + 2, "x") * 64,
            }
        )
    return data


class InternalAlphaKickoffTest(unittest.TestCase):
    def assert_invalid(self, data: dict, message: str | None = None) -> None:
        with self.assertRaises(VALIDATOR.KickoffValidationError) as context:
            VALIDATOR.validate_kickoff(data)
        if message:
            self.assertIn(message, str(context.exception))

    def test_committed_template_is_structurally_valid(self) -> None:
        VALIDATOR.validate_kickoff(template())

    def test_template_is_not_ready_evidence(self) -> None:
        with self.assertRaises(VALIDATOR.KickoffValidationError):
            VALIDATOR.validate_kickoff(template(), require_ready=True)

    def test_complete_ready_record_is_valid(self) -> None:
        VALIDATOR.validate_kickoff(ready(), require_ready=True)

    def test_unknown_field_fails_closed(self) -> None:
        data = ready()
        data["supportUrl"] = "redacted"
        self.assert_invalid(data, "unknown=['supportUrl']")

    def test_gate_order_and_completeness_are_exact(self) -> None:
        data = ready()
        data["gates"] = list(reversed(data["gates"]))
        self.assert_invalid(data, "mandatory gate")

    def test_ready_record_rejects_blocked_gate(self) -> None:
        data = ready()
        data["gates"][0]["status"] = "BLOCKED"
        self.assert_invalid(data, "requires PASS")

    def test_ready_record_requires_exact_candidate(self) -> None:
        data = ready()
        data["candidate"]["sourceSha"] = None
        self.assert_invalid(data, "lowercase 40-hex")

    def test_artifact_digest_must_be_sha256(self) -> None:
        data = ready()
        data["candidate"]["ios"]["artifactSha256"] = "not-a-digest"
        self.assert_invalid(data, "lowercase SHA-256")

    def test_gate_evidence_digest_must_be_sha256(self) -> None:
        data = ready()
        data["gates"][0]["evidenceDigestSha256"] = "2" * 63
        self.assert_invalid(data, "lowercase SHA-256")

    def test_approval_must_precede_observation_window(self) -> None:
        data = ready()
        data["approvedAtUtc"] = data["observationWindow"]["startsAtUtc"]
        self.assert_invalid(data, "approved < starts")

    def test_support_window_covers_one_hour(self) -> None:
        data = ready()
        data["observationWindow"]["supportUntilUtc"] = "2026-08-24T13:59:59Z"
        self.assert_invalid(data, "at least one hour")

    def test_participant_evidence_retention_is_bounded(self) -> None:
        data = ready()
        data["evidence"]["participantEvidenceDeleteByUtc"] = "2026-11-23T13:00:01Z"
        self.assert_invalid(data, "no more than 90 days")

    def test_version_fields_reject_sensitive_literals(self) -> None:
        data = ready()
        data["candidate"]["remoteConfigVersion"] = "secret_token"
        self.assert_invalid(data, "credential or sensitive identifier")

    def test_candidate_slugs_and_app_ids_reject_sensitive_literals(self) -> None:
        data = ready()
        data["candidate"]["ios"]["distributionTrack"] = "secret_token"
        self.assert_invalid(data, "credential or sensitive identifier")
        data = ready()
        data["candidate"]["android"]["applicationId"] = "app.secret.token"
        self.assert_invalid(data, "credential or sensitive identifier")

    def test_template_cannot_claim_candidate_or_gate_evidence(self) -> None:
        data = template()
        data["candidate"]["sourceSha"] = "b" * 40
        self.assert_invalid(data, "committed template")
        data = template()
        data["gates"][0]["evidenceDigestSha256"] = "2" * 64
        self.assert_invalid(data, "committed template")

    def test_fixed_cohort_cannot_drift(self) -> None:
        data = ready()
        data["cohort"]["plannedParticipants"] = 11
        self.assert_invalid(data, "approved value 12")

    def test_strict_loader_rejects_duplicate_json_keys(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "kickoff.json"
            path.write_text('{"schemaVersion":"a","schemaVersion":"b"}', encoding="utf-8")
            with self.assertRaises(VALIDATOR.KickoffValidationError):
                VALIDATOR.load_kickoff(path)


if __name__ == "__main__":
    unittest.main()
