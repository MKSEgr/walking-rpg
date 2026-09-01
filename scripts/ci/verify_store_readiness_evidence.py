#!/usr/bin/env python3
"""Fail-closed validator for store upload-readiness evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

import verify_visual_direction_evidence as visual_direction

SCHEMA = "walking-rpg-store-readiness-v1"
SOURCE = "dc2119a8305ecb7786f1c0a6fee8609d261f1195"
TOP = {"schemaVersion", "recordStatus", "recordedAtUtc", "baseline", "publicUrls", "capabilities", "stores", "approval"}
BASELINE = {"releaseId", "sourceGitSha", "visualDirectionSha256"}
URLS = {"privacy", "support", "deletion"}
CAPABILITIES = {"health", "push", "billing", "telegramLogin"}
STORE = {"platform", "appRecordStatus", "privacyDeclarationStatus", "healthDeclarationStatus", "locales", "screenshotSetSha256", "iconSha256", "reviewerFlowStatus", "advertisedCapabilities"}
APPROVAL = {"status", "ownerRole", "approvedAtUtc"}
SHA64 = re.compile(r"^[0-9a-f]{64}$")
UTC = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
HTTPS = re.compile(r"^https://[A-Za-z0-9.-]+(?::\d+)?(?:/[^\s]*)?$")


class StoreReadinessError(ValueError):
    pass


def _fail(path: str, message: str) -> None:
    raise StoreReadinessError(f"{path}: {message}")


def _object(value: Any, path: str, keys: set[str]) -> dict[str, Any]:
    if not isinstance(value, dict):
        _fail(path, "must be an object")
    missing, unknown = sorted(keys - value.keys()), sorted(value.keys() - keys)
    if missing or unknown:
        _fail(path, f"keys mismatch; missing={missing}, unknown={unknown}")
    return value


def _time(value: Any, path: str) -> datetime:
    if not isinstance(value, str) or not UTC.fullmatch(value):
        _fail(path, "must be an exact UTC timestamp ending in Z")
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def validate(data: Any, *, require_recorded: bool = False, visual: Any = None,
             visual_sha256: str | None = None, inventory: Any = None,
             inventory_sha256: str | None = None) -> None:
    root = _object(data, "$", TOP)
    if root["schemaVersion"] != SCHEMA:
        _fail("schemaVersion", f"must equal {SCHEMA!r}")
    status = root["recordStatus"]
    if status not in {"TEMPLATE", "RECORDED"}:
        _fail("recordStatus", "must be TEMPLATE or RECORDED")
    if require_recorded and status != "RECORDED":
        _fail("recordStatus", "recorded evidence is required")
    baseline = _object(root["baseline"], "baseline", BASELINE)
    if baseline["releaseId"] != "alpha-rc3" or baseline["sourceGitSha"] != SOURCE:
        _fail("baseline", "must identify the exact alpha-rc3 source")
    if not SHA64.fullmatch(baseline["visualDirectionSha256"]):
        _fail("baseline.visualDirectionSha256", "must be a lowercase SHA-256")
    urls = _object(root["publicUrls"], "publicUrls", URLS)
    capabilities = _object(root["capabilities"], "capabilities", CAPABILITIES)
    if capabilities != {"health": True, "push": False, "billing": False, "telegramLogin": False}:
        _fail("capabilities", "must match the enabled alpha-rc3 capability truth table")
    approval = _object(root["approval"], "approval", APPROVAL)
    stores = root["stores"]
    if not isinstance(stores, list):
        _fail("stores", "must be an array")
    if status == "TEMPLATE":
        if root["recordedAtUtc"] is not None or stores or any(value is not None for value in urls.values()) or approval != {"status": "PENDING", "ownerRole": None, "approvedAtUtc": None}:
            _fail("$", "committed TEMPLATE must remain empty and pending")
        return
    recorded_at = _time(root["recordedAtUtc"], "recordedAtUtc")
    if baseline["visualDirectionSha256"] == "0" * 64:
        _fail("baseline.visualDirectionSha256", "must bind an approved visual-direction record")
    if visual is None or visual_sha256 != baseline["visualDirectionSha256"]:
        _fail("baseline.visualDirectionSha256", "must match the supplied visual-direction bytes")
    try:
        visual_direction.validate_evidence(
            visual, require_recorded=True, inventory=inventory,
            inventory_sha256=inventory_sha256,
        )
    except visual_direction.VisualEvidenceError as error:
        _fail("visualDirection", f"must satisfy the recorded visual contract: {error}")
    for key, value in urls.items():
        if not isinstance(value, str) or not HTTPS.fullmatch(value):
            _fail(f"publicUrls.{key}", "must be a public HTTPS URL")
    if len(stores) != 2:
        _fail("stores", "must contain exactly Apple and Google records")
    platforms = set()
    for index, raw in enumerate(stores):
        path = f"stores[{index}]"
        store = _object(raw, path, STORE)
        platform = store["platform"]
        if platform not in {"apple", "google"} or platform in platforms:
            _fail(f"{path}.platform", "must uniquely identify apple or google")
        platforms.add(platform)
        for key in ("appRecordStatus", "privacyDeclarationStatus", "healthDeclarationStatus", "reviewerFlowStatus"):
            if store[key] != "APPROVED":
                _fail(f"{path}.{key}", "must equal APPROVED")
        if store["locales"] != ["en", "ru"]:
            _fail(f"{path}.locales", "must equal ['en', 'ru']")
        for key in ("screenshotSetSha256", "iconSha256"):
            if not isinstance(store[key], str) or not SHA64.fullmatch(store[key]) or store[key] == "0" * 64:
                _fail(f"{path}.{key}", "must be a real lowercase SHA-256")
        advertised = store["advertisedCapabilities"]
        if advertised != ["health"]:
            _fail(f"{path}.advertisedCapabilities", "must advertise only enabled health capability")
    if approval != {"status": "APPROVED", "ownerRole": "product_owner", "approvedAtUtc": approval["approvedAtUtc"]}:
        _fail("approval", "must contain product-owner approval")
    if _time(approval["approvedAtUtc"], "approval.approvedAtUtc") < recorded_at:
        _fail("approval.approvedAtUtc", "must not precede recordedAtUtc")


def _unique(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result = {}
    for key, value in pairs:
        if key in result:
            raise StoreReadinessError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence", type=Path)
    parser.add_argument("--require-recorded", action="store_true")
    parser.add_argument("--visual-direction", type=Path)
    parser.add_argument("--device-inventory", type=Path)
    args = parser.parse_args(argv)
    try:
        data = json.loads(args.evidence.read_text(encoding="utf-8"), object_pairs_hook=_unique)
        visual_bytes = args.visual_direction.read_bytes() if args.visual_direction else None
        inventory_bytes = args.device_inventory.read_bytes() if args.device_inventory else None
        visual = json.loads(visual_bytes, object_pairs_hook=_unique) if visual_bytes else None
        inventory = json.loads(inventory_bytes, object_pairs_hook=_unique) if inventory_bytes else None
        validate(data, require_recorded=args.require_recorded, visual=visual,
                 visual_sha256=hashlib.sha256(visual_bytes).hexdigest() if visual_bytes else None,
                 inventory=inventory,
                 inventory_sha256=hashlib.sha256(inventory_bytes).hexdigest() if inventory_bytes else None)
    except (OSError, UnicodeError, json.JSONDecodeError, StoreReadinessError) as error:
        print(f"Store readiness evidence invalid: {error}", file=sys.stderr)
        return 1
    print(f"Store readiness evidence valid: {args.evidence}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
