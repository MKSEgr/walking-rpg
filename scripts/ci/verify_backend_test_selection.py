#!/usr/bin/env python3
"""Fail when a backend test is omitted from or duplicated across CI selectors."""

from __future__ import annotations

import collections
import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parents[2]
CI_WORKFLOW = ROOT / ".github/workflows/ci.yml"
RESTORE_RUNNER = ROOT / "scripts/operations/run-synthetic-backup-restore-drill.sh"
TEST_ROOT = ROOT / "backend/src/test/java"
DEDICATED_TESTS = {"BackupRestoreDrillIntegrationTest"}


def fail(message: str) -> None:
    raise SystemExit(f"Backend CI test selection error: {message}")


def selected_tests(workflow: str) -> list[str]:
    selections = re.findall(r"-Dtest=([A-Za-z0-9_,*?]+)", workflow)
    if not selections:
        fail("no -Dtest selectors found in .github/workflows/ci.yml")
    return [
        name
        for selection in selections
        for name in selection.split(",")
        if name
    ]


def main() -> None:
    discovered = {
        path.stem
        for path in TEST_ROOT.rglob("*Test.java")
        if path.is_file()
    }
    if not discovered:
        fail("no backend *Test.java files discovered")

    missing_dedicated = DEDICATED_TESTS - discovered
    if missing_dedicated:
        fail(f"dedicated tests do not exist: {sorted(missing_dedicated)}")

    selected = selected_tests(CI_WORKFLOW.read_text(encoding="utf-8"))
    counts = collections.Counter(selected)
    expected = discovered - DEDICATED_TESTS

    missing = sorted(expected - counts.keys())
    duplicates = sorted(name for name, count in counts.items() if count != 1)
    unexpected = sorted(counts.keys() - expected)
    if missing:
        fail(f"tests missing from standard CI: {missing}")
    if duplicates:
        fail(f"tests selected more than once: {duplicates}")
    if unexpected:
        fail(f"unknown or dedicated tests selected in standard CI: {unexpected}")

    restore_runner = RESTORE_RUNNER.read_text(encoding="utf-8")
    for name in sorted(DEDICATED_TESTS):
        marker = f"-Dtest={name}"
        if restore_runner.count(marker) != 1:
            fail(f"{name} must be selected exactly once by the restore runner")

    print(
        "Backend CI test selection is complete:",
        f"{len(expected)} standard, {len(DEDICATED_TESTS)} dedicated",
    )


if __name__ == "__main__":
    try:
        main()
    except OSError as error:
        fail(str(error))
