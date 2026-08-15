#!/usr/bin/env python3
"""Regression tests for the retained/full evidence verifier."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("verify-backup-restore-evidence.py")
SPEC = importlib.util.spec_from_file_location("backup_evidence_verifier", SCRIPT)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("evidence verifier module could not be loaded")
VERIFIER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VERIFIER)

SOURCE_SHA = "a" * 40
DIGEST = "b" * 64


def valid_evidence() -> dict[str, object]:
    digest_pair = {
        "sourceSha256": DIGEST,
        "restoredSha256": DIGEST,
        "matched": True,
    }
    return {
        "schemaVersion": VERIFIER.EVIDENCE_SCHEMA,
        "scope": VERIFIER.SYNTHETIC_SCOPE,
        "productionValidated": False,
        "actualProductionDrillRequired": True,
        "sourceGitSha": SOURCE_SHA,
        "sourceTreeClean": True,
        "startedAtUtc": "2026-07-30T10:00:00Z",
        "completedAtUtc": "2026-07-30T10:00:01Z",
        "durationMillis": 1_000,
        "postgres": {
            "image": VERIFIER.POSTGRES_IMAGE,
            "imageTag": VERIFIER.POSTGRES_IMAGE_TAG,
            "imageDigest": VERIFIER.POSTGRES_IMAGE_DIGEST,
            "sourceServerVersion": "17.10",
            "restoreServerVersion": "17.10",
            "pgDumpVersion": "pg_dump (PostgreSQL) 17.10",
            "pgRestoreVersion": "pg_restore (PostgreSQL) 17.10",
        },
        "archive": {
            "format": "custom",
            "file": VERIFIER.ARCHIVE_NAME,
            "bytes": 1,
            "sha256": DIGEST,
            "sha256File": VERIFIER.ARCHIVE_CHECKSUM_NAME,
            "tocFile": VERIFIER.TOC_NAME,
            "tocSha256": DIGEST,
            "checksumVerifiedBeforeRestore": True,
        },
        "restore": {
            "targetInitiallyEmpty": True,
            "completed": True,
            "flags": list(VERIFIER.REQUIRED_RESTORE_FLAGS),
        },
        "flyway": {
            "latestRepositoryVersion": VERIFIER.FLYWAY_VERSION,
            "sourceVersion": VERIFIER.FLYWAY_VERSION,
            "restoredVersion": VERIFIER.FLYWAY_VERSION,
            "validationSuccessful": True,
        },
        "manifests": {
            "tableCount": len(VERIFIER.EXPECTED_TABLES),
            "applicationTableCount": len(VERIFIER.EXPECTED_TABLES) - 1,
            "fixtureCoveredApplicationTableCount": (
                len(VERIFIER.EXPECTED_TABLES) - 1
            ),
            "sequenceCount": 3,
            "tableRowCounts": {
                table_name: 1
                for table_name in sorted(VERIFIER.EXPECTED_TABLES)
            },
            "schema": dict(digest_pair),
            "data": dict(digest_pair),
            "sequences": dict(digest_pair),
        },
    }


def write_receipt(
    directory: Path,
    evidence: dict[str, object],
    raw_json: str | None = None,
) -> None:
    content = raw_json
    if content is None:
        content = json.dumps(evidence, indent=2, sort_keys=True) + "\n"
    evidence_path = directory / VERIFIER.EVIDENCE_NAME
    evidence_path.write_text(content, encoding="utf-8")
    digest = hashlib.sha256(content.encode("utf-8")).hexdigest()
    (directory / VERIFIER.EVIDENCE_CHECKSUM_NAME).write_text(
        f"{digest}  {VERIFIER.EVIDENCE_NAME}\n",
        encoding="ascii",
    )


def write_full(directory: Path, evidence: dict[str, object]) -> None:
    archive_content = b"synthetic archive"
    toc_content = b"synthetic table of contents\n"
    archive_path = directory / VERIFIER.ARCHIVE_NAME
    toc_path = directory / VERIFIER.TOC_NAME
    archive_path.write_bytes(archive_content)
    toc_path.write_bytes(toc_content)
    archive_digest = hashlib.sha256(archive_content).hexdigest()
    archive = evidence["archive"]
    assert isinstance(archive, dict)
    archive["bytes"] = len(archive_content)
    archive["sha256"] = archive_digest
    archive["tocSha256"] = hashlib.sha256(toc_content).hexdigest()
    (directory / VERIFIER.ARCHIVE_CHECKSUM_NAME).write_text(
        f"{archive_digest}  {VERIFIER.ARCHIVE_NAME}\n",
        encoding="ascii",
    )
    write_receipt(directory, evidence)


class EvidenceVerifierTest(unittest.TestCase):

    def receipt_directory(self) -> tuple[tempfile.TemporaryDirectory, Path]:
        temporary = tempfile.TemporaryDirectory()
        return temporary, Path(temporary.name)

    def test_accepts_exact_retained_receipt(self) -> None:
        temporary, directory = self.receipt_directory()
        self.addCleanup(temporary.cleanup)
        write_receipt(directory, valid_evidence())

        VERIFIER.validate_receipt(directory, SOURCE_SHA)

    def test_accepts_exact_full_evidence(self) -> None:
        temporary, directory = self.receipt_directory()
        self.addCleanup(temporary.cleanup)
        write_full(directory, valid_evidence())

        VERIFIER.validate_full(directory, SOURCE_SHA)

    def test_rejects_duplicate_json_keys_with_recomputed_checksum(self) -> None:
        temporary, directory = self.receipt_directory()
        self.addCleanup(temporary.cleanup)
        evidence = valid_evidence()
        raw = json.dumps(evidence)
        raw = raw.replace(
            '"scope": "SYNTHETIC_CI"',
            '"scope": "SYNTHETIC_CI", "scope": "SYNTHETIC_CI"',
            1,
        )
        write_receipt(directory, evidence, raw)

        with self.assertRaisesRegex(
            VERIFIER.EvidenceError,
            "duplicate JSON key",
        ):
            VERIFIER.validate_receipt(directory, SOURCE_SHA)

    def test_rejects_unknown_privacy_sensitive_field(self) -> None:
        temporary, directory = self.receipt_directory()
        self.addCleanup(temporary.cleanup)
        evidence = valid_evidence()
        evidence["requestBody"] = "raw user payload"
        write_receipt(directory, evidence)

        with self.assertRaisesRegex(VERIFIER.EvidenceError, "extra="):
            VERIFIER.validate_receipt(directory, SOURCE_SHA)

    def test_rejects_date_only_timestamp(self) -> None:
        temporary, directory = self.receipt_directory()
        self.addCleanup(temporary.cleanup)
        evidence = valid_evidence()
        evidence["startedAtUtc"] = "2026-07-30Z"
        write_receipt(directory, evidence)

        with self.assertRaisesRegex(VERIFIER.EvidenceError, "RFC3339"):
            VERIFIER.validate_receipt(directory, SOURCE_SHA)

    def test_rejects_duration_that_differs_by_exactly_one_second(self) -> None:
        temporary, directory = self.receipt_directory()
        self.addCleanup(temporary.cleanup)
        evidence = valid_evidence()
        evidence["durationMillis"] = 2_000
        write_receipt(directory, evidence)

        with self.assertRaisesRegex(VERIFIER.EvidenceError, "durationMillis"):
            VERIFIER.validate_receipt(directory, SOURCE_SHA)

    def test_rejects_unexpected_source_commit(self) -> None:
        temporary, directory = self.receipt_directory()
        self.addCleanup(temporary.cleanup)
        write_receipt(directory, valid_evidence())

        with self.assertRaisesRegex(VERIFIER.EvidenceError, "sourceGitSha"):
            VERIFIER.validate_receipt(directory, "c" * 40)

    def test_rejects_recomputed_receipt_with_wrong_schema_key(self) -> None:
        temporary, directory = self.receipt_directory()
        self.addCleanup(temporary.cleanup)
        evidence = valid_evidence()
        postgres = evidence["postgres"]
        assert isinstance(postgres, dict)
        postgres["password"] = "not-allowed"
        write_receipt(directory, evidence)

        with self.assertRaisesRegex(VERIFIER.EvidenceError, "postgres keys"):
            VERIFIER.validate_receipt(directory, SOURCE_SHA)

    def test_receipt_mode_rejects_unretained_archive(self) -> None:
        temporary, directory = self.receipt_directory()
        self.addCleanup(temporary.cleanup)
        write_receipt(directory, valid_evidence())
        (directory / VERIFIER.ARCHIVE_NAME).write_bytes(b"x")

        with self.assertRaisesRegex(
            VERIFIER.EvidenceError,
            "directory contents differ",
        ):
            VERIFIER.validate_receipt(directory, SOURCE_SHA)

    def test_full_mode_rejects_receipt_only_directory(self) -> None:
        temporary, directory = self.receipt_directory()
        self.addCleanup(temporary.cleanup)
        write_receipt(directory, valid_evidence())

        with self.assertRaisesRegex(
            VERIFIER.EvidenceError,
            "directory contents differ",
        ):
            VERIFIER.validate_full(directory, SOURCE_SHA)


if __name__ == "__main__":
    unittest.main()
