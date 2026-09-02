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
SOURCE = {"commitSha", "treeSha", "accountReadinessSha256"}
PLATFORM = {"platform", "status", "applicationId", "artifactType", "artifactSha256", "publicCertificateFingerprintSha256", "signatureVerified", "version", "buildNumber", "toolchain", "distributionTrack", "installableByInternalAudience", "ownerRole", "nextActionDueAtUtc", "blockerCategory"}
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

def validate(data: Any, *, require_recorded: bool = False, require_ready: bool = False,
             account: Any = None, account_sha256: str | None = None,
             repository_root: Path | None = None) -> None:
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
    try: accounts.validate(account, require_ready=True, repository_root=repository_root)
    except accounts.AccountReadinessError as error: _fail("accountReadiness", f"must be READY: {error}")
    repo = repository_root or Path(__file__).resolve().parents[2]
    resolved = subprocess.run(["git", "rev-parse", f'{source["commitSha"]}^{{tree}}'], cwd=repo, text=True, capture_output=True, check=False)
    if resolved.returncode != 0 or resolved.stdout.strip() != source["treeSha"]: _fail("source.treeSha", "must be the actual Git tree of source.commitSha")
    if len(platforms) != 2: _fail("platforms", "must contain exactly iOS and Android")
    expected_ids, _ = accounts._candidate_identities(repo); ready = True; seen = set()
    for index, raw in enumerate(platforms):
        path = f"platforms[{index}]"; item = _object(raw, path, PLATFORM); platform = item["platform"]
        if platform not in {"ios", "android"} or platform in seen: _fail(f"{path}.platform", "must uniquely identify ios or android")
        seen.add(platform); expected = expected_ids["apple" if platform == "ios" else "google"]
        if item["applicationId"] != expected: _fail(f"{path}.applicationId", "must match candidate configuration")
        if item["artifactType"] != ("ipa" if platform == "ios" else "aab"): _fail(f"{path}.artifactType", "must match platform")
        if item["status"] == "READY":
            for key in ("artifactSha256", "publicCertificateFingerprintSha256"): _digest(item[key], f"{path}.{key}")
            if item["signatureVerified"] is not True or item["installableByInternalAudience"] is not True: _fail(path, "READY requires verified signature and internal availability")
            for key in ("version", "buildNumber", "toolchain", "distributionTrack"):
                if not isinstance(item[key], str) or not item[key].strip(): _fail(f"{path}.{key}", "must be non-empty")
            if item["ownerRole"] != "release_owner" or item["nextActionDueAtUtc"] is not None or item["blockerCategory"] is not None: _fail(path, "READY owner/blocker fields are inconsistent")
        elif item["status"] == "BLOCKED":
            ready = False
            if any(item[key] is not None for key in ("artifactSha256", "publicCertificateFingerprintSha256")) or item["signatureVerified"] is not False or item["installableByInternalAudience"] is not False: _fail(path, "BLOCKED must not claim artifact evidence")
            if item["blockerCategory"] not in BLOCKERS: _fail(f"{path}.blockerCategory", "must be an approved coarse blocker")
            _time(item["nextActionDueAtUtc"], f"{path}.nextActionDueAtUtc")
        else: _fail(f"{path}.status", "must be READY or BLOCKED")
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
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("evidence", type=Path); parser.add_argument("--account-readiness", type=Path); parser.add_argument("--require-recorded", action="store_true"); parser.add_argument("--require-ready", action="store_true"); args = parser.parse_args(argv)
    try:
        evidence = json.loads(args.evidence.read_text(encoding="utf-8"), object_pairs_hook=_unique); account_bytes = args.account_readiness.read_bytes() if args.account_readiness else None; account = json.loads(account_bytes, object_pairs_hook=_unique) if account_bytes else None
        validate(evidence, require_recorded=args.require_recorded, require_ready=args.require_ready, account=account, account_sha256=hashlib.sha256(account_bytes).hexdigest() if account_bytes else None)
    except (OSError, UnicodeError, json.JSONDecodeError, SignedCandidateError) as error: print(f"Signed candidate evidence invalid: {error}", file=sys.stderr); return 1
    print(f"Signed candidate evidence valid: {args.evidence}"); return 0
if __name__ == "__main__": raise SystemExit(main())
