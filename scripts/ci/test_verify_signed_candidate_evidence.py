#!/usr/bin/env python3
from __future__ import annotations
import hashlib
import importlib.util
import json
import subprocess
import unittest
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
def recorded(ready: bool = True) -> dict:
    data = template(); data.update({"recordStatus": "RECORDED", "overallStatus": "READY" if ready else "BLOCKED", "recordedAtUtc": "2026-09-02T10:00:00Z"})
    data["source"] = {"commitSha": git("rev-parse", "HEAD"), "treeSha": git("rev-parse", "HEAD^{tree}"), "accountReadinessSha256": hashlib.sha256(account_bytes()).hexdigest()}
    ids = {"ios": "com.walkingrpg.walkingRpgMobile", "android": "com.walkingrpg.walking_rpg_mobile"}
    data["platforms"] = [{"platform": platform, "status": "READY", "applicationId": ids[platform], "artifactType": "ipa" if platform == "ios" else "aab", "artifactSha256": "a" * 64, "publicCertificateFingerprintSha256": "b" * 64, "signatureVerified": True, "version": "0.1.0", "buildNumber": "1", "toolchain": "protected-current", "distributionTrack": "internal", "installableByInternalAudience": True, "ownerRole": "release_owner", "nextActionDueAtUtc": None, "blockerCategory": None} for platform in ("ios", "android")]
    data["cleanup"] = {"temporaryMaterialRemoved": True, "ordinaryCiHadSigningAccess": False, "secretExposureDetected": False}
    data["approval"] = {"status": "APPROVED", "releaseOwnerRole": "release_owner", "approvedAtUtc": "2026-09-02T11:00:00Z"}
    if not ready:
        data["platforms"][0].update({"status": "BLOCKED", "artifactSha256": None, "publicCertificateFingerprintSha256": None, "signatureVerified": False, "installableByInternalAudience": False, "nextActionDueAtUtc": "2026-09-10T10:00:00Z", "blockerCategory": "signing_access_unavailable"})
    return data
def validate(data: dict, ready: bool = False) -> None: V.validate(data, require_recorded=True, require_ready=ready, account=account(), account_sha256=hashlib.sha256(account_bytes()).hexdigest(), repository_root=ROOT)

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
        with self.assertRaisesRegex(V.SignedCandidateError, "actual Git tree"): validate(data)
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
if __name__ == "__main__": unittest.main()
