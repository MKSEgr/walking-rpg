#!/usr/bin/env python3

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from wait_for_required_checks import REQUIRED_CHECKS, evaluate_check_runs


def run(name: str, status: str, conclusion: str | None, run_id: int) -> dict:
    return {
        "id": run_id,
        "name": name,
        "status": status,
        "conclusion": conclusion,
    }


def successful_runs() -> list[dict]:
    return [
        run(name, "completed", "success", index)
        for index, name in enumerate(sorted(REQUIRED_CHECKS), start=1)
    ]


class RequiredChecksTest(unittest.TestCase):

    def test_accepts_only_when_every_required_check_succeeded(self) -> None:
        self.assertTrue(evaluate_check_runs(successful_runs()).successful)

    def test_rejects_skipped_required_check(self) -> None:
        runs = successful_runs()
        runs[0] = run(runs[0]["name"], "completed", "skipped", 100)

        state = evaluate_check_runs(runs)

        self.assertEqual((runs[0]["name"],), state.failed)
        self.assertFalse(state.successful)

    def test_rejects_neutral_required_check(self) -> None:
        runs = successful_runs()
        runs[0] = run(runs[0]["name"], "completed", "neutral", 100)

        state = evaluate_check_runs(runs)

        self.assertEqual((runs[0]["name"],), state.failed)

    def test_waits_for_pending_and_missing_checks(self) -> None:
        runs = successful_runs()
        pending_name = runs[0]["name"]
        missing_name = runs[1]["name"]
        runs[0] = run(pending_name, "in_progress", None, 100)
        del runs[1]

        state = evaluate_check_runs(runs)

        self.assertEqual((pending_name,), state.pending)
        self.assertEqual((missing_name,), state.missing)
        self.assertFalse(state.failed)

    def test_uses_latest_check_run_for_duplicate_name(self) -> None:
        runs = successful_runs()
        name = runs[0]["name"]
        runs.append(run(name, "completed", "failure", 99))
        runs.append(run(name, "completed", "success", 100))

        self.assertTrue(evaluate_check_runs(runs).successful)


if __name__ == "__main__":
    unittest.main()
