#!/usr/bin/env python3
from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
import unittest
from pathlib import Path
from typing import Any

import test_verify_signed_candidate_evidence as SIGNED_TEST


MODULE = Path(__file__).with_name("verify_internal_track_evidence.py")
SPEC = importlib.util.spec_from_file_location("internal_track_evidence", MODULE)
assert SPEC and SPEC.loader
V = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(V)
ROOT = Path(__file__).resolve().parents[2]
TEMPLATE = ROOT / "docs/evidence/internal-track-validation-template.json"
CANDIDATE_ATTESTATION = b"protected-signed-candidate-attestation"
TRACK_ATTESTATION = b"protected-internal-track-attestation"


def encoded(value: dict[str, Any]) -> bytes:
    return json.dumps(value, separators=(",", ":")).encode()


def template() -> dict[str, Any]:
    return json.loads(TEMPLATE.read_text(encoding="utf-8"))


def candidate(ready: bool = True) -> dict[str, Any]:
    value = SIGNED_TEST.recorded(ready)
    for platform in value["platforms"]:
        if platform["status"] == "READY":
            platform["version"] = "0.2.0"
            platform["buildNumber"] = "2"
    return value


def recorded(validated: bool = True, candidate_value: dict[str, Any] | None = None) -> tuple[dict[str, Any], dict[str, Any], bytes]:
    candidate_value = copy.deepcopy(candidate_value or candidate())
    candidate_bytes = encoded(candidate_value)
    value = template()
    value.update({
        "recordStatus": "RECORDED",
        "overallStatus": "VALIDATED" if validated else "BLOCKED",
        "recordedAtUtc": "2026-09-04T10:30:00Z",
    })
    value["candidate"] = {
        "repository": "MKSEgr/walking-rpg",
        "signedCandidateEvidenceSha256": hashlib.sha256(candidate_bytes).hexdigest(),
        "signedCandidateEvidenceAttestationSha256": hashlib.sha256(CANDIDATE_ATTESTATION).hexdigest(),
        "candidateStatus": candidate_value["overallStatus"],
        "sourceCommitSha": candidate_value["source"]["commitSha"],
        "sourceTreeSha": candidate_value["source"]["treeSha"],
    }
    device = {"ios": "iphone_physical", "android": "android_physical"}
    os_version = {"ios": "26.0", "android": "16"}
    value["platforms"] = []
    for signed_platform in candidate_value["platforms"]:
        platform = signed_platform["platform"]
        value["platforms"].append({
            "platform": platform,
            "status": "VALIDATED",
            "applicationId": signed_platform["applicationId"],
            "artifactSha256": signed_platform["artifactSha256"],
            "version": signed_platform["version"],
            "buildNumber": signed_platform["buildNumber"],
            "distributionTrack": signed_platform["distributionTrack"],
            "deviceCategory": device[platform],
            "osVersion": os_version[platform],
            "previousVersion": "0.1.0",
            "previousBuildNumber": "1",
            "startedAtUtc": "2026-09-04T09:00:00Z",
            "completedAtUtc": "2026-09-04T10:00:00Z",
            "scenarioResults": {key: "PASS" for key in V.SCENARIOS},
            "defectIssueNumbers": [],
            "ownerRole": "release_validator",
            "nextActionDueAtUtc": None,
            "blockerCategory": None,
        })
    value["cleanup"] = {
        "localTestDataRemoved": True,
        "temporaryAccessRevoked": True,
        "secretExposureDetected": False,
        "personalDataRetained": False,
    }
    value["approval"] = {
        "status": "APPROVED",
        "releaseOwnerRole": "release_owner",
        "approvedAtUtc": "2026-09-04T11:00:00Z",
    }
    if not validated:
        block_without_run(value, 0)
        block_without_run(value, 1)
        value["approval"] = {
            "status": "BLOCKED",
            "releaseOwnerRole": None,
            "approvedAtUtc": None,
        }
    return value, candidate_value, candidate_bytes


def block_without_run(value: dict[str, Any], index: int, category: str = "device_unavailable") -> None:
    platform = value["platforms"][index]
    platform.update({
        "status": "BLOCKED",
        "deviceCategory": None,
        "osVersion": None,
        "previousVersion": None,
        "previousBuildNumber": None,
        "startedAtUtc": None,
        "completedAtUtc": None,
        "scenarioResults": {key: "NOT_RUN" for key in V.SCENARIOS},
        "defectIssueNumbers": [],
        "ownerRole": "release_validator",
        "nextActionDueAtUtc": "2026-09-10T10:00:00Z",
        "blockerCategory": category,
    })


def validate(
    value: dict[str, Any],
    candidate_value: dict[str, Any],
    candidate_bytes: bytes,
    *,
    require_validated: bool = False,
    include_track_attestation: bool = True,
    candidate_validator: Any = None,
    evidence_verifier: Any = None,
) -> None:
    V.validate(
        value,
        require_recorded=True,
        require_validated=require_validated,
        signed_candidate=candidate_value,
        signed_candidate_bytes=candidate_bytes,
        signed_candidate_attestation=CANDIDATE_ATTESTATION,
        evidence_bytes=encoded(value),
        evidence_attestation=(TRACK_ATTESTATION if include_track_attestation else None),
        candidate_validator=candidate_validator or (lambda *_args, **_kwargs: None),
        evidence_attestation_verifier=evidence_verifier or (lambda *_args: None),
    )


class InternalTrackEvidenceTest(unittest.TestCase):
    def test_template_is_valid_but_not_recorded_or_validated(self) -> None:
        V.validate(template())
        with self.assertRaisesRegex(V.InternalTrackEvidenceError, "recorded evidence"):
            V.validate(template(), require_recorded=True)
        with self.assertRaisesRegex(V.InternalTrackEvidenceError, "RECORDED VALIDATED"):
            V.validate(template(), require_validated=True)

    def test_validated_record_passes_and_requires_ready_candidate(self) -> None:
        value, candidate_value, candidate_bytes = recorded()
        calls: list[dict[str, Any]] = []

        def candidate_validator(_candidate: dict[str, Any], **kwargs: Any) -> None:
            calls.append(kwargs)

        validate(
            value,
            candidate_value,
            candidate_bytes,
            require_validated=True,
            candidate_validator=candidate_validator,
        )
        self.assertTrue(calls[0]["require_recorded"])
        self.assertTrue(calls[0]["require_ready"])

    def test_unrun_blocker_is_recorded_but_not_validated(self) -> None:
        value, candidate_value, candidate_bytes = recorded(False)
        V.validate(
            value,
            require_recorded=True,
            signed_candidate=candidate_value,
            signed_candidate_bytes=candidate_bytes,
            signed_candidate_attestation=CANDIDATE_ATTESTATION,
            candidate_validator=lambda *_args, **_kwargs: None,
        )
        with self.assertRaisesRegex(V.InternalTrackEvidenceError, "RECORDED VALIDATED"):
            validate(value, candidate_value, candidate_bytes, require_validated=True)

    def test_candidate_bytes_attestation_and_platform_tuple_are_bound(self) -> None:
        value, candidate_value, candidate_bytes = recorded()
        value["candidate"]["signedCandidateEvidenceSha256"] = "a" * 64
        with self.assertRaisesRegex(V.InternalTrackEvidenceError, "signed-candidate bytes"):
            validate(value, candidate_value, candidate_bytes)

        value, candidate_value, candidate_bytes = recorded()
        value["candidate"]["signedCandidateEvidenceAttestationSha256"] = "b" * 64
        with self.assertRaisesRegex(V.InternalTrackEvidenceError, "attestation bundle"):
            validate(value, candidate_value, candidate_bytes)

        value, candidate_value, candidate_bytes = recorded()
        value["platforms"][0]["artifactSha256"] = "c" * 64
        with self.assertRaisesRegex(V.InternalTrackEvidenceError, "signed-candidate platform"):
            validate(value, candidate_value, candidate_bytes)

        value, candidate_value, candidate_bytes = recorded()
        value["platforms"][1]["applicationId"] = "com.example.other"
        with self.assertRaisesRegex(V.InternalTrackEvidenceError, "signed-candidate platform"):
            validate(value, candidate_value, candidate_bytes)

        value, candidate_value, candidate_bytes = recorded()
        value["platforms"][1]["buildNumber"] = "3"
        with self.assertRaisesRegex(V.InternalTrackEvidenceError, "signed-candidate platform"):
            validate(value, candidate_value, candidate_bytes)

        value, candidate_value, candidate_bytes = recorded()
        value["candidate"]["sourceTreeSha"] = "d" * 40
        with self.assertRaisesRegex(V.InternalTrackEvidenceError, "exactly identify"):
            validate(value, candidate_value, candidate_bytes)

    def test_both_platforms_and_exact_scenarios_are_required(self) -> None:
        value, candidate_value, candidate_bytes = recorded()
        value["platforms"] = value["platforms"][:1]
        with self.assertRaisesRegex(V.InternalTrackEvidenceError, "exactly iOS and Android"):
            validate(value, candidate_value, candidate_bytes)

        value, candidate_value, candidate_bytes = recorded()
        del value["platforms"][0]["scenarioResults"]["ownerIsolation"]
        with self.assertRaisesRegex(V.InternalTrackEvidenceError, "keys mismatch"):
            validate(value, candidate_value, candidate_bytes)

        value, candidate_value, candidate_bytes = recorded()
        value["platforms"][1]["platform"] = "ios"
        with self.assertRaisesRegex(V.InternalTrackEvidenceError, "uniquely identify"):
            validate(value, candidate_value, candidate_bytes)

    def test_upgrade_and_run_times_fail_closed(self) -> None:
        value, candidate_value, candidate_bytes = recorded()
        value["platforms"][0]["previousBuildNumber"] = "2"
        with self.assertRaisesRegex(V.InternalTrackEvidenceError, "precede the candidate"):
            validate(value, candidate_value, candidate_bytes)

        value, candidate_value, candidate_bytes = recorded()
        value["platforms"][0]["completedAtUtc"] = "2026-09-04T12:00:00Z"
        with self.assertRaisesRegex(V.InternalTrackEvidenceError, "finish by recordedAtUtc"):
            validate(value, candidate_value, candidate_bytes)

        value, candidate_value, candidate_bytes = recorded(False)
        value["platforms"][0]["previousVersion"] = "0.1.0"
        with self.assertRaisesRegex(V.InternalTrackEvidenceError, "unrun upgrade"):
            validate(value, candidate_value, candidate_bytes)

    def test_failed_run_requires_defect_and_protected_attestation(self) -> None:
        value, candidate_value, candidate_bytes = recorded()
        value["overallStatus"] = "BLOCKED"
        value["approval"] = {"status": "BLOCKED", "releaseOwnerRole": None, "approvedAtUtc": None}
        platform = value["platforms"][0]
        platform.update({
            "status": "BLOCKED",
            "blockerCategory": "upgrade_failed",
            "nextActionDueAtUtc": "2026-09-10T10:00:00Z",
        })
        platform["scenarioResults"]["upgrade"] = "FAIL"
        with self.assertRaisesRegex(V.InternalTrackEvidenceError, "failed scenarios require a defect"):
            validate(value, candidate_value, candidate_bytes)

        platform["defectIssueNumbers"] = [564]
        with self.assertRaisesRegex(V.InternalTrackEvidenceError, "protected attestation bundle"):
            validate(
                value,
                candidate_value,
                candidate_bytes,
                include_track_attestation=False,
            )

    def test_attestation_covers_exact_track_record(self) -> None:
        value, candidate_value, candidate_bytes = recorded()
        with self.assertRaisesRegex(V.InternalTrackEvidenceError, "exact recorded evidence bytes"):
            V.validate(
                value,
                signed_candidate=candidate_value,
                signed_candidate_bytes=candidate_bytes,
                signed_candidate_attestation=CANDIDATE_ATTESTATION,
                candidate_validator=lambda *_args, **_kwargs: None,
            )

        def reject(*_args: Any) -> None:
            raise V.InternalTrackEvidenceError("evidenceAttestation: rejected")

        with self.assertRaisesRegex(V.InternalTrackEvidenceError, "rejected"):
            validate(
                value,
                candidate_value,
                candidate_bytes,
                evidence_verifier=reject,
            )

    def test_cleanup_approval_and_safe_metadata_are_strict(self) -> None:
        value, candidate_value, candidate_bytes = recorded()
        value["cleanup"]["personalDataRetained"] = {"path": "/private/user"}
        value["overallStatus"] = "BLOCKED"
        value["approval"] = {"status": "BLOCKED", "releaseOwnerRole": None, "approvedAtUtc": None}
        with self.assertRaisesRegex(V.InternalTrackEvidenceError, "strict booleans"):
            validate(value, candidate_value, candidate_bytes)

        value, candidate_value, candidate_bytes = recorded()
        value["platforms"][0]["osVersion"] = "26/private-device"
        with self.assertRaisesRegex(V.InternalTrackEvidenceError, "bounded numeric OS version"):
            validate(value, candidate_value, candidate_bytes)

        value, candidate_value, candidate_bytes = recorded()
        value["approval"]["approvedAtUtc"] = "2026-09-04T09:30:00Z"
        with self.assertRaisesRegex(V.InternalTrackEvidenceError, "must not precede recording"):
            validate(value, candidate_value, candidate_bytes)

    def test_blocked_candidate_cannot_produce_physical_claims(self) -> None:
        candidate_value = candidate(False)
        value, candidate_value, candidate_bytes = recorded(False, candidate_value)
        for index, signed_platform in enumerate(candidate_value["platforms"]):
            value["platforms"][index]["blockerCategory"] = "candidate_not_ready"
            if signed_platform["status"] == "BLOCKED":
                value["platforms"][index].update({
                    "applicationId": signed_platform["applicationId"],
                    "artifactSha256": None,
                    "version": None,
                    "buildNumber": None,
                    "distributionTrack": None,
                })
        calls: list[dict[str, Any]] = []
        validate(
            value,
            candidate_value,
            candidate_bytes,
            candidate_validator=lambda _candidate, **kwargs: calls.append(kwargs),
        )
        self.assertFalse(calls[0]["require_ready"])

        blocked_index = next(
            index
            for index, platform in enumerate(candidate_value["platforms"])
            if platform["status"] == "BLOCKED"
        )
        value["platforms"][blocked_index]["scenarioResults"]["launch"] = "PASS"
        with self.assertRaisesRegex(V.InternalTrackEvidenceError, "physical claims require a READY"):
            validate(value, candidate_value, candidate_bytes)


if __name__ == "__main__":
    unittest.main()
