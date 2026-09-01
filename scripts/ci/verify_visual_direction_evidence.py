#!/usr/bin/env python3
"""Fail-closed validator for physical visual-direction evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

SCHEMA_VERSION = "walking-rpg-visual-direction-v1"
TOP_KEYS = {"schemaVersion", "recordStatus", "recordedAtUtc", "baseline", "captures", "decision"}
BASELINE_KEYS = {"releaseId", "sourceGitSha", "deviceInventorySha256"}
CAPTURE_KEYS = {"id", "platform", "osVersion", "deviceInventorySlotId", "theme", "textScale", "screen", "sourceType", "capturedAtUtc", "artifactSha256", "evidenceRef", "companionId", "evolutionStage", "motionState"}
DECISION_KEYS = {"status", "decidedAtUtc", "ownerRole", "inclusions", "exclusions", "motionDecision", "iconSplashDecision", "storeArtworkPrinciples"}
REQUIRED_SCREENS = {"first-journey", "expedition", "crew", "journal", "event"}
COMPANIONS = {"spark-v1", "moss-v1", "rune-v1"}
SHA40 = re.compile(r"^[0-9a-f]{40}$")
SHA64 = re.compile(r"^[0-9a-f]{64}$")
SLUG = re.compile(r"^[a-z][a-z0-9_-]{1,63}$")
UTC = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
SENSITIVE = re.compile(r"(?i)(?:https?://|www\.|\b[\w.+-]+@[\w.-]+\.[a-z]{2,}\b|\b(?:token|secret|password|serial|imei|account[_ -]?id|device[_ -]?id)\b|\b\d{10,}\b)")


class VisualEvidenceError(ValueError):
    pass


def _fail(path: str, message: str) -> None:
    raise VisualEvidenceError(f"{path}: {message}")


def _object(value: Any, path: str, keys: set[str]) -> dict[str, Any]:
    if not isinstance(value, dict):
        _fail(path, "must be an object")
    missing, unknown = sorted(keys - value.keys()), sorted(value.keys() - keys)
    if missing or unknown:
        _fail(path, f"keys mismatch; missing={missing}, unknown={unknown}")
    return value


def _timestamp(value: Any, path: str) -> datetime:
    if not isinstance(value, str) or not UTC.fullmatch(value):
        _fail(path, "must be an exact UTC timestamp ending in Z")
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def _text(value: Any, path: str) -> str:
    if not isinstance(value, str) or not value.strip() or len(value) > 240:
        _fail(path, "must be non-empty text of at most 240 characters")
    if SENSITIVE.search(value):
        _fail(path, "must not contain URLs, credentials, identifiers, or personal data")
    return value


def validate_evidence(data: Any, *, require_recorded: bool = False, inventory: Any = None, inventory_sha256: str | None = None) -> None:
    root = _object(data, "$", TOP_KEYS)
    if root["schemaVersion"] != SCHEMA_VERSION:
        _fail("schemaVersion", f"must equal {SCHEMA_VERSION!r}")
    status = root["recordStatus"]
    if status not in {"TEMPLATE", "RECORDED"}:
        _fail("recordStatus", "must be TEMPLATE or RECORDED")
    if require_recorded and status != "RECORDED":
        _fail("recordStatus", "recorded evidence is required")

    baseline = _object(root["baseline"], "baseline", BASELINE_KEYS)
    if baseline["releaseId"] != "alpha-rc3" or not SHA40.fullmatch(baseline["sourceGitSha"]):
        _fail("baseline", "must identify the exact alpha-rc3 source")
    if not SHA64.fullmatch(baseline["deviceInventorySha256"]):
        _fail("baseline.deviceInventorySha256", "must be a lowercase SHA-256")
    if status == "RECORDED" and baseline["deviceInventorySha256"] == "0" * 64:
        _fail("baseline.deviceInventorySha256", "recorded evidence must bind a real inventory digest")
    inventory_slots = {}
    if status == "RECORDED":
        if inventory is None or inventory_sha256 != baseline["deviceInventorySha256"]:
            _fail("baseline.deviceInventorySha256", "must match the supplied recorded inventory bytes")
        if not isinstance(inventory, dict) or inventory.get("recordStatus") != "RECORDED":
            _fail("inventory", "must be a RECORDED device inventory")
        for slot in inventory.get("slots", []):
            if isinstance(slot, dict) and slot.get("status") == "AVAILABLE":
                inventory_slots[slot.get("slotId")] = slot.get("platform")

    decision = _object(root["decision"], "decision", DECISION_KEYS)
    captures = root["captures"]
    if not isinstance(captures, list):
        _fail("captures", "must be an array")
    if status == "TEMPLATE":
        if root["recordedAtUtc"] is not None or captures or decision != {
            "status": "PENDING", "decidedAtUtc": None, "ownerRole": None,
            "inclusions": [], "exclusions": [], "motionDecision": None,
            "iconSplashDecision": None, "storeArtworkPrinciples": [],
        }:
            _fail("$", "committed TEMPLATE must remain empty and pending")
        return

    recorded_at = _timestamp(root["recordedAtUtc"], "recordedAtUtc")
    coverage = {platform: {"themes": set(), "screens": set(), "largeText": False} for platform in ("ios", "android")}
    companions, motion_states, ids = set(), set(), set()
    if not captures:
        _fail("captures", "recorded evidence requires physical captures")
    for index, raw in enumerate(captures):
        path = f"captures[{index}]"
        capture = _object(raw, path, CAPTURE_KEYS)
        capture_id = capture["id"]
        if not isinstance(capture_id, str) or not SLUG.fullmatch(capture_id) or capture_id in ids:
            _fail(f"{path}.id", "must be a unique safe slug")
        ids.add(capture_id)
        if capture["platform"] not in {"ios", "android"}:
            _fail(f"{path}.platform", "must be ios or android")
        if capture["theme"] not in {"light", "dark"}:
            _fail(f"{path}.theme", "must be light or dark")
        if capture["screen"] not in REQUIRED_SCREENS:
            _fail(f"{path}.screen", f"must be one of {sorted(REQUIRED_SCREENS)}")
        if capture["sourceType"] != "PHYSICAL_DEVICE":
            _fail(f"{path}.sourceType", "must equal PHYSICAL_DEVICE")
        if inventory_slots.get(capture["deviceInventorySlotId"]) != capture["platform"]:
            _fail(f"{path}.deviceInventorySlotId", "must resolve to an AVAILABLE inventory slot on the same platform")
        if capture["companionId"] not in COMPANIONS:
            _fail(f"{path}.companionId", f"must be one of {sorted(COMPANIONS)}")
        if capture["evolutionStage"] not in {"base", "evolved"}:
            _fail(f"{path}.evolutionStage", "must be base or evolved")
        if capture["motionState"] not in {"static", "reduced_motion", "motion"}:
            _fail(f"{path}.motionState", "must be static, reduced_motion, or motion")
        scale = capture["textScale"]
        if isinstance(scale, bool) or not isinstance(scale, (int, float)) or not 1.0 <= scale <= 2.0:
            _fail(f"{path}.textScale", "must be between 1.0 and 2.0")
        for key in ("osVersion", "deviceInventorySlotId", "evidenceRef"):
            _text(capture[key], f"{path}.{key}")
        if not SHA64.fullmatch(capture["artifactSha256"]):
            _fail(f"{path}.artifactSha256", "must be a lowercase SHA-256")
        if _timestamp(capture["capturedAtUtc"], f"{path}.capturedAtUtc") > recorded_at:
            _fail(f"{path}.capturedAtUtc", "must not follow recordedAtUtc")
        platform_coverage = coverage[capture["platform"]]
        platform_coverage["themes"].add(capture["theme"])
        platform_coverage["screens"].add(capture["screen"])
        if scale >= 1.6:
            platform_coverage["largeText"] = True
        companions.add(capture["companionId"])
        motion_states.add(capture["motionState"])
    for platform, platform_coverage in coverage.items():
        if platform_coverage != {"themes": {"light", "dark"}, "screens": REQUIRED_SCREENS, "largeText": True}:
            _fail("captures", f"{platform} must cover light/dark, every required screen, and large text")
    if companions != COMPANIONS:
        _fail("captures", "must cover every candidate companion")

    if decision["status"] != "APPROVED":
        _fail("decision.status", "must equal APPROVED")
    if _timestamp(decision["decidedAtUtc"], "decision.decidedAtUtc") < recorded_at:
        _fail("decision.decidedAtUtc", "must not precede recordedAtUtc")
    if decision["ownerRole"] not in {"product_owner", "art_director"}:
        _fail("decision.ownerRole", "must be product_owner or art_director")
    for key in ("inclusions", "exclusions", "storeArtworkPrinciples"):
        values = decision[key]
        if not isinstance(values, list) or not values:
            _fail(f"decision.{key}", "must be a non-empty array")
        for index, value in enumerate(values):
            _text(value, f"decision.{key}[{index}]")
    if decision["motionDecision"] not in {"REDUCED_MOTION_SAFE", "STATIC_ONLY", "APPROVED_MOTION"}:
        _fail("decision.motionDecision", "must contain an explicit approved motion scope")
    required_motion = {"REDUCED_MOTION_SAFE": "reduced_motion", "STATIC_ONLY": "static", "APPROVED_MOTION": "motion"}[decision["motionDecision"]]
    if required_motion not in motion_states:
        _fail("captures", f"must contain {required_motion!r} evidence for the motion decision")
    _text(decision["iconSplashDecision"], "decision.iconSplashDecision")


def _unique(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result = {}
    for key, value in pairs:
        if key in result:
            raise VisualEvidenceError(f"duplicate JSON object key: {key}")
        result[key] = value
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence", type=Path)
    parser.add_argument("--require-recorded", action="store_true")
    parser.add_argument("--device-inventory", type=Path)
    args = parser.parse_args(argv)
    try:
        data = json.loads(args.evidence.read_text(encoding="utf-8"), object_pairs_hook=_unique)
        inventory_bytes = args.device_inventory.read_bytes() if args.device_inventory else None
        inventory = json.loads(inventory_bytes, object_pairs_hook=_unique) if inventory_bytes else None
        digest = hashlib.sha256(inventory_bytes).hexdigest() if inventory_bytes else None
        validate_evidence(data, require_recorded=args.require_recorded, inventory=inventory, inventory_sha256=digest)
    except (OSError, UnicodeError, json.JSONDecodeError, VisualEvidenceError) as error:
        print(f"Visual direction evidence invalid: {error}", file=sys.stderr)
        return 1
    print(f"Visual direction evidence valid: {args.evidence}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
