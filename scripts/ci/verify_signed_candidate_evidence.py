#!/usr/bin/env python3
"""Fail-closed validator for protected signed mobile candidate evidence."""

from __future__ import annotations
import argparse
import hashlib
import io
import json
import os
import plistlib
import re
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
import zipfile
from datetime import datetime
from pathlib import Path
from typing import Any

import verify_store_account_readiness as accounts

SCHEMA = "walking-rpg-signed-candidate-v1"
TOP = {"schemaVersion", "recordStatus", "overallStatus", "recordedAtUtc", "source", "platforms", "cleanup", "approval"}
SOURCE = {"repository", "commitSha", "treeSha", "approvedPrHeadTreeSha", "ciConclusion", "releaseQualityConclusion", "accountReadinessSha256"}
PLATFORM = {"platform", "status", "applicationId", "artifactType", "artifactSha256", "verifierReceiptSha256", "publicCertificateFingerprintSha256", "signatureVerified", "version", "buildNumber", "toolchain", "distributionTrack", "installableByInternalAudience", "ownerRole", "nextActionDueAtUtc", "blockerCategory"}
CLEANUP = {"temporaryMaterialRemoved", "ordinaryCiHadSigningAccess", "secretExposureDetected"}
APPROVAL = {"status", "releaseOwnerRole", "approvedAtUtc"}
SHA = re.compile(r"^[0-9a-f]{40}$"); SHA256 = re.compile(r"^[0-9a-f]{64}$"); UTC = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
VERSION = re.compile(r"^[0-9]+(?:\.[0-9]+){2}(?:[-+][0-9A-Za-z.-]+)?$")
BUILD = re.compile(r"^[1-9][0-9]{0,17}$")
SAFE_TOOLCHAIN = re.compile(r"^[a-z0-9][a-z0-9._+-]{0,159}$")
BLOCKERS = {"account_not_ready", "signing_access_unavailable", "protected_runner_unavailable", "distribution_unavailable", "signature_verification_failed", "cleanup_unconfirmed", "other_coarse"}
ATTESTATION_WORKFLOW = "MKSEgr/walking-rpg/.github/workflows/protected-mobile-signing.yml"
EVIDENCE_ATTESTATION_WORKFLOW = "MKSEgr/walking-rpg/.github/workflows/protected-mobile-evidence.yml"
TRACKS = {"ios": "testflight_internal", "android": "play_internal"}

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

def _unique(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result = {}
    for key, value in pairs:
        if key in result: raise SignedCandidateError(f"duplicate JSON key: {key}")
        result[key] = value
    return result

def _safe_metadata(value: Any, path: str) -> None:
    if not isinstance(value, str) or not SAFE_TOOLCHAIN.fullmatch(value):
        _fail(path, "must be a bounded lowercase toolchain token without paths or credentials")

def _git(repo: Path, *args: str) -> str:
    result = subprocess.run(["git", *args], cwd=repo, text=True, capture_output=True, check=False)
    if result.returncode != 0: _fail("source", f"git {' '.join(args)} failed")
    return result.stdout.strip()

def _source_configuration(repo: Path, commit: str) -> tuple[dict[str, str], str, str, str]:
    gradle = _git(repo, "show", f"{commit}:mobile/android/app/build.gradle.kts")
    xcode = _git(repo, "show", f"{commit}:mobile/ios/Runner.xcodeproj/project.pbxproj")
    plist = _git(repo, "show", f"{commit}:mobile/ios/Runner/Info.plist")
    environment = _git(repo, "show", f"{commit}:mobile/lib/core/config/app_environment.dart")
    pubspec = _git(repo, "show", f"{commit}:mobile/pubspec.yaml")
    android = set(re.findall(r'applicationId\s*=\s*"([^"]+)"', gradle))
    ios = {value for value in re.findall(r"PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;]+);", xcode) if not value.endswith(".RunnerTests")}
    schemes = [set(re.findall(r'"appAuthRedirectScheme"\s+to\s+"([^"]+)"', gradle)), set(re.findall(r"nativeOidcRedirectScheme\s*=\s*'([^']+)'", environment)), set(re.findall(r"<key>CFBundleURLSchemes</key>\s*<array>\s*<string>([^<]+)</string>", plist, re.DOTALL))]
    version_match = re.search(r"^version:\s*([^+\s]+)\+([^\s]+)\s*$", pubspec, re.MULTILINE)
    if len(android) != 1 or len(ios) != 1 or any(len(value) != 1 for value in schemes) or not schemes[0] == schemes[1] == schemes[2]: _fail("source", "claimed commit must expose exact mobile identities and redirect scheme")
    if not version_match or not VERSION.fullmatch(version_match.group(1)) or not BUILD.fullmatch(version_match.group(2)): _fail("source", "claimed commit must expose a safe Flutter version and build number")
    return {"android": next(iter(android)), "ios": next(iter(ios))}, next(iter(schemes[0])), version_match.group(1), version_match.group(2)

def _github_state(repository: str, commit: str) -> dict[str, Any]:
    def get(path: str) -> Any:
        request = urllib.request.Request(f"https://api.github.com/repos/{repository}/{path}", headers={"Accept": "application/vnd.github+json", "User-Agent": "walking-rpg-evidence-validator"})
        with urllib.request.urlopen(request, timeout=30) as response: return json.load(response)
    master = get("git/ref/heads/master")["object"]["sha"]
    runs = get(f"actions/runs?head_sha={commit}&status=completed&per_page=100")["workflow_runs"]
    successful = _successful_push_workflows(runs, commit)
    return {"masterSha": master, "successfulWorkflows": successful}

def _successful_push_workflows(runs: list[dict[str, Any]], commit: str) -> set[str]:
    return {run["name"] for run in runs if run.get("head_sha") == commit and run.get("event") == "push" and run.get("conclusion") == "success"}

def _verify_attestation(repository: str, commit: str, subject: bytes, bundle: bytes,
                        workflow: str, label: str) -> None:
    with tempfile.TemporaryDirectory() as directory:
        subject_path, bundle_path = Path(directory) / "subject", Path(directory) / "bundle.jsonl"
        subject_path.write_bytes(subject); bundle_path.write_bytes(bundle)
        result = subprocess.run(["gh", "attestation", "verify", str(subject_path), "--repo", repository, "--bundle", str(bundle_path), "--signer-workflow", workflow, "--source-digest", commit], text=True, capture_output=True, check=False)
        if result.returncode != 0: _fail("attestation", f"GitHub {label} attestation verification failed")

def _artifact_metadata(platform: str, artifact: bytes) -> dict[str, str]:
    if platform == "ios":
        try:
            with zipfile.ZipFile(io.BytesIO(artifact)) as archive:
                names = [name for name in archive.namelist() if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", name)]
                if len(names) != 1: _fail("artifact", "iOS artifact must contain exactly one application Info.plist")
                plist = plistlib.loads(archive.read(names[0]))
        except (OSError, plistlib.InvalidFileException, zipfile.BadZipFile, KeyError) as error:
            _fail("artifact", f"cannot read iOS application metadata: {error}")
        values = {
            "applicationId": plist.get("CFBundleIdentifier"),
            "version": plist.get("CFBundleShortVersionString"),
            "buildNumber": plist.get("CFBundleVersion"),
        }
    else:
        with tempfile.TemporaryDirectory() as directory:
            artifact_path = Path(directory) / "candidate.aab"
            artifact_path.write_bytes(artifact)
            bundletool_jar = os.environ.get("BUNDLETOOL_JAR")
            command = ["java", "-jar", bundletool_jar] if bundletool_jar else ["bundletool"]
            values = {}
            for key, xpath in {
                "applicationId": "/manifest/@package",
                "version": "/manifest/@android:versionName",
                "buildNumber": "/manifest/@android:versionCode",
            }.items():
                try:
                    result = subprocess.run([*command, "dump", "manifest", f"--bundle={artifact_path}", f"--xpath={xpath}"], text=True, capture_output=True, check=False)
                except OSError as error:
                    _fail("artifact", f"cannot execute bundletool: {error}")
                if result.returncode != 0:
                    _fail("artifact", f"bundletool cannot extract Android {key}")
                values[key] = result.stdout.strip()
    if any(not isinstance(value, str) or not value for value in values.values()):
        _fail("artifact", f"{platform} identity, version and build number must be present")
    return values

def _artifact_fingerprint(platform: str, artifact: bytes) -> str:
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory); artifact_path = root / ("candidate.ipa" if platform == "ios" else "candidate.aab")
        artifact_path.write_bytes(artifact)
        if platform == "android":
            verify = subprocess.run(["jarsigner", "-verify", "-strict", str(artifact_path)], text=True, capture_output=True, check=False)
            details = subprocess.run(["keytool", "-printcert", "-jarfile", str(artifact_path)], text=True, capture_output=True, check=False)
            output = details.stdout + details.stderr
        else:
            unpack = subprocess.run(["unzip", "-q", str(artifact_path), "-d", str(root / "ipa")], text=True, capture_output=True, check=False)
            apps = list((root / "ipa" / "Payload").glob("*.app"))
            if unpack.returncode != 0 or len(apps) != 1: _fail("attestation", "iOS artifact must contain exactly one app")
            verify = subprocess.run(["codesign", "--verify", "--deep", "--strict", str(apps[0])], text=True, capture_output=True, check=False)
            certificate_prefix, certificate = root / "certificate", root / "certificate0"
            details = subprocess.run(["codesign", "-d", f"--extract-certificates={certificate_prefix}", str(apps[0])], text=True, capture_output=True, check=False)
            if details.returncode != 0: _fail("attestation", "cannot extract iOS signing certificate")
            details = subprocess.run(["openssl", "x509", "-inform", "DER", "-in", str(certificate), "-noout", "-fingerprint", "-sha256"], text=True, capture_output=True, check=False)
            output = details.stdout + details.stderr
        if verify.returncode != 0 or details.returncode != 0: _fail("attestation", f"{platform} native signature verification failed")
        match = re.search(r"SHA(?:-?256)?\s*(?:fingerprint)?:?\s*([0-9A-F:]{64,95})", output, re.IGNORECASE)
        if not match: _fail("attestation", f"cannot extract {platform} certificate fingerprint")
        return match.group(1).replace(":", "").lower()

def validate(data: Any, *, require_recorded: bool = False, require_ready: bool = False,
             account: Any = None, account_sha256: str | None = None,
             repository_root: Path | None = None, artifacts: dict[str, bytes] | None = None,
             receipts: dict[str, bytes] | None = None, github_state: dict[str, Any] | None = None,
             evidence_bytes: bytes | None = None, evidence_receipt: bytes | None = None,
             artifact_attestation_verifier: Any = None,
             evidence_attestation_verifier: Any = None,
             fingerprint_extractor: Any = None, metadata_extractor: Any = None) -> None:
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
    remote = _git(repo, "remote", "get-url", "origin")
    if remote.removesuffix(".git") not in {"https://github.com/MKSEgr/walking-rpg", "git@github.com:MKSEgr/walking-rpg"}: _fail("source.repository", "origin must be the canonical GitHub repository")
    state = github_state or _github_state(source["repository"], source["commitSha"])
    if source["commitSha"] != state.get("masterSha"): _fail("source.commitSha", "must equal GitHub's current master commit")
    actual_tree = _git(repo, "rev-parse", f'{source["commitSha"]}^{{tree}}')
    if source["treeSha"] != actual_tree or source["approvedPrHeadTreeSha"] != actual_tree: _fail("source.treeSha", "source and approved PR-head trees must equal the actual master tree")
    if source["ciConclusion"] != "success" or source["releaseQualityConclusion"] != "success" or not {"CI", "Release quality"}.issubset(set(state.get("successfulWorkflows", []))): _fail("source", "GitHub must report successful CI and Release quality runs for the source commit")
    if len(platforms) != 2: _fail("platforms", "must contain exactly iOS and Android")
    mobile_ids, redirect_scheme, source_version, source_build = _source_configuration(repo, source["commitSha"])
    source_configuration = ({"apple": mobile_ids["ios"], "google": mobile_ids["android"]}, redirect_scheme)
    expected_ids = mobile_ids; ready = True; seen = set(); has_ready_platform = False
    for index, raw in enumerate(platforms):
        path = f"platforms[{index}]"; item = _object(raw, path, PLATFORM); platform = item["platform"]
        if platform not in {"ios", "android"} or platform in seen: _fail(f"{path}.platform", "must uniquely identify ios or android")
        seen.add(platform); expected = expected_ids[platform]
        if item["applicationId"] != expected: _fail(f"{path}.applicationId", "must match candidate configuration")
        if item["artifactType"] != ("ipa" if platform == "ios" else "aab"): _fail(f"{path}.artifactType", "must match platform")
        if item["status"] == "READY":
            has_ready_platform = True
            for key in ("artifactSha256", "verifierReceiptSha256", "publicCertificateFingerprintSha256"): _digest(item[key], f"{path}.{key}")
            artifact_bytes = (artifacts or {}).get(platform); receipt_bytes = (receipts or {}).get(platform)
            if artifact_bytes is None or hashlib.sha256(artifact_bytes).hexdigest() != item["artifactSha256"]: _fail(path, "artifact digest must match supplied artifact bytes")
            if receipt_bytes is None or hashlib.sha256(receipt_bytes).hexdigest() != item["verifierReceiptSha256"]: _fail(path, "receipt digest must match supplied verifier receipt bytes")
            verifier = artifact_attestation_verifier or (lambda repository, commit, subject, bundle: _verify_attestation(repository, commit, subject, bundle, ATTESTATION_WORKFLOW, "artifact"))
            verifier(source["repository"], source["commitSha"], artifact_bytes, receipt_bytes)
            fingerprint = (fingerprint_extractor or _artifact_fingerprint)(platform, artifact_bytes)
            if fingerprint != item["publicCertificateFingerprintSha256"]: _fail(path, "certificate fingerprint must match the signed artifact")
            metadata = (metadata_extractor or _artifact_metadata)(platform, artifact_bytes)
            expected_metadata = {"applicationId": expected, "version": source_version, "buildNumber": source_build}
            if metadata != expected_metadata: _fail(path, "artifact identity, version and build number must match the claimed source")
            if item["signatureVerified"] is not True or item["installableByInternalAudience"] is not True: _fail(path, "READY requires verified signature and internal availability")
            if item["version"] != source_version or item["buildNumber"] != source_build: _fail(path, "recorded version/build must match artifact and source")
            _safe_metadata(item["toolchain"], f"{path}.toolchain")
            if item["distributionTrack"] != TRACKS[platform]: _fail(f"{path}.distributionTrack", "must identify the exact internal store track")
            if item["ownerRole"] != "release_owner" or item["nextActionDueAtUtc"] is not None or item["blockerCategory"] is not None: _fail(path, "READY owner/blocker fields are inconsistent")
        elif item["status"] == "BLOCKED":
            ready = False
            if any(item[key] is not None for key in ("artifactSha256", "verifierReceiptSha256", "publicCertificateFingerprintSha256")) or item["signatureVerified"] is not False or item["installableByInternalAudience"] is not False: _fail(path, "BLOCKED must not claim artifact evidence")
            if any(item[key] is not None for key in ("version", "buildNumber", "toolchain", "distributionTrack")): _fail(path, "BLOCKED must not retain artifact or distribution metadata")
            if item["ownerRole"] not in {None, "release_owner"}: _fail(f"{path}.ownerRole", "must be release_owner or null")
            if item["blockerCategory"] not in BLOCKERS: _fail(f"{path}.blockerCategory", "must be an approved coarse blocker")
            _time(item["nextActionDueAtUtc"], f"{path}.nextActionDueAtUtc")
        else: _fail(f"{path}.status", "must be READY or BLOCKED")
    if has_ready_platform:
        if evidence_bytes is None:
            _fail("evidenceAttestation", "exact recorded evidence bytes are required for READY platform claims")
        try:
            decoded_evidence = json.loads(evidence_bytes, object_pairs_hook=_unique)
        except (UnicodeError, json.JSONDecodeError, SignedCandidateError) as error:
            _fail("evidenceAttestation", f"cannot decode exact evidence bytes: {error}")
        if decoded_evidence != data: _fail("evidenceAttestation", "attested evidence bytes must exactly represent this record")
        if evidence_receipt is None: _fail("evidenceAttestation", "protected evidence attestation bundle is required")
        verifier = evidence_attestation_verifier or (lambda repository, commit, subject, bundle: _verify_attestation(repository, commit, subject, bundle, EVIDENCE_ATTESTATION_WORKFLOW, "evidence"))
        verifier(source["repository"], source["commitSha"], evidence_bytes, evidence_receipt)
    if any(type(value) is not bool for value in cleanup.values()): _fail("cleanup", "recorded cleanup values must be strict booleans")
    account_stores = {item.get("platform"): item for item in account.get("stores", [])} if isinstance(account, dict) else {}
    for item in platforms:
        store_platform = "apple" if item["platform"] == "ios" else "google"
        store = account_stores.get(store_platform, {})
        store_ready = store.get("accountStatus") == "VERIFIED" and store.get("appRecordStatus") == "CREATED"
        if item["status"] == "READY" and not store_ready:
            _fail("accountReadiness", f"{store_platform} account must be ready for a READY platform")
        if item["blockerCategory"] == "account_not_ready" and store_ready:
            _fail("accountReadiness", f"{store_platform} account must be blocked for account_not_ready")
    try: accounts.validate(account, require_recorded=True, require_ready=ready,
                           repository_root=repo, candidate_configuration=source_configuration)
    except accounts.AccountReadinessError as error: _fail("accountReadiness", f"has incompatible status: {error}")
    safe_cleanup = cleanup == {"temporaryMaterialRemoved": True, "ordinaryCiHadSigningAccess": False, "secretExposureDetected": False}
    if not safe_cleanup: ready = False
    if approval == {"status": "BLOCKED", "releaseOwnerRole": None, "approvedAtUtc": None}:
        ready = False
    elif approval["status"] == "APPROVED" and approval["releaseOwnerRole"] == "release_owner" and approval["approvedAtUtc"] is not None:
        if _time(approval["approvedAtUtc"], "approval.approvedAtUtc") < recorded_at: _fail("approval.approvedAtUtc", "must not precede recording")
    else: _fail("approval", "must be exact BLOCKED or APPROVED shape")
    if overall != ("READY" if ready else "BLOCKED"): _fail("overallStatus", "must match artifact, cleanup and approval outcomes")

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("evidence", type=Path); parser.add_argument("--account-readiness", type=Path); parser.add_argument("--ios-artifact", type=Path); parser.add_argument("--android-artifact", type=Path); parser.add_argument("--ios-verifier-receipt", type=Path); parser.add_argument("--android-verifier-receipt", type=Path); parser.add_argument("--evidence-attestation", type=Path); parser.add_argument("--require-recorded", action="store_true"); parser.add_argument("--require-ready", action="store_true"); args = parser.parse_args(argv)
    try:
        evidence_bytes = args.evidence.read_bytes(); evidence = json.loads(evidence_bytes, object_pairs_hook=_unique); account_bytes = args.account_readiness.read_bytes() if args.account_readiness else None; account = json.loads(account_bytes, object_pairs_hook=_unique) if account_bytes else None
        artifact_paths = {"ios": args.ios_artifact, "android": args.android_artifact}; receipt_paths = {"ios": args.ios_verifier_receipt, "android": args.android_verifier_receipt}
        artifacts = {key: path.read_bytes() for key, path in artifact_paths.items() if path}; receipts = {key: path.read_bytes() for key, path in receipt_paths.items() if path}
        evidence_receipt = args.evidence_attestation.read_bytes() if args.evidence_attestation else None
        validate(evidence, require_recorded=args.require_recorded, require_ready=args.require_ready, account=account, account_sha256=hashlib.sha256(account_bytes).hexdigest() if account_bytes else None, artifacts=artifacts, receipts=receipts, evidence_bytes=evidence_bytes, evidence_receipt=evidence_receipt)
    except (OSError, UnicodeError, json.JSONDecodeError, urllib.error.URLError, SignedCandidateError) as error: print(f"Signed candidate evidence invalid: {error}", file=sys.stderr); return 1
    print(f"Signed candidate evidence valid: {args.evidence}"); return 0
if __name__ == "__main__": raise SystemExit(main())
