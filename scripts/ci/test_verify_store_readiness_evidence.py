#!/usr/bin/env python3
from __future__ import annotations
import importlib.util
import hashlib
import json
import unittest
from pathlib import Path

import test_verify_visual_direction_evidence as VISUAL_TEST

MODULE = Path(__file__).with_name("verify_store_readiness_evidence.py")
SPEC = importlib.util.spec_from_file_location("store_readiness", MODULE)
assert SPEC and SPEC.loader
V = importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(V)
ROOT = Path(__file__).resolve().parents[2]
TEMPLATE = ROOT / "docs/evidence/store-readiness-template.json"

def template() -> dict: return json.loads(TEMPLATE.read_text(encoding="utf-8"))

def recorded() -> dict:
    data = template(); data["recordStatus"] = "RECORDED"; data["recordedAtUtc"] = "2026-09-01T10:00:00Z"
    data["baseline"]["visualDirectionSha256"] = visual_digest()
    data["publicUrls"] = {key: f"https://walking-rpg.com/{key}" for key in V.URLS}
    data["stores"] = []
    for platform in ("apple", "google"):
        data["stores"].append({"platform": platform, "appRecordStatus": "APPROVED", "privacyDeclarationStatus": "APPROVED", "healthDeclarationStatus": "APPROVED", "locales": ["en", "ru"], "assetDigests": {key: "b" * 64 for key in V.ASSET_KEYS[platform]}, "metadataPackSha256": "c" * 64, "reviewerFlowStatus": "APPROVED", "advertisedCapabilities": ["health", "telegramLogin"]})
    data["approval"] = {"status": "APPROVED", "ownerRole": "product_owner", "approvedAtUtc": "2026-09-01T13:00:00Z"}
    return data

def visual() -> dict: return VISUAL_TEST.recorded()
def inventory() -> dict: return VISUAL_TEST.inventory()
def encoded(value: dict) -> bytes: return json.dumps(value, separators=(",", ":")).encode()
def visual_digest() -> str: return hashlib.sha256(encoded(visual())).hexdigest()
def inventory_digest() -> str: return hashlib.sha256(encoded(inventory())).hexdigest()
def validate(data: dict) -> None:
    V.validate(data, require_recorded=True, visual=visual(), visual_sha256=visual_digest(),
               inventory=inventory(), inventory_sha256=inventory_digest())

class StoreReadinessTest(unittest.TestCase):
    def test_template_valid_but_not_recorded(self) -> None:
        V.validate(template())
        with self.assertRaises(V.StoreReadinessError): V.validate(template(), require_recorded=True)
    def test_complete_record_valid(self) -> None: validate(recorded())
    def test_disabled_capability_cannot_be_advertised(self) -> None:
        data = recorded(); data["stores"][0]["advertisedCapabilities"] = ["health", "billing"]
        with self.assertRaisesRegex(V.StoreReadinessError, "enabled shipped"): validate(data)
    def test_both_stores_and_public_urls_are_required(self) -> None:
        data = recorded(); data["stores"] = data["stores"][:1]
        with self.assertRaisesRegex(V.StoreReadinessError, "exactly Apple"): validate(data)
        data = recorded(); data["publicUrls"]["privacy"] = "http://private.local"
        with self.assertRaisesRegex(V.StoreReadinessError, "public HTTPS"): validate(data)
    def test_visual_digest_and_product_owner_are_required(self) -> None:
        data = recorded(); data["baseline"]["visualDirectionSha256"] = "0" * 64
        with self.assertRaisesRegex(V.StoreReadinessError, "approved visual"): validate(data)
        data = recorded(); data["approval"]["ownerRole"] = "release_owner"
        with self.assertRaisesRegex(V.StoreReadinessError, "product-owner"): validate(data)

    def test_visual_record_bytes_and_contract_are_required(self) -> None:
        data = recorded()
        with self.assertRaisesRegex(V.StoreReadinessError, "supplied visual-direction bytes"):
            V.validate(data, require_recorded=True)
        bad_visual = visual(); bad_visual["decision"]["status"] = "PENDING"
        with self.assertRaisesRegex(V.StoreReadinessError, "recorded visual contract"):
            V.validate(data, require_recorded=True, visual=bad_visual,
                       visual_sha256=visual_digest(), inventory=inventory(),
                       inventory_sha256=inventory_digest())

    def test_reserved_urls_and_missing_platform_assets_are_rejected(self) -> None:
        for url in ("https://localhost/privacy", "https://127.0.0.1/privacy",
                    "https://walking.example/privacy", "https://walking.example.com/privacy"):
            data = recorded(); data["publicUrls"]["privacy"] = url
            with self.assertRaisesRegex(V.StoreReadinessError, "public|reserved"):
                validate(data)
        for url in ("https://walking-rpg.com:bad/privacy",
                    "https://walking-rpg.com:65536/privacy"):
            data = recorded(); data["publicUrls"]["privacy"] = url
            with self.assertRaisesRegex(V.StoreReadinessError, "valid HTTPS port"):
                validate(data)
        data = recorded(); del data["stores"][0]["assetDigests"]["ipadScreenshotsSha256"]
        with self.assertRaisesRegex(V.StoreReadinessError, "keys mismatch"):
            validate(data)

    def test_approval_follows_bound_evidence_and_zero_capture_is_rejected(self) -> None:
        data = recorded(); data["approval"]["approvedAtUtc"] = "2026-09-01T11:00:00Z"
        with self.assertRaisesRegex(V.StoreReadinessError, "bound evidence approval"):
            validate(data)
        bad_visual = visual(); bad_visual["captures"][0]["artifactSha256"] = "0" * 64
        bad_digest = hashlib.sha256(encoded(bad_visual)).hexdigest(); data = recorded()
        data["baseline"]["visualDirectionSha256"] = bad_digest
        with self.assertRaisesRegex(V.StoreReadinessError, "real capture artifact"):
            V.validate(data, require_recorded=True, visual=bad_visual,
                       visual_sha256=bad_digest, inventory=inventory(),
                       inventory_sha256=inventory_digest())

if __name__ == "__main__": unittest.main()
