#!/usr/bin/env python3
"""Fail-closed validator for developer-account and app-identity readiness."""

from __future__ import annotations
import argparse
import json
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

import verify_store_readiness_evidence as store_readiness

SCHEMA = "walking-rpg-store-account-readiness-v1"
TOP = {"schemaVersion", "recordStatus", "overallStatus", "recordedAtUtc", "reviewedAtUtc", "legalOperatorRole", "markets", "locales", "stores", "publicUrls", "googleClosedTesting", "approval"}
STORE = {"platform", "accountType", "accountStatus", "appRecordStatus", "applicationId", "ownerRole", "nextActionDueAtUtc", "blockerCategory"}
URL = {"kind", "status", "url", "ownerRole", "nextActionDueAtUtc", "blockerCategory"}
TESTING = {"status", "nextActionDueAtUtc", "blockerCategory"}
APPROVAL = {"productOwnerRole", "releaseOwnerRole"}
UTC = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
APP_ID = re.compile(r"^[a-z][a-z0-9]*(?:\.[a-z][a-z0-9]*){2,}$")
BLOCKERS = {"account_unavailable", "verification_pending", "operator_unapproved", "app_identity_unapproved", "public_url_unavailable", "testing_gate_pending", "access_owner_unassigned", "other_coarse"}


class AccountReadinessError(ValueError): pass


def _fail(path: str, message: str) -> None: raise AccountReadinessError(f"{path}: {message}")


def _object(value: Any, path: str, keys: set[str]) -> dict[str, Any]:
    if not isinstance(value, dict): _fail(path, "must be an object")
    missing, unknown = sorted(keys - value.keys()), sorted(value.keys() - keys)
    if missing or unknown: _fail(path, f"keys mismatch; missing={missing}, unknown={unknown}")
    return value


def _time(value: Any, path: str) -> datetime:
    if not isinstance(value, str) or not UTC.fullmatch(value): _fail(path, "must be an exact UTC timestamp ending in Z")
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def _role(value: Any, path: str) -> None:
    if value not in {"product_owner", "release_owner", "store_account_owner", "legal_operator"}: _fail(path, "must be an approved coarse role")


def _blocked(status: str, due: Any, blocker: Any, path: str) -> None:
    if status == "BLOCKED":
        _time(due, f"{path}.nextActionDueAtUtc")
        if blocker not in BLOCKERS: _fail(f"{path}.blockerCategory", "must contain an approved coarse blocker")
    elif due is not None or blocker is not None: _fail(path, "READY fields must not retain blocker metadata")


def validate(data: Any, *, require_recorded: bool = False, require_ready: bool = False) -> None:
    root = _object(data, "$", TOP)
    if root["schemaVersion"] != SCHEMA: _fail("schemaVersion", f"must equal {SCHEMA!r}")
    record = root["recordStatus"]
    overall = root["overallStatus"]
    if record not in {"TEMPLATE", "RECORDED"}: _fail("recordStatus", "must be TEMPLATE or RECORDED")
    if overall not in {"OWNER_INPUT_REQUIRED", "READY", "BLOCKED"}: _fail("overallStatus", "has an unsupported value")
    if require_recorded and record != "RECORDED": _fail("recordStatus", "recorded evidence is required")
    if require_ready and (record != "RECORDED" or overall != "READY"): _fail("overallStatus", "a RECORDED READY result is required")
    stores, urls = root["stores"], root["publicUrls"]
    testing = _object(root["googleClosedTesting"], "googleClosedTesting", TESTING)
    approval = _object(root["approval"], "approval", APPROVAL)
    if not isinstance(stores, list) or not isinstance(urls, list): _fail("$", "stores and publicUrls must be arrays")
    if record == "TEMPLATE":
        expected_testing = {"status": "OWNER_INPUT_REQUIRED", "nextActionDueAtUtc": None, "blockerCategory": None}
        if overall != "OWNER_INPUT_REQUIRED" or root["recordedAtUtc"] is not None or root["reviewedAtUtc"] is not None or root["legalOperatorRole"] is not None or root["markets"] or root["locales"] or stores or urls or testing != expected_testing or any(approval.values()): _fail("$", "committed TEMPLATE must remain empty and owner-input-required")
        return
    recorded_at, reviewed_at = _time(root["recordedAtUtc"], "recordedAtUtc"), _time(root["reviewedAtUtc"], "reviewedAtUtc")
    if reviewed_at < recorded_at: _fail("reviewedAtUtc", "must not precede recordedAtUtc")
    _role(root["legalOperatorRole"], "legalOperatorRole")
    if root["markets"] != ["global"] or root["locales"] != ["en", "ru"]: _fail("markets/locales", "must equal global and ['en', 'ru']")
    if len(stores) != 2: _fail("stores", "must contain exactly Apple and Google")
    ready = True; platforms = set()
    for index, raw in enumerate(stores):
        path = f"stores[{index}]"; item = _object(raw, path, STORE); platform = item["platform"]
        if platform not in {"apple", "google"} or platform in platforms: _fail(f"{path}.platform", "must uniquely identify apple or google")
        platforms.add(platform); _role(item["ownerRole"], f"{path}.ownerRole")
        if item["accountType"] not in {"organization", "individual"}: _fail(f"{path}.accountType", "must be organization or individual")
        if item["accountStatus"] not in {"VERIFIED", "BLOCKED"} or item["appRecordStatus"] not in {"CREATED", "BLOCKED"}: _fail(path, "account/app record status is invalid")
        item_ready = item["accountStatus"] == "VERIFIED" and item["appRecordStatus"] == "CREATED"
        if item_ready:
            if not isinstance(item["applicationId"], str) or not APP_ID.fullmatch(item["applicationId"]): _fail(f"{path}.applicationId", "must be a final reverse-domain identifier")
        elif item["applicationId"] is not None: _fail(f"{path}.applicationId", "must be null while blocked")
        _blocked("READY" if item_ready else "BLOCKED", item["nextActionDueAtUtc"], item["blockerCategory"], path); ready &= item_ready
    if len(urls) != 3: _fail("publicUrls", "must contain privacy, support and deletion")
    kinds = set()
    for index, raw in enumerate(urls):
        path = f"publicUrls[{index}]"; item = _object(raw, path, URL); kind = item["kind"]
        if kind not in {"privacy", "support", "deletion"} or kind in kinds: _fail(f"{path}.kind", "must uniquely identify privacy, support or deletion")
        kinds.add(kind); _role(item["ownerRole"], f"{path}.ownerRole")
        if item["status"] == "READY": store_readiness._public_https(item["url"], f"{path}.url")
        elif item["status"] == "BLOCKED" and item["url"] is None: pass
        else: _fail(path, "must be READY with a public URL or BLOCKED without one")
        _blocked(item["status"], item["nextActionDueAtUtc"], item["blockerCategory"], path); ready &= item["status"] == "READY"
    if testing["status"] not in {"CONFIRMED", "BLOCKED"}: _fail("googleClosedTesting.status", "must be CONFIRMED or BLOCKED")
    _blocked("READY" if testing["status"] == "CONFIRMED" else "BLOCKED", testing["nextActionDueAtUtc"], testing["blockerCategory"], "googleClosedTesting"); ready &= testing["status"] == "CONFIRMED"
    if approval != {"productOwnerRole": "product_owner", "releaseOwnerRole": "release_owner"}: _fail("approval", "must contain product and release owner review")
    if overall != ("READY" if ready else "BLOCKED"): _fail("overallStatus", "must match the recorded component outcomes")


def _unique(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result = {}
    for key, value in pairs:
        if key in result: raise AccountReadinessError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("evidence", type=Path); parser.add_argument("--require-recorded", action="store_true"); parser.add_argument("--require-ready", action="store_true"); args = parser.parse_args(argv)
    try: validate(json.loads(args.evidence.read_text(encoding="utf-8"), object_pairs_hook=_unique), require_recorded=args.require_recorded, require_ready=args.require_ready)
    except (OSError, UnicodeError, json.JSONDecodeError, AccountReadinessError, store_readiness.StoreReadinessError) as error: print(f"Store account readiness invalid: {error}", file=sys.stderr); return 1
    print(f"Store account readiness valid: {args.evidence}"); return 0


if __name__ == "__main__": raise SystemExit(main())
