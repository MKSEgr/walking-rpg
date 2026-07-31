#!/usr/bin/env python3
"""Wait until every release-gate check has completed successfully."""

from __future__ import annotations

import json
import os
import subprocess
import time
from dataclasses import dataclass
from typing import Iterable, Mapping


REQUIRED_CHECKS = frozenset(
    {
        "Project structure",
        "Backend · Java 21",
        "Mobile · Flutter 3.44.7",
        "Android host · debug APK",
        "iOS host · simulator debug",
        "Release quality · policy and metadata",
        "Release quality · backend package",
        "Release quality · synthetic backup/restore drill",
        "Release quality · Android unsigned AAB",
        "Release quality · iOS no-codesign app",
    }
)


@dataclass(frozen=True)
class CheckState:
    missing: tuple[str, ...]
    pending: tuple[str, ...]
    failed: tuple[str, ...]

    @property
    def successful(self) -> bool:
        return not self.missing and not self.pending and not self.failed


def evaluate_check_runs(
    runs: Iterable[Mapping[str, object]],
    required: frozenset[str] = REQUIRED_CHECKS,
) -> CheckState:
    latest_by_name: dict[str, Mapping[str, object]] = {}
    for run in runs:
        name = run.get("name")
        if not isinstance(name, str) or name not in required:
            continue
        current = latest_by_name.get(name)
        if current is None or _run_id(run) > _run_id(current):
            latest_by_name[name] = run

    missing = tuple(sorted(required - latest_by_name.keys()))
    pending = tuple(
        sorted(
            name
            for name, run in latest_by_name.items()
            if run.get("status") != "completed"
        )
    )
    failed = tuple(
        sorted(
            name
            for name, run in latest_by_name.items()
            if run.get("status") == "completed"
            and run.get("conclusion") != "success"
        )
    )
    return CheckState(missing=missing, pending=pending, failed=failed)


def _run_id(run: Mapping[str, object]) -> int:
    value = run.get("id")
    return value if isinstance(value, int) else -1


def fetch_check_runs(repository: str, sha: str) -> list[Mapping[str, object]]:
    raw = subprocess.check_output(
        [
            "gh",
            "api",
            f"repos/{repository}/commits/{sha}/check-runs?per_page=100",
        ],
        text=True,
    )
    payload = json.loads(raw)
    runs = payload.get("check_runs")
    if not isinstance(runs, list):
        raise RuntimeError("GitHub check-runs response is malformed")
    return runs


def wait_for_required_checks(
    repository: str,
    sha: str,
    *,
    attempts: int = 90,
    delay_seconds: int = 30,
) -> None:
    for attempt in range(attempts):
        state = evaluate_check_runs(fetch_check_runs(repository, sha))
        if state.failed:
            raise SystemExit(f"Required checks failed: {list(state.failed)}")
        if state.successful:
            print("All standard and release checks completed successfully.")
            return
        print(
            "Waiting for checks; "
            f"missing={list(state.missing)}, "
            f"pending={list(state.pending)}, "
            f"attempt={attempt + 1}/{attempts}"
        )
        time.sleep(delay_seconds)
    raise SystemExit("Timed out waiting for required checks")


def main() -> None:
    wait_for_required_checks(
        os.environ["REPOSITORY"],
        os.environ["CHECK_SHA"],
    )


if __name__ == "__main__":
    main()
