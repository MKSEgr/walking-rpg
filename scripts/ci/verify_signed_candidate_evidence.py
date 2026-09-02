#!/usr/bin/env python3
"""Fail-closed validator for protected signed mobile candidate evidence."""

from __future__ import annotations
import argparse
import hashlib
import json
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

import verify_store_account_readiness as accounts

SCHEMA = "walking-rpg-signed-candidate-v1"
TOP = {"schemaVersion", "recordStatus", "overallStatus", "recordedAtUtc", "source", "platforms", "cleanup", "approval"}
SOURCE = {"repository", "commitSha", "treeSha", "approvedPrHeadTreeSha", "ciConclusion", "releaseQualityConclusion", "accountReadinessSha256"}
PLATFORM = {"platform", "status", "applicationId", "artifactType", "artifactSha256", "verifierReceiptSha256", "publicCertificateFingerprintSha256", "signatureVerified", "version", "buildNumber", "toolchain", "distributionTrack", "installableByInternalAudience", "ownerRole", "nextActionDueAtUtc", "blockerCategory"}
RECEIPT = {"platform", "artifactSha256", "publicCertificateFingerprintSha256", "signatureVerified", "verifier", "verifierVersion", "verifiedAtUtc"}
CLEANUP = {"temporaryMaterialRemoved", "ordinaryCiHadSigningAccess", "secretExposureDetected"}
APPROVAL = {"status", "releaseOwnerRole", "approvedAtUtc"}
SHA = re.compile(r"^[0-9a-f]{40}$"); SHA256 = re.compile(r"^[0-9a-f]{64}$"); UTC = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
BLOCKERS = {"account_not_ready", "signing_access_unavailable", "protected_runner_unavailable", "distribution_unavailable", "signature_verification_failed", "cleanup_unconfirmed", "other_coarse"}

class SignedCandidateError(ValueError): pass
def _fail(path: str, message: str) -> None: raise SignedCandidateError(f"{path}: {message}")
def _object(value: Any, path: str, keys: set[str]) -> dict[str, Any]:
    if not isinstance(value, dict): _fail(path, "must be an object")
    missing, unknown = sorted(keys - value.keys()), sorted(value.keys() - keys)
    if missing or unknown: _fail(path, f"keys mismatch; missing={missing}, unknown={unknown}")
    return value
def _time(value: Any, path: str) -> datetime:
    if not isinstance(value, str) or not UTC.fullmatch(value): _fail(path, "must be an exact UTC timestamp")
    return datetime.fromisoformat(value.replace("Z", "+00:00"))
def _digest(value: Any, path: str) -> None:
    if not isinstance(value, str) or not SHA256.fullmatch(value) or value == "0" * 64: _fail(path, "must be a real lowercase SHA-256")

def _git(repo: Path, *args: str) -> str:
    result = subprocess.run(["git", *args], cwd=repo, text=True, capture_output=True, check=False)
    if result.returncode != 0: _fail("source", f"git {' '.join(args)} failed")
    return result.stdout.strip()

def _source_identities(repo: Path, commit: str) -> dict[str, str]:
    gradle = _git(repo, "show", f"{commit}:mobile/android/app/build.gradle.kts")
    xcode = _git(repo, "show", f"{commit}:mobile/ios/Runner.xcodeproj/project.pbxproj")
    android = set(re.findall(r'applicationId\s*=\s*"([^"]+)"', gradle))
    ios = {value for value in re.findall(r"PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;]+);", xcode) if not value.endswith(".RunnerTests")}
    if len(android) != 1 or len(ios) != 1: _fail("source", "claimed commit must expose exact mobile identities")
    return {"android": next(iter(android)), "ios": next(iter(ios))}

def validate(data: Any, *, require_recorded: bool = False, require_ready: bool = False,
             account: Any = None, account_sha256: str | None = None,
             repository_root: Path | None = None, artifacts: dict[str, bytes] | None = None,
             receipts: dict[str, bytes] | None = None) -> None:
    root = _object(data, "$", TOP); record, overall = root["recordStatus"], root["overallStatus"]
    if root["schemaVersion"] != SCHEMA: _fail("schemaVersion", f"must equal {SCHEMA!r}")
    if record not in {"TEMPLATE", "RECORDED"} or overall not in {"OWNER_INPUT_REQUIRED", "READY", "BLOCKED"}: _fail("$", "invalid status")
    if require_recorded and record != "RECORDED": _fail("recordStatus", "recorded evidence is required")
    if require_ready and (record != "RECORDED" or overall != "READY"): _fail("overallStatus", "RECORDED READY evidence is required")
    source = _object(root["source"], "source", SOURCE); cleanup = _object(root["cleanup"], "cleanup", CLEANUP); approval = _object(root["approval"], "approval", APPROVAL)
    platforms = root["platforms"]
    if not isinstance(platforms, list): _fail("platforms", "must be an array")
    if record == "TEMPLATE":
        if overall != "OWNER_INPUT_REQUIRED" or root["recordedAtUtc"] is not None or any(source.values()) or platforms or any(value is not None for value in cleanup.values()) or approval != {"status": "OWNER_INPUT_REQUIRED", "releaseOwnerRole": None, "approvedAtUtc": None}: _fail("$", "committed TEMPLATE must remain empty")
        return
    recorded_at = _time(root["recordedAtUtc"], "recordedAtUtc")
    if not isinstance(source["commitSha"], str) or not SHA.fullmatch(source["commitSha"]): _fail("source.commitSha", "must be a lowercase commit SHA")
    if not isinstance(source["treeSha"], str) or not SHA.fullmatch(source["treeSha"]): _fail("source.treeSha", "must be a lowercase tree SHA")
    _digest(source["accountReadinessSha256"], "source.accountReadinessSha256")
    if account is None or account_sha256 != source["accountReadinessSha256"]: _fail("source.accountReadinessSha256", "must match supplied account-readiness bytes")
    repo = repository_root or Path(__file__).resolve().parents[2]
    if source["repository"] != "MKSEgr/walking-rpg": _fail("source.repository", "must identify the approved repository")
    master_sha = _git(repo, "rev-parse", "refs/remotes/origin/master")
    if source["commitSha"] != master_sha: _fail("source.commitSha", "must equal the current origin/master commit")
    actual_tree = _git(repo, "rev-parse", f'{source["commitSha"]}^{{tree}}')
    if source["treeSha"] != actual_tree or source["approvedPrHeadTreeSha"] != actual_tree: _fail("source.treeSha", "source and approved PR-head trees must equal the actual master tree")
    if source["ciConclusion"] != "success" or source["releaseQualityConclusion"] != "success": _fail("source", "CI and Release quality must both be successful")
    if len(platforms) != 2: _fail("platforms", "must contain exactly iOS and Android")
    expected_ids = _source_identities(repo, source["commitSha"]); ready = True; seen = set()
    for index, raw in enumerate(platforms):
        path = f"platforms[{index}]"; item = _object(raw, path, PLATFORM); platform = item["platform"]
        if platform not in {"ios", "android"} or platform in seen: _fail(f"{path}.platform", "must uniquely identify ios or android")
        seen.add(platform); expected = expected_ids[platform]
        if item["applicationId"] != expected: _fail(f"{path}.applicationId", "must match candidate configuration")
        if item["artifactType"] != ("ipa" if platform == "ios" else "aab"): _fail(f"{path}.artifactType", "must match platform")
        if item["status"] == "READY":
            for key in ("artifactSha256", "verifierReceiptSha256", "publicCertificateFingerprintSha256"): _digest(item[key], f"{path}.{key}")
            artifact_bytes = (artifacts or {}).get(platform); receipt_bytes = (receipts or {}).get(platform)
            if artifact_bytes is None or hashlib.sha256(artifact_bytes).hexdigest() != item["artifactSha256"]: _fail(path, "artifact digest must match supplied artifact bytes")
            if receipt_bytes is None or hashlib.sha256(receipt_bytes).hexdigest() != item["verifierReceiptSha256"]: _fail(path, "receipt digest must match supplied verifier receipt bytes")
            try: receipt = _object(json.loads(receipt_bytes, object_pairs_hook=_unique), f"{path}.receipt", RECEIPT)
            except (UnicodeError, json.JSONDecodeError) as error: _fail(f"{path}.receipt", f"must be strict JSON: {error}")
            if receipt["platform"] != platform or receipt["artifactSha256"] != item["artifactSha256"] or receipt["publicCertificateFingerprintSha256"] != item["publicCertificateFingerprintSha256"] or receipt["signatureVerified"] is not True: _fail(f"{path}.receipt", "must confirm this platform artifact, fingerprint and signature")
            if not isinstance(receipt["verifier"], str) or not receipt["verifier"] or not isinstance(receipt["verifierVersion"], str) or not receipt["verifierVersion"]: _fail(f"{path}.receipt", "must identify the signature verifier and version")
            _time(receipt["verifiedAtUtc"], f"{path}.receipt.verifiedAtUtc")
            if item["signatureVerified"] is not True or item["installableByInternalAudience"] is not True: _fail(path, "READY requires verified signature and internal availability")
            for key in ("version", "buildNumber", "toolchain", "distributionTrack"):
                if not isinstance(item[key], str) or not item[key].strip(): _fail(f"{path}.{key}", "must be non-empty")
            if item["ownerRole"] != "release_owner" or item["nextActionDueAtUtc"] is not None or item["blockerCategory"] is not None: _fail(path, "READY owner/blocker fields are inconsistent")
        elif item["status"] == "BLOCKED":
            ready = False
            if any(item[key] is not None for key in ("artifactSha256", "verifierReceiptSha256", "publicCertificateFingerprintSha256")) or item["signatureVerified"] is not False or item["installableByInternalAudience"] is not False: _fail(path, "BLOCKED must not claim artifact evidence")
            if item["blockerCategory"] not in BLOCKERS: _fail(f"{path}.blockerCategory", "must be an approved coarse blocker")
            _time(item["nextActionDueAtUtc"], f"{path}.nextActionDueAtUtc")
        else: _fail(f"{path}.status", "must be READY or BLOCKED")
    if any(type(value) is not bool for value in cleanup.values()): _fail("cleanup", "recorded cleanup values must be strict booleans")
    account_blocked = any(item["status"] == "BLOCKED" and item["blockerCategory"] == "account_not_ready" for item in platforms)
    try: accounts.validate(account, require_recorded=True, require_ready=not account_blocked, repository_root=repo)
    except accounts.AccountReadinessError as error: _fail("accountReadiness", f"has incompatible status: {error}")
    safe_cleanup = cleanup == {"temporaryMaterialRemoved": True, "ordinaryCiHadSigningAccess": False, "secretExposureDetected": False}
    if not safe_cleanup: ready = False
    if approval["status"] == "APPROVED" and approval["releaseOwnerRole"] == "release_owner":
        if _time(approval["approvedAtUtc"], "approval.approvedAtUtc") < recorded_at: _fail("approval.approvedAtUtc", "must not precede recording")
    else: ready = False
    if overall != ("READY" if ready else "BLOCKED"): _fail("overallStatus", "must match artifact, cleanup and approval outcomes")

def _unique(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result = {}
    for key, value in pairs:
        if key in result: raise SignedCandidateError(f"duplicate JSON key: {key}")
        result[key] = value
    return result
def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("evidence", type=Path); parser.add_argument("--account-readiness", type=Path); parser.add_argument("--ios-artifact", type=Path); parser.add_argument("--android-artifact", type=Path); parser.add_argument("--ios-verifier-receipt", type=Path); parser.add_argument("--android-verifier-receipt", type=Path); parser.add_argument("--require-recorded", action="store_true"); parser.add_argument("--require-ready", action="store_true"); args = parser.parse_args(argv)
    try:
        evidence = json.loads(args.evidence.read_text(encoding="utf-8"), object_pairs_hook=_unique); account_bytes = args.account_readiness.read_bytes() if args.account_readiness else None; account = json.loads(account_bytes, object_pairs_hook=_unique) if account_bytes else None
        artifact_paths = {"ios": args.ios_artifact, "android": args.android_artifact}; receipt_paths = {"ios": args.ios_verifier_receipt, "android": args.android_verifier_receipt}
        artifacts = {key: path.read_bytes() for key, path in artifact_paths.items() if path}; receipts = {key: path.read_bytes() for key, path in receipt_paths.items() if path}
        validate(evidence, require_recorded=args.require_recorded, require_ready=args.require_ready, account=account, account_sha256=hashlib.sha256(account_bytes).hexdigest() if account_bytes else None, artifacts=artifacts, receipts=receipts)
    except (OSError, UnicodeError, json.JSONDecodeError, SignedCandidateError) as error: print(f"Signed candidate evidence invalid: {error}", file=sys.stderr); return 1
    print(f"Signed candidate evidence valid: {args.evidence}"); return 0
if __name__ == "__main__": raise SystemExit(main())
