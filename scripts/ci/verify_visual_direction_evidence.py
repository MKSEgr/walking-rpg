#!/usr/bin/env python3
"""Fail-closed validator for physical visual-direction evidence."""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

SCHEMA_VERSION = "walking-rpg-visual-direction-v1"
TOP_KEYS = {"schemaVersion", "recordStatus", "recordedAtUtc", "baseline", "captures", "decision"}
BASELINE_KEYS = {"releaseId", "sourceGitSha", "deviceInventorySha256"}
CAPTURE_KEYS = {"id", "platform", "osVersion", "deviceInventorySlotId", "theme", "textScale", "screen", "sourceType", "capturedAtUtc", "artifactSha256", "evidenceRef"}
DECISION_KEYS = {"status", "decidedAtUtc", "ownerRole", "inclusions", "exclusions", "motionDecision", "iconSplashDecision", "storeArtworkPrinciples"}
REQUIRED_SCREENS = {"first-journey", "expedition", "crew", "journal", "event"}
SHA40 = re.compile(r"^[0-9a-f]{40}$")
SHA64 = re.compile(r"^[0-9a-f]{64}$")
SLUG = re.compile(r"^[a-z][a-z0-9_-]{1,63}$")
UTC = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")


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
    return value


def validate_evidence(data: Any, *, require_recorded: bool = False) -> None:
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
    platforms, themes, screens, large_text, ids = set(), set(), set(), set(), set()
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
        scale = capture["textScale"]
        if isinstance(scale, bool) or not isinstance(scale, (int, float)) or not 1.0 <= scale <= 2.0:
            _fail(f"{path}.textScale", "must be between 1.0 and 2.0")
        for key in ("osVersion", "deviceInventorySlotId", "evidenceRef"):
            _text(capture[key], f"{path}.{key}")
        if not SHA64.fullmatch(capture["artifactSha256"]):
            _fail(f"{path}.artifactSha256", "must be a lowercase SHA-256")
        if _timestamp(capture["capturedAtUtc"], f"{path}.capturedAtUtc") > recorded_at:
            _fail(f"{path}.capturedAtUtc", "must not follow recordedAtUtc")
        platforms.add(capture["platform"])
        themes.add(capture["theme"])
        screens.add(capture["screen"])
        if scale >= 1.6:
            large_text.add(capture["platform"])
    if platforms != {"ios", "android"} or themes != {"light", "dark"} or screens != REQUIRED_SCREENS or large_text != {"ios", "android"}:
        _fail("captures", "must cover iOS/Android, light/dark, every required screen, and large text on both platforms")

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
    args = parser.parse_args(argv)
    try:
        data = json.loads(args.evidence.read_text(encoding="utf-8"), object_pairs_hook=_unique)
        validate_evidence(data, require_recorded=args.require_recorded)
    except (OSError, UnicodeError, json.JSONDecodeError, VisualEvidenceError) as error:
        print(f"Visual direction evidence invalid: {error}", file=sys.stderr)
        return 1
    print(f"Visual direction evidence valid: {args.evidence}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
