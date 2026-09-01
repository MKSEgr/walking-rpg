#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import hashlib
import json
import unittest
from pathlib import Path

import test_verify_health_device_inventory as HEALTH_TEST

MODULE = Path(__file__).with_name("verify_visual_direction_evidence.py")
SPEC = importlib.util.spec_from_file_location("visual_evidence", MODULE)
assert SPEC and SPEC.loader
V = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(V)
ROOT = Path(__file__).resolve().parents[2]
TEMPLATE = ROOT / "docs/evidence/visual-direction-template.json"


def template() -> dict:
    return json.loads(TEMPLATE.read_text(encoding="utf-8"))


def recorded() -> dict:
    data = template()
    data["recordStatus"] = "RECORDED"
    data["recordedAtUtc"] = "2026-09-01T11:00:00Z"
    data["baseline"]["deviceInventorySha256"] = inventory_digest()
    screens = ["first-journey", "expedition", "crew", "journal", "event"]
    specs = []
    for platform in ("ios", "android"):
        for companion_index, companion in enumerate(("spark-v1", "moss-v1", "rune-v1")):
            for stage in (0, 1, 2):
                index = companion_index * 3 + stage
                specs.append((f"{platform}-{companion}-{stage}", platform,
                              "light" if index % 2 == 0 else "dark",
                              1.6 if index == 0 else 1.0, screens[index % len(screens)],
                              companion, stage))
    data["captures"] = [{
        "id": capture_id, "platform": platform, "osVersion": "current-stable",
        "deviceInventorySlotId": ("ios-phone-no-watch" if platform == "ios" else
                                  "android-health-connect-primary"), "theme": theme,
        "textScale": scale, "screen": screen, "sourceType": "PHYSICAL_DEVICE",
        "capturedAtUtc": "2026-09-01T10:00:00Z", "artifactSha256": "b" * 64,
        "evidenceRef": f"approved-internal/{capture_id}", "companionId": companion,
        "evolutionStage": stage, "motionState": "reduced_motion",
    } for capture_id, platform, theme, scale, screen, companion, stage in specs]
    data["decision"] = {
        "status": "APPROVED", "decidedAtUtc": "2026-09-01T12:00:00Z",
        "ownerRole": "product_owner", "inclusions": ["world and pet direction"],
        "exclusions": ["unreviewed event art"], "motionDecision": "REDUCED_MOTION_SAFE",
        "iconSplashDecision": "retain current candidates for alpha",
        "storeArtworkPrinciples": ["world and companion lead"],
    }
    return data


def inventory() -> dict:
    return HEALTH_TEST.recorded()


def inventory_digest() -> str:
    return hashlib.sha256(json.dumps(inventory(), separators=(",", ":")).encode()).hexdigest()


def validate(data: dict) -> None:
    V.validate_evidence(data, require_recorded=True, inventory=inventory(), inventory_sha256=inventory_digest())


class VisualEvidenceTest(unittest.TestCase):
    def test_template_is_valid_but_not_recorded(self) -> None:
        V.validate_evidence(template())
        with self.assertRaises(V.VisualEvidenceError):
            V.validate_evidence(template(), require_recorded=True)

    def test_complete_record_is_valid(self) -> None:
        validate(recorded())

    def test_ci_render_cannot_pose_as_physical_evidence(self) -> None:
        data = recorded()
        data["captures"][0]["sourceType"] = "CI_RENDER"
        with self.assertRaisesRegex(V.VisualEvidenceError, "PHYSICAL_DEVICE"):
            validate(data)

    def test_every_screen_and_large_text_on_both_platforms_are_required(self) -> None:
        data = recorded()
        data["captures"] = [capture for capture in data["captures"] if not (
            capture["platform"] == "ios" and capture["screen"] == "event")]
        with self.assertRaisesRegex(V.VisualEvidenceError, "must cover"):
            validate(data)
        data = recorded()
        for capture in data["captures"]:
            if capture["platform"] == "ios":
                capture["textScale"] = 1.0
        with self.assertRaisesRegex(V.VisualEvidenceError, "must cover"):
            validate(data)

    def test_pending_decision_and_unknown_fields_fail_closed(self) -> None:
        data = recorded()
        data["decision"]["status"] = "PENDING"
        with self.assertRaisesRegex(V.VisualEvidenceError, "APPROVED"):
            validate(data)
        data = recorded()
        data["captures"][0]["deviceSerial"] = "redacted"
        with self.assertRaisesRegex(V.VisualEvidenceError, "unknown"):
            validate(data)

    def test_inventory_binding_and_redaction_fail_closed(self) -> None:
        data = recorded()
        data["captures"][0]["deviceInventorySlotId"] = "invented-slot"
        with self.assertRaisesRegex(V.VisualEvidenceError, "AVAILABLE"):
            validate(data)
        data = recorded()
        data["decision"]["inclusions"] = ["owner@example.com"]
        with self.assertRaisesRegex(V.VisualEvidenceError, "personal data"):
            validate(data)

    def test_source_inventory_stages_and_motion_are_fully_bound(self) -> None:
        data = recorded()
        data["baseline"]["sourceGitSha"] = "f" * 40
        with self.assertRaisesRegex(V.VisualEvidenceError, "exact alpha-rc3"):
            validate(data)
        data = recorded()
        data["captures"] = [capture for capture in data["captures"] if not (
            capture["companionId"] == "rune-v1" and capture["evolutionStage"] == 2)]
        with self.assertRaisesRegex(V.VisualEvidenceError, "canonical stages"):
            validate(data)
        data = recorded()
        for capture in data["captures"]:
            if capture["platform"] == "android" and capture["companionId"] == "moss-v1":
                capture["motionState"] = "static"
        with self.assertRaisesRegex(V.VisualEvidenceError, "android/moss-v1"):
            validate(data)
        data = recorded()
        bad_inventory = inventory()
        del bad_inventory["baseline"]
        with self.assertRaisesRegex(V.VisualEvidenceError, "recorded inventory contract"):
            V.validate_evidence(data, require_recorded=True, inventory=bad_inventory,
                                inventory_sha256=inventory_digest())


if __name__ == "__main__":
    unittest.main()
