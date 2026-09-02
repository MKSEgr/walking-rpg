#!/usr/bin/env python3
"""Fail-closed validator for store upload-readiness evidence."""

from __future__ import annotations

import argparse
import hashlib
import ipaddress
import json
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit

import verify_visual_direction_evidence as visual_direction

SCHEMA = "walking-rpg-store-readiness-v1"
SOURCE = "dc2119a8305ecb7786f1c0a6fee8609d261f1195"
TOP = {"schemaVersion", "recordStatus", "recordedAtUtc", "baseline", "publicUrls", "capabilities", "stores", "approval"}
BASELINE = {"releaseId", "sourceGitSha", "visualDirectionSha256"}
URLS = {"privacy", "support", "deletion"}
CAPABILITIES = {"health", "push", "billing", "telegramLogin"}
STORE = {"platform", "appRecordStatus", "privacyDeclarationStatus", "healthDeclarationStatus", "locales", "assetDigests", "metadataPackSha256", "reviewerFlowStatus", "advertisedCapabilities"}
APPROVAL = {"status", "ownerRole", "approvedAtUtc"}
SHA64 = re.compile(r"^[0-9a-f]{64}$")
UTC = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
RESERVED_TLDS = {"example", "invalid", "localhost", "local", "test"}
RESERVED_DOMAINS = {"example.com", "example.net", "example.org"}
ASSET_KEYS = {
    "apple": {"iphoneScreenshotsSha256", "ipadScreenshotsSha256", "iconSha256"},
    "google": {"androidPhoneScreenshotsSha256", "featureGraphicSha256", "iconSha256"},
}


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


def _public_https(value: Any, path: str) -> None:
    if not isinstance(value, str) or any(char.isspace() for char in value):
        _fail(path, "must be a public HTTPS URL")
    parsed = urlsplit(value)
    host = parsed.hostname
    try:
        port = parsed.port
    except ValueError:
        _fail(path, "must contain a valid HTTPS port")
    if port is not None and not 1 <= port <= 65535:
        _fail(path, "must contain a valid HTTPS port")
    if parsed.scheme != "https" or not host or parsed.username or parsed.password or parsed.query or parsed.fragment:
        _fail(path, "must be a public HTTPS URL without credentials, query, or fragments")
    try:
        address = ipaddress.ip_address(host)
    except ValueError:
        labels = host.rstrip(".").lower().split(".")
        registrable_tail = ".".join(labels[-2:]) if len(labels) >= 2 else host
        if len(labels) < 2 or labels[-1] in RESERVED_TLDS or registrable_tail in RESERVED_DOMAINS or any(not label or not re.fullmatch(r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?", label) for label in labels):
            _fail(path, "must use a non-reserved public DNS host")
    else:
        if not address.is_global:
            _fail(path, "must not use a private, loopback, link-local, or reserved IP")


def _digest(value: Any, path: str) -> None:
    if not isinstance(value, str) or not SHA64.fullmatch(value) or value == "0" * 64:
        _fail(path, "must be a real lowercase SHA-256")


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
    if capabilities != {"health": True, "push": False, "billing": False, "telegramLogin": True}:
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
        _public_https(value, f"publicUrls.{key}")
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
        assets = _object(store["assetDigests"], f"{path}.assetDigests", ASSET_KEYS[platform])
        for key, value in assets.items():
            _digest(value, f"{path}.assetDigests.{key}")
        _digest(store["metadataPackSha256"], f"{path}.metadataPackSha256")
        advertised = store["advertisedCapabilities"]
        if advertised != ["health", "telegramLogin"]:
            _fail(f"{path}.advertisedCapabilities", "must match enabled shipped capabilities")
    if approval != {"status": "APPROVED", "ownerRole": "product_owner", "approvedAtUtc": approval["approvedAtUtc"]}:
        _fail("approval", "must contain product-owner approval")
    approved_at = _time(approval["approvedAtUtc"], "approval.approvedAtUtc")
    prerequisite_times = [recorded_at, _time(visual["decision"]["decidedAtUtc"], "visualDirection.decision.decidedAtUtc"), _time(inventory["reviewedAtUtc"], "inventory.reviewedAtUtc")]
    if approved_at < max(prerequisite_times):
        _fail("approval.approvedAtUtc", "must not precede the store record or any bound evidence approval")


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
