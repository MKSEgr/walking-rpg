#!/usr/bin/env python3
from __future__ import annotations
import importlib.util
import json
import shutil
import tempfile
import unittest
from pathlib import Path

MODULE = Path(__file__).with_name("verify_store_account_readiness.py")
SPEC = importlib.util.spec_from_file_location("account_readiness", MODULE)
assert SPEC and SPEC.loader
V = importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(V)
ROOT = Path(__file__).resolve().parents[2]
TEMPLATE = ROOT / "docs/evidence/store-account-readiness-template.json"

def template() -> dict: return json.loads(TEMPLATE.read_text(encoding="utf-8"))

def recorded(ready: bool = True) -> dict:
    data = template(); data.update({"recordStatus": "RECORDED", "overallStatus": "READY" if ready else "BLOCKED", "recordedAtUtc": "2026-09-02T09:00:00Z", "reviewedAtUtc": "2026-09-02T10:00:00Z", "legalOperatorRole": "legal_operator", "markets": ["global"], "locales": ["en", "ru"]})
    identities = {"apple": "com.walkingrpg.walkingRpgMobile", "google": "com.walkingrpg.walking_rpg_mobile"}
    data["stores"] = [{"platform": platform, "accountType": "organization", "accountStatus": "VERIFIED", "appRecordStatus": "CREATED", "applicationId": identities[platform], "oidcRedirectScheme": "com.walkingrpg.app", "ownerRole": "store_account_owner", "nextActionDueAtUtc": None, "blockerCategory": None} for platform in ("apple", "google")]
    data["publicUrls"] = [{"kind": kind, "status": "READY", "url": f"https://walking-rpg.com/{kind}", "ownerRole": "product_owner", "nextActionDueAtUtc": None, "blockerCategory": None} for kind in ("privacy", "support", "deletion")]
    data["googleClosedTesting"] = {"status": "CONFIRMED", "nextActionDueAtUtc": None, "blockerCategory": None}
    data["approval"] = {"status": "APPROVED", "productOwnerRole": "product_owner", "releaseOwnerRole": "release_owner", "nextActionDueAtUtc": None, "blockerCategory": None}
    if not ready:
        item = data["stores"][1]; item.update({"accountStatus": "BLOCKED", "appRecordStatus": "BLOCKED", "applicationId": None, "oidcRedirectScheme": None, "nextActionDueAtUtc": "2026-09-10T09:00:00Z", "blockerCategory": "verification_pending"})
    return data

class AccountReadinessTest(unittest.TestCase):
    def test_template_is_valid_but_not_recorded_or_ready(self) -> None:
        V.validate(template())
        with self.assertRaises(V.AccountReadinessError): V.validate(template(), require_recorded=True)
        with self.assertRaises(V.AccountReadinessError): V.validate(template(), require_ready=True)
    def test_ready_record_passes(self) -> None: V.validate(recorded(), require_ready=True)
    def test_blocked_record_is_honest_but_not_ready(self) -> None:
        V.validate(recorded(False), require_recorded=True)
        with self.assertRaisesRegex(V.AccountReadinessError, "READY result"): V.validate(recorded(False), require_ready=True)
    def test_final_ids_and_both_stores_are_required(self) -> None:
        data = recorded(); data["stores"][0]["applicationId"] = "com.unrelated.apple"
        with self.assertRaisesRegex(V.AccountReadinessError, "effective candidate"): V.validate(data)
        data = recorded(); data["stores"][1]["oidcRedirectScheme"] = "com.unrelated.app"
        with self.assertRaisesRegex(V.AccountReadinessError, "OIDC redirect"): V.validate(data)
        data = recorded(); data["stores"] = data["stores"][:1]
        with self.assertRaisesRegex(V.AccountReadinessError, "exactly Apple"): V.validate(data)
    def test_urls_and_owner_review_are_required(self) -> None:
        data = recorded(); data["publicUrls"][0]["url"] = "https://localhost/privacy"
        with self.assertRaises(V.store_readiness.StoreReadinessError): V.validate(data)
        data = recorded(); data["approval"]["releaseOwnerRole"] = None
        with self.assertRaisesRegex(V.AccountReadinessError, "product and release"): V.validate(data)
        data = recorded(); data["publicUrls"][0]["url"] = "https://walking-rpg.com/privacy?verification_token=secret"
        with self.assertRaises(V.store_readiness.StoreReadinessError): V.validate(data)
    def test_blocker_metadata_cannot_pose_as_ready(self) -> None:
        data = recorded(); data["stores"][0]["blockerCategory"] = "verification_pending"
        with self.assertRaisesRegex(V.AccountReadinessError, "must not retain"): V.validate(data)

    def test_pending_approval_and_unassigned_owner_can_be_blocked(self) -> None:
        data = recorded(); data["overallStatus"] = "BLOCKED"
        data["approval"] = {"status": "BLOCKED", "productOwnerRole": "product_owner", "releaseOwnerRole": None, "nextActionDueAtUtc": "2026-09-10T09:00:00Z", "blockerCategory": "access_owner_unassigned"}
        V.validate(data, require_recorded=True)
        data = recorded(); data["overallStatus"] = "BLOCKED"
        data["approval"] = {"status": "BLOCKED", "productOwnerRole": "product_owner", "releaseOwnerRole": "release_owner", "nextActionDueAtUtc": "2026-09-10T09:00:00Z", "blockerCategory": "access_owner_unassigned"}
        with self.assertRaisesRegex(V.AccountReadinessError, "missing approval role"):
            V.validate(data)
        data = recorded(False); data["stores"][1]["blockerCategory"] = "access_owner_unassigned"; data["stores"][1]["ownerRole"] = None
        V.validate(data, require_recorded=True)

    def test_roles_are_bound_to_responsibilities(self) -> None:
        data = recorded(); data["legalOperatorRole"] = "product_owner"
        with self.assertRaisesRegex(V.AccountReadinessError, "legal_operator"): V.validate(data)
        data = recorded(); data["stores"][0]["ownerRole"] = "release_owner"
        with self.assertRaisesRegex(V.AccountReadinessError, "store_account_owner"): V.validate(data)

    def test_created_identity_survives_blocked_account_access(self) -> None:
        data = recorded(); data["overallStatus"] = "BLOCKED"
        data["stores"][0].update({"accountStatus": "BLOCKED", "nextActionDueAtUtc": "2026-09-10T09:00:00Z", "blockerCategory": "verification_pending"})
        V.validate(data, require_recorded=True)

    def test_candidate_configuration_drift_is_detected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for relative in ("mobile/android/app/build.gradle.kts", "mobile/ios/Runner.xcodeproj/project.pbxproj", "mobile/ios/Runner/Info.plist", "mobile/lib/core/config/app_environment.dart"):
                target = root / relative; target.parent.mkdir(parents=True, exist_ok=True); shutil.copy2(ROOT / relative, target)
            gradle = root / "mobile/android/app/build.gradle.kts"
            gradle.write_text(gradle.read_text().replace("com.walkingrpg.walking_rpg_mobile", "com.changed.walking_rpg_mobile"), encoding="utf-8")
            with self.assertRaisesRegex(V.AccountReadinessError, "effective candidate"):
                V.validate(recorded(), repository_root=root)

if __name__ == "__main__": unittest.main()
