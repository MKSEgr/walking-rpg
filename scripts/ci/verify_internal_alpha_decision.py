#!/usr/bin/env python3
"""Validate the redacted internal-alpha decision record without rounding."""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


SCHEMA = "walking-rpg-internal-alpha-decision-v1"
PROTOCOL = "walking-rpg-internal-alpha-v1"
SHA_RE = re.compile(r"[0-9a-f]{40}")
DIGEST_RE = re.compile(r"[0-9a-f]{64}")
UTC_RE = re.compile(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z")
GAP_CODES = {
    "instrumentation_missing",
    "evidence_corrupt",
    "cohort_invalid",
    "collection_stopped",
}
METRIC_NAMES = [
    "unaidedFirstTenMinutes",
    "stepPermissionAcceptance",
    "firstDayReward",
    "crashFreeSessions",
    "syncErrorRate",
    "instrumentationCoverage",
]


class ContractError(ValueError):
    pass


def _fail(path: str, message: str) -> None:
    raise ContractError(f"{path}: {message}")


def _object_no_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            _fail("$", f"duplicate JSON key {key!r}")
        result[key] = value
    return result


def _keys(value: Any, expected: list[str], path: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        _fail(path, "must be an object")
    actual = list(value)
    if actual != expected:
        _fail(path, f"keys must be exactly {expected} in that order; got {actual}")
    return value


def _integer(value: Any, path: str) -> int:
    if type(value) is not int or value < 0:
        _fail(path, "must be a non-negative integer")
    return value


def _timestamp(value: Any, path: str) -> datetime:
    if not isinstance(value, str) or not UTC_RE.fullmatch(value):
        _fail(path, "must be an RFC 3339 UTC timestamp with whole seconds")
    try:
        parsed = datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    except ValueError as error:
        _fail(path, f"is not a real UTC timestamp ({error})")
    return parsed


def _hash(value: Any, pattern: re.Pattern[str], path: str) -> None:
    if not isinstance(value, str) or not pattern.fullmatch(value):
        _fail(path, f"must match {pattern.pattern}")


def _metric_template(value: Any, path: str) -> None:
    metric = _keys(value, ["status", "numerator", "denominator", "dataGapReasonCode"], path)
    if metric != {
        "status": "OWNER_INPUT_REQUIRED",
        "numerator": None,
        "denominator": None,
        "dataGapReasonCode": None,
    }:
        _fail(path, "template metric must remain unclaimed")


def _metric_decided(value: Any, path: str) -> tuple[str, int | None, int | None]:
    metric = _keys(value, ["status", "numerator", "denominator", "dataGapReasonCode"], path)
    status = metric["status"]
    if status == "DATA_GAP":
        if metric["numerator"] is not None or metric["denominator"] is not None:
            _fail(path, "DATA_GAP must not contain partial counts")
        if metric["dataGapReasonCode"] not in GAP_CODES:
            _fail(f"{path}.dataGapReasonCode", f"must be one of {sorted(GAP_CODES)}")
        return status, None, None
    if status != "MEASURED":
        _fail(f"{path}.status", "must be MEASURED or DATA_GAP in a decided record")
    numerator = _integer(metric["numerator"], f"{path}.numerator")
    denominator = _integer(metric["denominator"], f"{path}.denominator")
    if denominator == 0:
        _fail(f"{path}.denominator", "must be greater than zero")
    if numerator > denominator:
        _fail(path, "numerator must not exceed denominator")
    if metric["dataGapReasonCode"] is not None:
        _fail(f"{path}.dataGapReasonCode", "must be null when status is MEASURED")
    return status, numerator, denominator


def _passes(metric_name: str, numerator: int, denominator: int) -> bool:
    if metric_name == "unaidedFirstTenMinutes":
        return denominator == 12 and numerator >= 9
    if metric_name == "stepPermissionAcceptance":
        return numerator * 100 > denominator * 70
    if metric_name == "firstDayReward":
        return denominator == 12 and numerator * 100 > denominator * 55
    if metric_name == "crashFreeSessions":
        return numerator * 1000 > denominator * 995
    if metric_name == "syncErrorRate":
        return numerator * 100 < denominator
    if metric_name == "instrumentationCoverage":
        return numerator * 100 >= denominator * 95
    raise AssertionError(metric_name)


def validate(document: Any, require_decided: bool = False) -> None:
    root = _keys(document, [
        "schemaVersion", "recordStatus", "recordedAtUtc", "decisionAtUtc",
        "protocol", "candidate", "cohort", "metrics", "qualitative",
        "findings", "decision",
    ], "$")
    if root["schemaVersion"] != SCHEMA:
        _fail("$.schemaVersion", f"must be {SCHEMA}")
    if root["recordStatus"] not in {"TEMPLATE", "DECIDED"}:
        _fail("$.recordStatus", "must be TEMPLATE or DECIDED")

    protocol = _keys(root["protocol"], ["protocolId", "commitSha"], "$.protocol")
    if protocol["protocolId"] != PROTOCOL:
        _fail("$.protocol.protocolId", f"must be {PROTOCOL}")
    candidate = _keys(root["candidate"], [
        "sourceSha", "treeSha", "kickoffRecordSha256", "alphaEvidencePackageSha256",
    ], "$.candidate")
    cohort = _keys(root["cohort"], [
        "invited", "started", "completed", "iosRealUsers", "androidRealUsers",
        "withdrawn", "excluded", "stoppedOrPaused",
    ], "$.cohort")
    metrics = _keys(root["metrics"], METRIC_NAMES, "$.metrics")
    qualitative = _keys(root["qualitative"], [
        "instrumentationInterpretable", "walkingAsAdventureSupported",
        "companionReturnSupported", "dataGapReasonCode",
    ], "$.qualitative")
    findings = _keys(root["findings"], [
        "stopCount", "fixBeforeExpandCount", "experimentCount", "laterCount",
        "openReleaseBlockers",
    ], "$.findings")
    decision = _keys(root["decision"], [
        "selected", "rationaleCode", "nextScope", "authority", "confirmationAtUtc",
    ], "$.decision")
    if decision["authority"] != "MKSEgr":
        _fail("$.decision.authority", "must be MKSEgr")

    if root["recordStatus"] == "TEMPLATE":
        if require_decided:
            _fail("$.recordStatus", "a TEMPLATE is not an owner decision")
        if root["recordedAtUtc"] is not None or root["decisionAtUtc"] is not None:
            _fail("$", "template timestamps must be null")
        if protocol["commitSha"] is not None or any(value is not None for value in candidate.values()):
            _fail("$", "template identity fields must remain null")
        if any(value is not None for value in cohort.values()):
            _fail("$.cohort", "template cohort must remain unclaimed")
        for name in METRIC_NAMES:
            _metric_template(metrics[name], f"$.metrics.{name}")
        if any(value is not None for value in qualitative.values()):
            _fail("$.qualitative", "template qualitative fields must remain unclaimed")
        if any(value is not None for value in findings.values()):
            _fail("$.findings", "template findings must remain unclaimed")
        if decision != {
            "selected": None,
            "rationaleCode": None,
            "nextScope": None,
            "authority": "MKSEgr",
            "confirmationAtUtc": None,
        }:
            _fail("$.decision", "template decision must remain unsigned and unclaimed")
        return

    recorded_at = _timestamp(root["recordedAtUtc"], "$.recordedAtUtc")
    decision_at = _timestamp(root["decisionAtUtc"], "$.decisionAtUtc")
    confirmation_at = _timestamp(decision["confirmationAtUtc"], "$.decision.confirmationAtUtc")
    if not recorded_at <= decision_at <= confirmation_at:
        _fail("$", "timestamps must satisfy recordedAtUtc <= decisionAtUtc <= confirmationAtUtc")
    _hash(protocol["commitSha"], SHA_RE, "$.protocol.commitSha")
    _hash(candidate["sourceSha"], SHA_RE, "$.candidate.sourceSha")
    _hash(candidate["treeSha"], SHA_RE, "$.candidate.treeSha")
    _hash(candidate["kickoffRecordSha256"], DIGEST_RE, "$.candidate.kickoffRecordSha256")
    _hash(candidate["alphaEvidencePackageSha256"], DIGEST_RE, "$.candidate.alphaEvidencePackageSha256")

    cohort_values = {name: _integer(value, f"$.cohort.{name}") for name, value in cohort.items()}
    cohort_limits = {
        "started": "invited",
        "completed": "started",
        "iosRealUsers": "started",
        "androidRealUsers": "started",
        "withdrawn": "invited",
        "excluded": "invited",
        "stoppedOrPaused": "started",
    }
    for value_name, limit_name in cohort_limits.items():
        if cohort_values[value_name] > cohort_values[limit_name]:
            _fail(
                f"$.cohort.{value_name}",
                f"must not exceed cohort.{limit_name}",
            )
    metric_values: dict[str, tuple[str, int | None, int | None]] = {}
    for name in METRIC_NAMES:
        metric_values[name] = _metric_decided(metrics[name], f"$.metrics.{name}")

    bool_values = qualitative.copy()
    gap = bool_values.pop("dataGapReasonCode")
    for name, value in bool_values.items():
        if value is not None and type(value) is not bool:
            _fail(f"$.qualitative.{name}", "must be a boolean or null")
    has_qualitative_gap = any(value is None for value in bool_values.values())
    if has_qualitative_gap and gap not in GAP_CODES:
        _fail("$.qualitative.dataGapReasonCode", f"must be one of {sorted(GAP_CODES)} when a value is null")
    if not has_qualitative_gap and gap is not None:
        _fail("$.qualitative.dataGapReasonCode", "must be null when all values are recorded")

    finding_values = {name: _integer(value, f"$.findings.{name}") for name, value in findings.items()}
    selected = decision["selected"]
    decision_contracts = {
        "EXPAND": ({"thresholds_passed"}, "closed_beta_wave"),
        "FIX_AND_RERUN": ({
            "threshold_miss", "instrumentation_gap", "release_blocker",
            "cohort_invalid", "focused_comprehension_gap",
        }, "focused_fix_and_alpha_rerun"),
        "STOP": ({
            "safety_risk", "operationally_infeasible", "core_value_not_supported",
        }, "stop_and_archive"),
    }
    if selected not in decision_contracts:
        _fail("$.decision.selected", f"must be one of {sorted(decision_contracts)}")
    rationale_codes, next_scope = decision_contracts[selected]
    if decision["rationaleCode"] not in rationale_codes:
        _fail("$.decision.rationaleCode", f"must be one of {sorted(rationale_codes)} for {selected}")
    if decision["nextScope"] != next_scope:
        _fail("$.decision.nextScope", f"must be {next_scope} for {selected}")

    if selected == "EXPAND":
        required_cohort = {
            "invited": 12, "started": 12, "completed": 12,
            "withdrawn": 0, "excluded": 0, "stoppedOrPaused": 0,
        }
        for name, expected in required_cohort.items():
            if cohort_values[name] != expected:
                _fail(f"$.cohort.{name}", f"must be {expected} for EXPAND")
        if cohort_values["iosRealUsers"] < 4 or cohort_values["androidRealUsers"] < 4:
            _fail("$.cohort", "EXPAND requires at least four real users on each platform")
        for name, (status, numerator, denominator) in metric_values.items():
            if status != "MEASURED" or numerator is None or denominator is None:
                _fail(f"$.metrics.{name}", "EXPAND forbids data gaps")
            if not _passes(name, numerator, denominator):
                _fail(f"$.metrics.{name}", "approved threshold is not met")
        if any(value is not True for value in bool_values.values()):
            _fail("$.qualitative", "EXPAND requires all qualitative gates to be true")
        for name in ("stopCount", "fixBeforeExpandCount", "openReleaseBlockers"):
            if finding_values[name] != 0:
                _fail(f"$.findings.{name}", "must be zero for EXPAND")


def _load(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=_object_no_duplicates)
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ContractError(f"{path}: cannot read strict UTF-8 JSON ({error})") from error


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("record", type=Path)
    parser.add_argument("--require-decided", action="store_true")
    args = parser.parse_args()
    try:
        validate(_load(args.record), require_decided=args.require_decided)
    except ContractError as error:
        print(f"internal-alpha decision validation failed: {error}", file=sys.stderr)
        return 1
    print(f"internal-alpha decision record valid: {args.record}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
