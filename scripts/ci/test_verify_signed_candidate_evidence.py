#!/usr/bin/env python3
from __future__ import annotations
import hashlib
import importlib.util
import io
import json
import plistlib
import subprocess
import unittest
import zipfile
from pathlib import Path

import test_verify_store_account_readiness as ACCOUNT_TEST

MODULE = Path(__file__).with_name("verify_signed_candidate_evidence.py")
SPEC = importlib.util.spec_from_file_location("signed_candidate", MODULE)
assert SPEC and SPEC.loader
V = importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(V)
ROOT = Path(__file__).resolve().parents[2]
TEMPLATE = ROOT / "docs/evidence/signed-candidate-template.json"
def template() -> dict: return json.loads(TEMPLATE.read_text(encoding="utf-8"))
def account() -> dict: return ACCOUNT_TEST.recorded()
def account_bytes() -> bytes: return json.dumps(account(), separators=(",", ":")).encode()
def git(*args: str) -> str: return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()
def source_commit() -> str: return git("rev-parse", "HEAD")
def artifacts() -> dict[str, bytes]: return {"ios": b"synthetic-ipa-fixture", "android": b"synthetic-aab-fixture"}
def receipt(platform: str, artifact_sha: str, fingerprint: str) -> bytes:
    return json.dumps({"platform": platform, "artifactSha256": artifact_sha, "publicCertificateFingerprintSha256": fingerprint, "signatureVerified": True, "verifier": "fixture-verifier", "verifierVersion": "1", "verifiedAtUtc": "2026-09-02T10:30:00Z"}, separators=(",", ":")).encode()
def receipts() -> dict[str, bytes]:
    values = {}
    for platform, content in artifacts().items(): values[platform] = receipt(platform, hashlib.sha256(content).hexdigest(), "b" * 64)
    return values
def encoded(value: dict) -> bytes: return json.dumps(value, separators=(",", ":")).encode()
def artifact_metadata(platform: str, _: bytes) -> dict[str, str]:
    ids = {"ios": "com.walkingrpg.walkingRpgMobile", "android": "com.walkingrpg.walking_rpg_mobile"}
    return {"applicationId": ids[platform], "version": "0.1.0", "buildNumber": "1"}
def trust() -> dict:
    return {"github_state": {"masterSha": source_commit(), "successfulWorkflows": {"CI", "Release quality"}}, "artifact_attestation_verifier": lambda repository, commit, artifact, bundle: None, "evidence_attestation_verifier": lambda repository, commit, evidence, bundle: None, "fingerprint_extractor": lambda platform, artifact: "b" * 64, "metadata_extractor": artifact_metadata}
def recorded(ready: bool = True) -> dict:
    data = template(); data.update({"recordStatus": "RECORDED", "overallStatus": "READY" if ready else "BLOCKED", "recordedAtUtc": "2026-09-02T10:00:00Z"})
    commit = source_commit(); tree = git("rev-parse", "HEAD^{tree}")
    data["source"] = {"repository": "MKSEgr/walking-rpg", "commitSha": commit, "treeSha": tree, "approvedPrHeadTreeSha": tree, "ciConclusion": "success", "releaseQualityConclusion": "success", "accountReadinessSha256": hashlib.sha256(account_bytes()).hexdigest()}
    ids = {"ios": "com.walkingrpg.walkingRpgMobile", "android": "com.walkingrpg.walking_rpg_mobile"}
    data["platforms"] = [{"platform": platform, "status": "READY", "applicationId": ids[platform], "artifactType": "ipa" if platform == "ios" else "aab", "artifactSha256": hashlib.sha256(artifacts()[platform]).hexdigest(), "verifierReceiptSha256": hashlib.sha256(receipts()[platform]).hexdigest(), "publicCertificateFingerprintSha256": "b" * 64, "signatureVerified": True, "version": "0.1.0", "buildNumber": "1", "toolchain": "flutter_3.35.0+xcode_26.0" if platform == "ios" else "flutter_3.35.0+android-sdk_36", "distributionTrack": "testflight_internal" if platform == "ios" else "play_internal", "installableByInternalAudience": True, "ownerRole": "release_owner", "nextActionDueAtUtc": None, "blockerCategory": None} for platform in ("ios", "android")]
    data["cleanup"] = {"temporaryMaterialRemoved": True, "ordinaryCiHadSigningAccess": False, "secretExposureDetected": False}
    data["approval"] = {"status": "APPROVED", "releaseOwnerRole": "release_owner", "approvedAtUtc": "2026-09-02T11:00:00Z"}
    if not ready:
        data["platforms"][0].update({"status": "BLOCKED", "artifactSha256": None, "verifierReceiptSha256": None, "publicCertificateFingerprintSha256": None, "signatureVerified": False, "version": None, "buildNumber": None, "toolchain": None, "distributionTrack": None, "installableByInternalAudience": False, "nextActionDueAtUtc": "2026-09-10T10:00:00Z", "blockerCategory": "signing_access_unavailable"})
    return data
def validate(data: dict, ready: bool = False, account_value: dict | None = None) -> None: V.validate(data, require_recorded=True, require_ready=ready, account=account_value or account(), account_sha256=hashlib.sha256(json.dumps(account_value or account(), separators=(",", ":")).encode()).hexdigest(), repository_root=ROOT, artifacts=artifacts(), receipts=receipts(), evidence_bytes=encoded(data), evidence_receipt=b"protected-evidence-attestation", **trust())

class SignedCandidateTest(unittest.TestCase):
    def test_template_is_valid_but_not_ready(self) -> None:
        V.validate(template())
        with self.assertRaises(V.SignedCandidateError): V.validate(template(), require_ready=True)
    def test_ready_record_passes(self) -> None: validate(recorded(), True)
    def test_blocked_record_is_honest_but_not_ready(self) -> None:
        validate(recorded(False))
        with self.assertRaises(V.SignedCandidateError): validate(recorded(False), True)
    def test_git_tree_and_account_digest_are_bound(self) -> None:
        data = recorded(); data["source"]["treeSha"] = "f" * 40
        with self.assertRaisesRegex(V.SignedCandidateError, "actual master tree"): validate(data)
        data = recorded(); data["source"]["accountReadinessSha256"] = "c" * 64
        with self.assertRaisesRegex(V.SignedCandidateError, "supplied account"): validate(data)
    def test_signature_cleanup_and_both_platforms_are_required(self) -> None:
        data = recorded(); data["platforms"][0]["signatureVerified"] = False
        with self.assertRaisesRegex(V.SignedCandidateError, "verified signature"): validate(data)
        data = recorded(); data["cleanup"]["ordinaryCiHadSigningAccess"] = True; data["overallStatus"] = "BLOCKED"
        validate(data)
        with self.assertRaises(V.SignedCandidateError): validate(data, True)
        data = recorded(); data["platforms"] = data["platforms"][:1]
        with self.assertRaisesRegex(V.SignedCandidateError, "exactly iOS and Android"): validate(data)
    def test_artifact_and_verifier_receipt_bytes_are_required(self) -> None:
        data = recorded()
        with self.assertRaisesRegex(V.SignedCandidateError, "artifact digest"):
            V.validate(data, account=account(), account_sha256=hashlib.sha256(account_bytes()).hexdigest(), repository_root=ROOT, **trust())
        bad = dict(artifacts()); bad["ios"] = b"different"
        with self.assertRaisesRegex(V.SignedCandidateError, "artifact digest"):
            V.validate(data, account=account(), account_sha256=hashlib.sha256(account_bytes()).hexdigest(), repository_root=ROOT, artifacts=bad, receipts=receipts(), **trust())
    def test_account_not_ready_can_remain_blocked(self) -> None:
        blocked_account = ACCOUNT_TEST.recorded(False); blocked_bytes = json.dumps(blocked_account, separators=(",", ":")).encode()
        data = recorded(False); data["platforms"][1].update({"status": "BLOCKED", "artifactSha256": None, "verifierReceiptSha256": None, "publicCertificateFingerprintSha256": None, "signatureVerified": False, "version": None, "buildNumber": None, "toolchain": None, "distributionTrack": None, "installableByInternalAudience": False, "nextActionDueAtUtc": "2026-09-10T10:00:00Z", "blockerCategory": "account_not_ready"}); data["source"]["accountReadinessSha256"] = hashlib.sha256(blocked_bytes).hexdigest()
        validate(data, account_value=blocked_account)
        data["platforms"][0]["blockerCategory"] = "account_not_ready"
        with self.assertRaisesRegex(V.SignedCandidateError, "apple account must be blocked"): validate(data, account_value=blocked_account)
    def test_external_github_state_and_attestation_are_required(self) -> None:
        data = recorded()
        with self.assertRaisesRegex(V.SignedCandidateError, "GitHub's current master"):
            V.validate(data, account=account(), account_sha256=hashlib.sha256(account_bytes()).hexdigest(), repository_root=ROOT, artifacts=artifacts(), receipts=receipts(), github_state={"masterSha": "f" * 40, "successfulWorkflows": {"CI", "Release quality"}}, artifact_attestation_verifier=lambda *_: None)
        def reject(*_: object) -> None: raise V.SignedCandidateError("attestation: rejected")
        with self.assertRaisesRegex(V.SignedCandidateError, "attestation: rejected"):
            V.validate(data, account=account(), account_sha256=hashlib.sha256(account_bytes()).hexdigest(), repository_root=ROOT, artifacts=artifacts(), receipts=receipts(), github_state={"masterSha": source_commit(), "successfulWorkflows": {"CI", "Release quality"}}, artifact_attestation_verifier=reject, fingerprint_extractor=lambda *_: "b" * 64)
    def test_fingerprint_and_approval_shapes_are_strict(self) -> None:
        data = recorded()
        with self.assertRaisesRegex(V.SignedCandidateError, "fingerprint must match"):
            V.validate(data, account=account(), account_sha256=hashlib.sha256(account_bytes()).hexdigest(), repository_root=ROOT, artifacts=artifacts(), receipts=receipts(), github_state=trust()["github_state"], artifact_attestation_verifier=trust()["artifact_attestation_verifier"], fingerprint_extractor=lambda *_: "c" * 64)
        data = recorded(False); data["approval"] = {"status": {}, "releaseOwnerRole": [], "approvedAtUtc": {"secret": "value"}}
        with self.assertRaisesRegex(V.SignedCandidateError, "exact BLOCKED or APPROVED"): validate(data)
    def test_only_successful_push_workflows_are_trusted(self) -> None:
        runs = [{"name": "CI", "head_sha": source_commit(), "event": "workflow_dispatch", "conclusion": "success"}, {"name": "Release quality", "head_sha": source_commit(), "event": "push", "conclusion": "success"}]
        self.assertEqual(V._successful_push_workflows(runs, source_commit()), {"Release quality"})
    def test_cleanup_values_are_strict_booleans(self) -> None:
        data = recorded(False); data["cleanup"]["temporaryMaterialRemoved"] = {"path": "/private/key"}
        with self.assertRaisesRegex(V.SignedCandidateError, "strict booleans"): validate(data)
    def test_artifact_identity_version_and_build_are_extracted(self) -> None:
        data = recorded()
        def wrong_metadata(platform: str, artifact: bytes) -> dict[str, str]:
            result = artifact_metadata(platform, artifact); result["applicationId"] = "com.example.other"; return result
        with self.assertRaisesRegex(V.SignedCandidateError, "artifact identity"):
            V.validate(data, account=account(), account_sha256=hashlib.sha256(account_bytes()).hexdigest(), repository_root=ROOT, artifacts=artifacts(), receipts=receipts(), evidence_bytes=encoded(data), evidence_receipt=b"protected-evidence-attestation", metadata_extractor=wrong_metadata, **{key: value for key, value in trust().items() if key != "metadata_extractor"})
        ipa = io.BytesIO()
        with zipfile.ZipFile(ipa, "w") as archive:
            archive.writestr("Payload/Runner.app/Info.plist", plistlib.dumps({"CFBundleIdentifier": "com.walkingrpg.walkingRpgMobile", "CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "1"}))
        self.assertEqual(V._artifact_metadata("ios", ipa.getvalue()), artifact_metadata("ios", b""))
    def test_internal_availability_requires_attested_exact_evidence(self) -> None:
        data = recorded()
        with self.assertRaisesRegex(V.SignedCandidateError, "exact recorded evidence bytes"):
            V.validate(data, account=account(), account_sha256=hashlib.sha256(account_bytes()).hexdigest(), repository_root=ROOT, artifacts=artifacts(), receipts=receipts(), **trust())
        with self.assertRaisesRegex(V.SignedCandidateError, "attestation: rejected"):
            V.validate(data, account=account(), account_sha256=hashlib.sha256(account_bytes()).hexdigest(), repository_root=ROOT, artifacts=artifacts(), receipts=receipts(), evidence_bytes=encoded(data), evidence_receipt=b"untrusted", **{**trust(), "evidence_attestation_verifier": lambda *_: (_ for _ in ()).throw(V.SignedCandidateError("attestation: rejected"))})
    def test_platform_metadata_is_secret_free_and_bounded(self) -> None:
        data = recorded(); data["platforms"][0]["toolchain"] = "/private/keychain/token"
        with self.assertRaisesRegex(V.SignedCandidateError, "without paths or credentials"): validate(data)
        data = recorded(); data["platforms"][1]["distributionTrack"] = "secret-token"
        with self.assertRaisesRegex(V.SignedCandidateError, "exact internal store track"): validate(data)
        data = recorded(False); data["platforms"][0]["toolchain"] = {"path": "/private/key"}
        with self.assertRaisesRegex(V.SignedCandidateError, "must not retain"): validate(data)
if __name__ == "__main__": unittest.main()
