#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
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
    data["baseline"]["deviceInventorySha256"] = "a" * 64
    specs = [
        ("ios-first", "ios", "light", 1.0, "first-journey"),
        ("ios-crew", "ios", "dark", 1.6, "crew"),
        ("android-expedition", "android", "light", 1.0, "expedition"),
        ("android-journal", "android", "dark", 1.6, "journal"),
        ("android-event", "android", "dark", 1.0, "event"),
    ]
    data["captures"] = [{
        "id": capture_id, "platform": platform, "osVersion": "current-stable",
        "deviceInventorySlotId": f"{platform}-primary", "theme": theme,
        "textScale": scale, "screen": screen, "sourceType": "PHYSICAL_DEVICE",
        "capturedAtUtc": "2026-09-01T10:00:00Z", "artifactSha256": "b" * 64,
        "evidenceRef": f"approved-internal/{capture_id}",
    } for capture_id, platform, theme, scale, screen in specs]
    data["decision"] = {
        "status": "APPROVED", "decidedAtUtc": "2026-09-01T12:00:00Z",
        "ownerRole": "product_owner", "inclusions": ["world and pet direction"],
        "exclusions": ["unreviewed event art"], "motionDecision": "REDUCED_MOTION_SAFE",
        "iconSplashDecision": "retain current candidates for alpha",
        "storeArtworkPrinciples": ["world and companion lead"],
    }
    return data


class VisualEvidenceTest(unittest.TestCase):
    def test_template_is_valid_but_not_recorded(self) -> None:
        V.validate_evidence(template())
        with self.assertRaises(V.VisualEvidenceError):
            V.validate_evidence(template(), require_recorded=True)

    def test_complete_record_is_valid(self) -> None:
        V.validate_evidence(recorded(), require_recorded=True)

    def test_ci_render_cannot_pose_as_physical_evidence(self) -> None:
        data = recorded()
        data["captures"][0]["sourceType"] = "CI_RENDER"
        with self.assertRaisesRegex(V.VisualEvidenceError, "PHYSICAL_DEVICE"):
            V.validate_evidence(data)

    def test_every_screen_and_large_text_on_both_platforms_are_required(self) -> None:
        data = recorded()
        data["captures"] = data["captures"][:-1]
        with self.assertRaisesRegex(V.VisualEvidenceError, "must cover"):
            V.validate_evidence(data)
        data = recorded()
        data["captures"][1]["textScale"] = 1.0
        with self.assertRaisesRegex(V.VisualEvidenceError, "must cover"):
            V.validate_evidence(data)

    def test_pending_decision_and_unknown_fields_fail_closed(self) -> None:
        data = recorded()
        data["decision"]["status"] = "PENDING"
        with self.assertRaisesRegex(V.VisualEvidenceError, "APPROVED"):
            V.validate_evidence(data)
        data = recorded()
        data["captures"][0]["deviceSerial"] = "redacted"
        with self.assertRaisesRegex(V.VisualEvidenceError, "unknown"):
            V.validate_evidence(data)


if __name__ == "__main__":
    unittest.main()
