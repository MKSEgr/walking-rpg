#!/usr/bin/env python3
"""Validate strict synthetic backup/restore evidence without dependencies."""

from __future__ import annotations

import hashlib
import hmac
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


EVIDENCE_SCHEMA = "walking-rpg-backup-restore-evidence-v1"
SYNTHETIC_SCOPE = "SYNTHETIC_CI"
FLYWAY_VERSION = "32"
POSTGRES_IMAGE_TAG = "postgres:17.10-alpine3.24"
POSTGRES_IMAGE_DIGEST = (
    "sha256:742f40ea20b9ff2ff31db5458d127452988a2164df9e17441e191f3b72252193"
)
POSTGRES_IMAGE = f"postgres@{POSTGRES_IMAGE_DIGEST}"
ARCHIVE_NAME = "walking-rpg-synthetic.dump"
ARCHIVE_CHECKSUM_NAME = "walking-rpg-synthetic.dump.sha256"
TOC_NAME = "archive.toc"
EVIDENCE_NAME = "evidence.json"
EVIDENCE_CHECKSUM_NAME = "evidence.json.sha256"
FULL_FILES = {
    ARCHIVE_NAME,
    ARCHIVE_CHECKSUM_NAME,
    TOC_NAME,
    EVIDENCE_NAME,
    EVIDENCE_CHECKSUM_NAME,
}
RECEIPT_FILES = {EVIDENCE_NAME, EVIDENCE_CHECKSUM_NAME}
SHA256 = re.compile(r"^[0-9a-f]{64}$")
SOURCE_SHA = re.compile(r"^[0-9a-f]{40}$")
UTC_INSTANT = re.compile(
    r"^(?P<whole>[0-9]{4}-[0-9]{2}-[0-9]{2}"
    r"T[0-9]{2}:[0-9]{2}:[0-9]{2})"
    r"(?:\.(?P<fraction>[0-9]{1,9}))?Z$"
)
CHECKSUM_LINE = re.compile(r"^([0-9a-f]{64})  ([A-Za-z0-9._-]+)\n?$")
REQUIRED_RESTORE_FLAGS = [
    "--single-transaction",
    "--exit-on-error",
    "--no-owner",
    "--no-privileges",
    "--no-tablespaces",
]
EXPECTED_TABLES = {
    "account_deletion_receipt",
    "activity_risk_assessment",
    "activity_sync_state",
    "app_device",
    "app_user",
    "content_release",
    "economy_ledger",
    "economy_wallet",
    "equipment_slot_state",
    "expedition_progress",
    "first_journey_milestone",
    "flyway_schema_history",
    "inventory_ledger",
    "inventory_stack",
    "payment_intent",
    "pet_progress",
    "pilot_progress",
    "platform_crash_report",
    "platform_cosmetic_slot_state",
    "platform_event",
    "processed_activity_sync",
    "processed_crafting_command",
    "processed_crafting_ingredient",
    "processed_item_upgrade_command",
    "processed_item_upgrade_ingredient",
    "processed_equipment_command",
    "processed_event_resolution",
    "processed_expedition_advance",
    "processed_roadmap_command",
    "push_registration",
    "remote_config_snapshot",
    "roadmap_squad",
    "roadmap_squad_member",
    "roadmap_user_state",
    "tester_cohort_member",
    "unique_inventory_item",
}
TOP_LEVEL_KEYS = {
    "schemaVersion",
    "scope",
    "productionValidated",
    "actualProductionDrillRequired",
    "sourceGitSha",
    "sourceTreeClean",
    "startedAtUtc",
    "completedAtUtc",
    "durationMillis",
    "postgres",
    "archive",
    "restore",
    "flyway",
    "manifests",
}
POSTGRES_KEYS = {
    "image",
    "imageTag",
    "imageDigest",
    "sourceServerVersion",
    "restoreServerVersion",
    "pgDumpVersion",
    "pgRestoreVersion",
}
ARCHIVE_KEYS = {
    "format",
    "file",
    "bytes",
    "sha256",
    "sha256File",
    "tocFile",
    "tocSha256",
    "checksumVerifiedBeforeRestore",
}
RESTORE_KEYS = {"targetInitiallyEmpty", "completed", "flags"}
FLYWAY_KEYS = {
    "latestRepositoryVersion",
    "sourceVersion",
    "restoredVersion",
    "validationSuccessful",
}
MANIFEST_KEYS = {
    "tableCount",
    "applicationTableCount",
    "fixtureCoveredApplicationTableCount",
    "sequenceCount",
    "tableRowCounts",
    "schema",
    "data",
    "sequences",
}
DIGEST_PAIR_KEYS = {"sourceSha256", "restoredSha256", "matched"}


class EvidenceError(RuntimeError):
    pass


def fail(message: str) -> None:
    raise EvidenceError(message)


def reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            fail(f"duplicate JSON key is forbidden: {key}")
        result[key] = value
    return result


def require_exact_keys(
    value: dict[str, Any],
    expected: set[str],
    field: str,
) -> None:
    actual = set(value)
    if actual != expected:
        missing = sorted(expected - actual)
        extra = sorted(actual - expected)
        fail(f"{field} keys differ; missing={missing}, extra={extra}")


def require_directory_contents(directory: Path, expected: set[str]) -> None:
    actual = {path.name for path in directory.iterdir()}
    if actual != expected:
        fail(
            "evidence directory contents differ; "
            f"missing={sorted(expected - actual)}, "
            f"extra={sorted(actual - expected)}"
        )


def regular_file(directory: Path, name: str) -> Path:
    path = directory / name
    if path.is_symlink() or not path.is_file():
        fail(f"required regular file is missing or is a symlink: {name}")
    return path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(64 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def expected_checksum(path: Path, expected_name: str) -> str:
    try:
        line = path.read_text(encoding="ascii")
    except UnicodeError as error:
        fail(f"{path.name} is not ASCII: {error}")
    match = CHECKSUM_LINE.fullmatch(line)
    if match is None or match.group(2) != expected_name:
        fail(f"malformed checksum file: {path.name}")
    return match.group(1)


def require_digest(value: Any, field: str) -> str:
    if not isinstance(value, str) or SHA256.fullmatch(value) is None:
        fail(f"{field} must be a lowercase SHA-256")
    return value


def require_dict(value: Any, field: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        fail(f"{field} must be an object")
    return value


def require_bool(value: Any, expected: bool, field: str) -> None:
    if value is not expected:
        fail(f"{field} must be {str(expected).lower()}")


def require_positive_int(value: Any, field: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
        fail(f"{field} must be a positive integer")
    return value


def parse_instant_nanoseconds(value: Any, field: str) -> int:
    if not isinstance(value, str):
        fail(f"{field} must be a complete RFC3339 UTC instant")
    match = UTC_INSTANT.fullmatch(value)
    if match is None:
        fail(f"{field} must be a complete RFC3339 UTC instant")
    try:
        whole = datetime.fromisoformat(match.group("whole") + "+00:00")
    except ValueError as error:
        fail(f"{field} is invalid: {error}")
    epoch = datetime(1970, 1, 1, tzinfo=timezone.utc)
    whole_seconds = (whole - epoch).days * 86_400 + (whole - epoch).seconds
    fraction = (match.group("fraction") or "").ljust(9, "0")
    return whole_seconds * 1_000_000_000 + int(fraction or "0")


def load_evidence(path: Path) -> dict[str, Any]:
    try:
        text = path.read_text(encoding="utf-8")
        value = json.loads(text, object_pairs_hook=reject_duplicate_keys)
    except (UnicodeError, json.JSONDecodeError) as error:
        fail(f"evidence JSON is invalid: {error}")
    return require_dict(value, "$")


def validate_digest_pair(value: Any, field: str) -> None:
    digest_pair = require_dict(value, field)
    require_exact_keys(digest_pair, DIGEST_PAIR_KEYS, field)
    source = require_digest(
        digest_pair.get("sourceSha256"),
        f"{field}.sourceSha256",
    )
    restored = require_digest(
        digest_pair.get("restoredSha256"),
        f"{field}.restoredSha256",
    )
    require_bool(digest_pair.get("matched"), True, f"{field}.matched")
    if not hmac.compare_digest(source, restored):
        fail(f"{field} source and restored digests differ")


def validate_schema(
    evidence: dict[str, Any],
    expected_source_sha: str,
) -> None:
    require_exact_keys(evidence, TOP_LEVEL_KEYS, "$")
    if evidence.get("schemaVersion") != EVIDENCE_SCHEMA:
        fail("unexpected evidence schemaVersion")
    if evidence.get("scope") != SYNTHETIC_SCOPE:
        fail("evidence scope must remain SYNTHETIC_CI")
    require_bool(evidence.get("productionValidated"), False, "productionValidated")
    require_bool(
        evidence.get("actualProductionDrillRequired"),
        True,
        "actualProductionDrillRequired",
    )
    require_bool(evidence.get("sourceTreeClean"), True, "sourceTreeClean")
    source_git_sha = evidence.get("sourceGitSha")
    if source_git_sha != expected_source_sha:
        fail("sourceGitSha does not match the expected tested commit")

    started = parse_instant_nanoseconds(
        evidence.get("startedAtUtc"),
        "startedAtUtc",
    )
    completed = parse_instant_nanoseconds(
        evidence.get("completedAtUtc"),
        "completedAtUtc",
    )
    duration = require_positive_int(evidence.get("durationMillis"), "durationMillis")
    if completed < started:
        fail("completedAtUtc precedes startedAtUtc")
    observed_duration = (completed - started) // 1_000_000
    if observed_duration != duration:
        fail("durationMillis does not match the evidence timestamps")

    postgres = require_dict(evidence.get("postgres"), "postgres")
    require_exact_keys(postgres, POSTGRES_KEYS, "postgres")
    expected_postgres = {
        "image": POSTGRES_IMAGE,
        "imageTag": POSTGRES_IMAGE_TAG,
        "imageDigest": POSTGRES_IMAGE_DIGEST,
        "sourceServerVersion": "17.10",
        "restoreServerVersion": "17.10",
        "pgDumpVersion": "pg_dump (PostgreSQL) 17.10",
        "pgRestoreVersion": "pg_restore (PostgreSQL) 17.10",
    }
    if postgres != expected_postgres:
        fail("postgres metadata is not the exact approved toolchain")

    archive = require_dict(evidence.get("archive"), "archive")
    require_exact_keys(archive, ARCHIVE_KEYS, "archive")
    if archive.get("format") != "custom":
        fail("archive.format must be custom")
    if archive.get("file") != ARCHIVE_NAME:
        fail("archive.file is unexpected")
    if archive.get("sha256File") != ARCHIVE_CHECKSUM_NAME:
        fail("archive.sha256File is unexpected")
    if archive.get("tocFile") != TOC_NAME:
        fail("archive.tocFile is unexpected")
    require_positive_int(archive.get("bytes"), "archive.bytes")
    require_digest(archive.get("sha256"), "archive.sha256")
    require_digest(archive.get("tocSha256"), "archive.tocSha256")
    require_bool(
        archive.get("checksumVerifiedBeforeRestore"),
        True,
        "archive.checksumVerifiedBeforeRestore",
    )

    restore = require_dict(evidence.get("restore"), "restore")
    require_exact_keys(restore, RESTORE_KEYS, "restore")
    require_bool(restore.get("targetInitiallyEmpty"), True, "restore.targetInitiallyEmpty")
    require_bool(restore.get("completed"), True, "restore.completed")
    if restore.get("flags") != REQUIRED_RESTORE_FLAGS:
        fail("restore.flags must be the exact ordered fail-safe flag list")

    flyway = require_dict(evidence.get("flyway"), "flyway")
    require_exact_keys(flyway, FLYWAY_KEYS, "flyway")
    latest = flyway.get("latestRepositoryVersion")
    source_version = flyway.get("sourceVersion")
    restored_version = flyway.get("restoredVersion")
    if not all(
        isinstance(version, str) and version.isdigit()
        for version in (latest, source_version, restored_version)
    ):
        fail("Flyway versions must be numeric strings")
    if (
        latest != FLYWAY_VERSION
        or source_version != latest
        or restored_version != latest
    ):
        fail(
            "Flyway source/restore versions must match repository "
            f"V{FLYWAY_VERSION}"
        )
    require_bool(
        flyway.get("validationSuccessful"),
        True,
        "flyway.validationSuccessful",
    )

    manifests = require_dict(evidence.get("manifests"), "manifests")
    require_exact_keys(manifests, MANIFEST_KEYS, "manifests")
    if manifests.get("tableCount") != len(EXPECTED_TABLES):
        fail(
            "manifests.tableCount must match the exact "
            f"V{FLYWAY_VERSION} schema"
        )
    if manifests.get("applicationTableCount") != len(EXPECTED_TABLES) - 1:
        fail(
            "manifests.applicationTableCount must match the exact "
            f"V{FLYWAY_VERSION} schema"
        )
    if manifests.get("fixtureCoveredApplicationTableCount") != len(
        EXPECTED_TABLES
    ) - 1:
        fail(
            "the synthetic fixture must cover every "
            f"V{FLYWAY_VERSION} application table"
        )
    if manifests.get("sequenceCount") != 3:
        fail(
            "manifests.sequenceCount must match the exact "
            f"V{FLYWAY_VERSION} schema"
        )

    row_counts = require_dict(
        manifests.get("tableRowCounts"),
        "manifests.tableRowCounts",
    )
    require_exact_keys(
        row_counts,
        EXPECTED_TABLES,
        "manifests.tableRowCounts",
    )
    for table_name, row_count in row_counts.items():
        require_positive_int(
            row_count,
            f"manifests.tableRowCounts.{table_name}",
        )

    validate_digest_pair(manifests.get("schema"), "manifests.schema")
    validate_digest_pair(manifests.get("data"), "manifests.data")
    validate_digest_pair(manifests.get("sequences"), "manifests.sequences")


def validate_evidence_receipt(
    directory: Path,
    expected_source_sha: str,
) -> dict[str, Any]:
    evidence_file = regular_file(directory, EVIDENCE_NAME)
    evidence_checksum = regular_file(directory, EVIDENCE_CHECKSUM_NAME)
    trusted_evidence_sha = expected_checksum(
        evidence_checksum,
        EVIDENCE_NAME,
    )
    actual_evidence_sha = sha256(evidence_file)
    if not hmac.compare_digest(trusted_evidence_sha, actual_evidence_sha):
        fail("evidence SHA-256 does not match its checksum file")
    evidence = load_evidence(evidence_file)
    validate_schema(evidence, expected_source_sha)
    return evidence


def validate_full(directory: Path, expected_source_sha: str) -> None:
    require_directory_contents(directory, FULL_FILES)
    evidence = validate_evidence_receipt(directory, expected_source_sha)
    archive = regular_file(directory, ARCHIVE_NAME)
    archive_checksum = regular_file(directory, ARCHIVE_CHECKSUM_NAME)
    toc = regular_file(directory, TOC_NAME)

    trusted_archive_sha = expected_checksum(
        archive_checksum,
        ARCHIVE_NAME,
    )
    actual_archive_sha = sha256(archive)
    if not hmac.compare_digest(trusted_archive_sha, actual_archive_sha):
        fail("archive SHA-256 does not match its checksum file")

    archive_evidence = require_dict(evidence.get("archive"), "archive")
    if archive_evidence.get("bytes") != archive.stat().st_size:
        fail("archive.bytes does not match the archive")
    if not hmac.compare_digest(
        require_digest(archive_evidence.get("sha256"), "archive.sha256"),
        actual_archive_sha,
    ):
        fail("archive SHA-256 in evidence does not match the archive")
    if not hmac.compare_digest(
        require_digest(archive_evidence.get("tocSha256"), "archive.tocSha256"),
        sha256(toc),
    ):
        fail("TOC SHA-256 in evidence does not match archive.toc")


def validate_receipt(directory: Path, expected_source_sha: str) -> None:
    require_directory_contents(directory, RECEIPT_FILES)
    validate_evidence_receipt(directory, expected_source_sha)


def main(argv: list[str]) -> int:
    if len(argv) != 4 or argv[1] not in {"full", "receipt"}:
        print(
            "usage: verify-backup-restore-evidence.py "
            "{full|receipt} DIRECTORY EXPECTED_SOURCE_GIT_SHA",
            file=sys.stderr,
        )
        return 2
    mode, directory_argument, expected_source_sha = argv[1:]
    if SOURCE_SHA.fullmatch(expected_source_sha) is None:
        print("expected source SHA must be 40 lowercase hex", file=sys.stderr)
        return 2
    try:
        raw_directory = Path(directory_argument).expanduser()
        if raw_directory.is_symlink():
            fail("evidence directory must not be a symlink")
        directory = raw_directory.resolve(strict=True)
        if not directory.is_dir():
            fail("evidence directory must be an existing directory")
        if mode == "full":
            validate_full(directory, expected_source_sha)
        else:
            validate_receipt(directory, expected_source_sha)
    except (EvidenceError, OSError) as error:
        print(
            f"backup/restore evidence verification failed: {error}",
            file=sys.stderr,
        )
        return 1
    if mode == "receipt":
        print(
            "Synthetic evidence receipt verified for the expected commit; "
            "CI-run provenance must be checked separately."
        )
    else:
        print("Full synthetic backup/restore evidence verified.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
