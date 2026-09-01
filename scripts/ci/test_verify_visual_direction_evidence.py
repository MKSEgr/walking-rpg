#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import hashlib
import json
import unittest
from pathlib import Path

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
    specs = [
        ("ios-first", "ios", "light", 1.0, "first-journey", "spark-v1"),
        ("ios-expedition", "ios", "dark", 1.0, "expedition", "moss-v1"),
        ("ios-crew", "ios", "light", 1.6, "crew", "rune-v1"),
        ("ios-journal", "ios", "dark", 1.0, "journal", "spark-v1"),
        ("ios-event", "ios", "light", 1.0, "event", "moss-v1"),
        ("android-first", "android", "light", 1.0, "first-journey", "spark-v1"),
        ("android-expedition", "android", "dark", 1.0, "expedition", "moss-v1"),
        ("android-crew", "android", "light", 1.6, "crew", "rune-v1"),
        ("android-journal", "android", "dark", 1.0, "journal", "spark-v1"),
        ("android-event", "android", "light", 1.0, "event", "moss-v1"),
    ]
    data["captures"] = [{
        "id": capture_id, "platform": platform, "osVersion": "current-stable",
        "deviceInventorySlotId": f"{platform}-primary", "theme": theme,
        "textScale": scale, "screen": screen, "sourceType": "PHYSICAL_DEVICE",
        "capturedAtUtc": "2026-09-01T10:00:00Z", "artifactSha256": "b" * 64,
        "evidenceRef": f"approved-internal/{capture_id}", "companionId": companion,
        "evolutionStage": "base", "motionState": "reduced_motion",
    } for capture_id, platform, theme, scale, screen, companion in specs]
    data["decision"] = {
        "status": "APPROVED", "decidedAtUtc": "2026-09-01T12:00:00Z",
        "ownerRole": "product_owner", "inclusions": ["world and pet direction"],
        "exclusions": ["unreviewed event art"], "motionDecision": "REDUCED_MOTION_SAFE",
        "iconSplashDecision": "retain current candidates for alpha",
        "storeArtworkPrinciples": ["world and companion lead"],
    }
    return data


def inventory() -> dict:
    return {"recordStatus": "RECORDED", "slots": [
        {"slotId": "ios-primary", "status": "AVAILABLE", "platform": "ios"},
        {"slotId": "android-primary", "status": "AVAILABLE", "platform": "android"},
    ]}


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
        data["captures"] = data["captures"][:-1]
        with self.assertRaisesRegex(V.VisualEvidenceError, "must cover"):
            validate(data)
        data = recorded()
        data["captures"][2]["textScale"] = 1.0
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


if __name__ == "__main__":
    unittest.main()
