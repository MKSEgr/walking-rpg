#!/usr/bin/env python3
"""Fail-closed validator for the sanitized F1 health-device inventory."""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Any


SCHEMA_VERSION = "walking-rpg-health-device-inventory-v1"
REDACTION_POLICY = "walking-rpg-evidence-redaction-v1"

BASELINE = {
    "candidate": "alpha-rc3",
    "masterAnchorSha": "ffd67f099256135ff0b9c7df5534516aa074bf74",
    "artifactSourceSha": "dc2119a8305ecb7786f1c0a6fee8609d261f1195",
    "treeSha": "d622a8fc974f234c9a0744b9e99426a201dd2cad",
    "appVersion": "0.1.0",
    "buildNumber": "1",
}

TOP_LEVEL_KEYS = {
    "schemaVersion",
    "recordStatus",
    "recordedAtUtc",
    "reviewedAtUtc",
    "inventoryOwnerRole",
    "reviewerRole",
    "baseline",
    "evidence",
    "slots",
}
BASELINE_KEYS = set(BASELINE)
EVIDENCE_KEYS = {"storageCategory", "redactionPolicy"}
SLOT_KEYS = {
    "slotId",
    "required",
    "status",
    "platform",
    "deviceCategory",
    "deviceModel",
    "operatingSystemVersion",
    "healthApi",
    "providerCategories",
    "watchCategory",
    "ownerRole",
    "availability",
    "blockerCategory",
    "blockerReason",
}
AVAILABILITY_KEYS = {
    "cleanInstall",
    "upgrade",
    "timeZoneMidnight",
    "batteryMeasurement",
}

SLOT_SPECS = {
    "ios-phone-no-watch": {
        "platform": "ios",
        "deviceCategory": "iphone_without_watch",
        "healthApi": "healthkit",
        "watchCategories": {"none"},
    },
    "ios-phone-with-watch": {
        "platform": "ios",
        "deviceCategory": "iphone_with_apple_watch",
        "healthApi": "healthkit",
        "watchCategories": {"apple_watch"},
    },
    "android-health-connect-primary": {
        "platform": "android",
        "deviceCategory": "android_health_connect_primary",
        "healthApi": "health_connect",
        "watchCategories": {"none", "android_wearable"},
    },
    "android-health-connect-secondary": {
        "platform": "android",
        "deviceCategory": "android_health_connect_secondary_provider",
        "healthApi": "health_connect",
        "watchCategories": {"none", "android_wearable"},
    },
}
SLOT_ORDER = tuple(SLOT_SPECS)

ROLE_CATEGORIES = {
    "product_owner",
    "release_owner",
    "qa_owner",
    "ios_validation_owner",
    "android_validation_owner",
    "external_lab",
}
STORAGE_CATEGORIES = {
    "approved_internal_evidence",
    "encrypted_project_storage",
    "approved_research_workspace",
}
BLOCKER_CATEGORIES = {
    "device_unavailable",
    "os_version_unconfirmed",
    "provider_unavailable",
    "watch_unavailable",
    "owner_unassigned",
    "budget_not_approved",
    "distribution_unavailable",
    "other_coarse",
}

SAFE_SLUG = re.compile(r"^[a-z][a-z0-9_\-]{1,63}$")
LOWER_SHA = re.compile(r"^[0-9a-f]{40}$")
UUID_LIKE = re.compile(
    r"(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b"
)
SHA_LIKE = re.compile(r"(?i)\b[0-9a-f]{40,64}\b")
LONG_NUMBER = re.compile(r"\b\d{10,}\b")
URL_OR_PATH = re.compile(r"(?i)(?:https?://|www\.|[a-z]:\\|(?:^|\s)/(?:[^\s/]+/)+)")
SENSITIVE_WORD = re.compile(
    r"(?i)\b(?:token|secret|subject|serial|imei|advertising[_ -]?id|"
    r"installation[_ -]?id|device[_ -]?id|user[_ -]?id|account[_ -]?id)\b"
)
UTC_TIMESTAMP = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")


class InventoryValidationError(ValueError):
    """Raised when inventory content is not safe and structurally valid."""


def _fail(path: str, message: str) -> None:
    raise InventoryValidationError(f"{path}: {message}")


def _require_object(value: Any, path: str, keys: set[str]) -> dict[str, Any]:
    if not isinstance(value, dict):
        _fail(path, "must be an object")
    actual = set(value)
    if actual != keys:
        missing = sorted(keys - actual)
        unknown = sorted(actual - keys)
        _fail(path, f"exact keys required; missing={missing}, unknown={unknown}")
    return value


def _safe_text(value: Any, path: str, *, max_length: int) -> str:
    if not isinstance(value, str) or value != value.strip() or not value:
        _fail(path, "must be a non-empty trimmed string")
    if len(value) > max_length:
        _fail(path, f"must be at most {max_length} characters")
    if "@" in value or "/" in value or "\\" in value or URL_OR_PATH.search(value):
        _fail(path, "must not contain an email, URL or filesystem path")
    if UUID_LIKE.search(value) or SHA_LIKE.search(value) or LONG_NUMBER.search(value):
        _fail(path, "must not contain UUID/device-ID/SHA-like identifiers")
    if SENSITIVE_WORD.search(value):
        _fail(path, "must not name sensitive identifier or credential fields")
    for character in value:
        if ord(character) < 0x20 and character not in "\t":
            _fail(path, "must not contain control characters")
    return value


def _utc(value: Any, path: str) -> datetime:
    if not isinstance(value, str) or not UTC_TIMESTAMP.fullmatch(value):
        _fail(path, "must be RFC-3339 UTC with whole seconds (YYYY-MM-DDTHH:MM:SSZ)")
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        _fail(path, f"invalid UTC timestamp: {error}")


def _role(value: Any, path: str) -> str:
    if value not in ROLE_CATEGORIES:
        _fail(path, f"must be one of {sorted(ROLE_CATEGORIES)}")
    return value


def _availability(value: Any, path: str, status: str) -> None:
    data = _require_object(value, path, AVAILABILITY_KEYS)
    if status == "AVAILABLE":
        for key, available in data.items():
            if available is not True:
                _fail(f"{path}.{key}", "must be true when slot status is AVAILABLE")
    else:
        for key, available in data.items():
            if available is not None:
                _fail(f"{path}.{key}", "must be null until the slot is AVAILABLE")


def _provider_categories(value: Any, path: str, status: str, platform: str) -> set[str]:
    if not isinstance(value, list) or len(value) != len(set(value)):
        _fail(path, "must be an array without duplicates")
    providers: set[str] = set()
    for index, provider in enumerate(value):
        provider_path = f"{path}[{index}]"
        if not isinstance(provider, str) or not SAFE_SLUG.fullmatch(provider):
            _fail(provider_path, "must be a sanitized provider-category slug")
        # Slug separators are identifier boundaries for redaction purposes.
        # Without normalization, regex word boundaries treat `_` as a word
        # character and values such as device_id_<number> bypass _safe_text.
        _safe_text(provider.replace("_", " "), provider_path, max_length=64)
        providers.add(provider)
    if status == "AVAILABLE":
        if not providers:
            _fail(path, "must not be empty when slot status is AVAILABLE")
        if platform == "ios" and "healthkit" not in providers:
            _fail(path, "available iOS slot must include healthkit")
        if platform == "android" and providers == {"health_connect"}:
            _fail(path, "Health Connect is an API; name at least one sanitized data-provider category")
    return providers


def _validate_slot(slot: Any, index: int, record_status: str) -> set[str]:
    path = f"slots[{index}]"
    data = _require_object(slot, path, SLOT_KEYS)
    slot_id = data["slotId"]
    if slot_id not in SLOT_SPECS:
        _fail(f"{path}.slotId", f"must be one of {list(SLOT_ORDER)}")
    spec = SLOT_SPECS[slot_id]
    if data["required"] is not True:
        _fail(f"{path}.required", "must be true")
    status = data["status"]
    if record_status == "TEMPLATE":
        if status != "OWNER_INPUT_REQUIRED":
            _fail(f"{path}.status", "template slots must remain OWNER_INPUT_REQUIRED")
    elif status not in {"AVAILABLE", "BLOCKED"}:
        _fail(f"{path}.status", "recorded slots must be AVAILABLE or BLOCKED")

    for key in ("platform", "deviceCategory", "healthApi"):
        if data[key] != spec[key]:
            _fail(f"{path}.{key}", f"must equal {spec[key]!r}")
    if data["watchCategory"] not in spec["watchCategories"]:
        _fail(
            f"{path}.watchCategory",
            f"must be one of {sorted(spec['watchCategories'])}",
        )

    if status == "AVAILABLE":
        _safe_text(data["deviceModel"], f"{path}.deviceModel", max_length=80)
        _safe_text(
            data["operatingSystemVersion"],
            f"{path}.operatingSystemVersion",
            max_length=40,
        )
        _role(data["ownerRole"], f"{path}.ownerRole")
        if data["blockerCategory"] is not None or data["blockerReason"] is not None:
            _fail(path, "AVAILABLE slot must not contain blocker fields")
    elif status == "BLOCKED":
        for key, maximum in (("deviceModel", 80), ("operatingSystemVersion", 40)):
            if data[key] is not None:
                _safe_text(data[key], f"{path}.{key}", max_length=maximum)
        if data["ownerRole"] is not None:
            _role(data["ownerRole"], f"{path}.ownerRole")
        if data["blockerCategory"] not in BLOCKER_CATEGORIES:
            _fail(f"{path}.blockerCategory", f"must be one of {sorted(BLOCKER_CATEGORIES)}")
        _safe_text(data["blockerReason"], f"{path}.blockerReason", max_length=160)
    else:
        if data["deviceModel"] is not None or data["operatingSystemVersion"] is not None:
            _fail(path, "OWNER_INPUT_REQUIRED template slot must not claim device/OS values")
        if data["ownerRole"] is not None:
            _fail(f"{path}.ownerRole", "must be null in the committed template")
        if data["blockerCategory"] != "owner_input_required":
            _fail(f"{path}.blockerCategory", "must equal owner_input_required")
        _safe_text(data["blockerReason"], f"{path}.blockerReason", max_length=160)

    providers = _provider_categories(
        data["providerCategories"],
        f"{path}.providerCategories",
        status,
        data["platform"],
    )
    _availability(data["availability"], f"{path}.availability", status)
    return providers if status == "AVAILABLE" and data["platform"] == "android" else set()


def validate_inventory(data: Any, *, require_recorded: bool = False) -> None:
    root = _require_object(data, "$", TOP_LEVEL_KEYS)
    if root["schemaVersion"] != SCHEMA_VERSION:
        _fail("schemaVersion", f"must equal {SCHEMA_VERSION!r}")
    record_status = root["recordStatus"]
    if record_status not in {"TEMPLATE", "RECORDED"}:
        _fail("recordStatus", "must be TEMPLATE or RECORDED")
    if require_recorded and record_status != "RECORDED":
        _fail("recordStatus", "--require-recorded rejects a template")

    if record_status == "TEMPLATE":
        for key in ("recordedAtUtc", "reviewedAtUtc", "inventoryOwnerRole", "reviewerRole"):
            if root[key] is not None:
                _fail(key, "must be null in the committed template")
    else:
        recorded = _utc(root["recordedAtUtc"], "recordedAtUtc")
        reviewed = _utc(root["reviewedAtUtc"], "reviewedAtUtc")
        if reviewed < recorded:
            _fail("reviewedAtUtc", "must not precede recordedAtUtc")
        _role(root["inventoryOwnerRole"], "inventoryOwnerRole")
        _role(root["reviewerRole"], "reviewerRole")

    baseline = _require_object(root["baseline"], "baseline", BASELINE_KEYS)
    for key, expected in BASELINE.items():
        if baseline[key] != expected:
            _fail(f"baseline.{key}", f"must equal the alpha-rc3 value {expected!r}")
    for key in ("masterAnchorSha", "artifactSourceSha", "treeSha"):
        if not LOWER_SHA.fullmatch(baseline[key]):
            _fail(f"baseline.{key}", "must be a lowercase 40-hex SHA")

    evidence = _require_object(root["evidence"], "evidence", EVIDENCE_KEYS)
    if evidence["redactionPolicy"] != REDACTION_POLICY:
        _fail("evidence.redactionPolicy", f"must equal {REDACTION_POLICY!r}")
    if record_status == "TEMPLATE":
        if evidence["storageCategory"] is not None:
            _fail("evidence.storageCategory", "must be null in the committed template")
    elif evidence["storageCategory"] not in STORAGE_CATEGORIES:
        _fail("evidence.storageCategory", f"must be one of {sorted(STORAGE_CATEGORIES)}")

    slots = root["slots"]
    if not isinstance(slots, list):
        _fail("slots", "must be an array")
    ids = [slot.get("slotId") if isinstance(slot, dict) else None for slot in slots]
    if ids != list(SLOT_ORDER):
        _fail("slots", f"must contain each mandatory slot once in order {list(SLOT_ORDER)}")
    android_providers: set[str] = set()
    android_available = 0
    android_blocked = 0
    for index, slot in enumerate(slots):
        providers = _validate_slot(slot, index, record_status)
        if slot["platform"] == "android" and slot["status"] == "AVAILABLE":
            android_available += 1
            android_providers.update(providers - {"health_connect"})
        if slot["platform"] == "android" and slot["status"] == "BLOCKED":
            android_blocked += 1
    if record_status == "RECORDED" and android_available == 2 and len(android_providers) < 2:
        _fail("slots", "two available Android slots must expose two distinct data-provider categories")
    if record_status == "RECORDED" and android_available < 2 and android_blocked == 0:
        _fail("slots", "unavailable Android coverage must be explicit BLOCKED")


def _unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise InventoryValidationError(f"duplicate JSON object key: {key}")
        result[key] = value
    return result


def load_inventory(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=_unique_object)
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise InventoryValidationError(f"cannot read strict UTF-8 JSON: {error}") from error


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("inventory", type=Path)
    parser.add_argument(
        "--require-recorded",
        action="store_true",
        help="reject TEMPLATE and require a reviewed inventory record",
    )
    args = parser.parse_args(argv)
    try:
        validate_inventory(load_inventory(args.inventory), require_recorded=args.require_recorded)
    except InventoryValidationError as error:
        print(f"Health device inventory invalid: {error}", file=sys.stderr)
        return 1
    print(f"Health device inventory valid: {args.inventory}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
