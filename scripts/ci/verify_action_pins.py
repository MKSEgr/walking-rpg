#!/usr/bin/env python3
"""Reject mutable or unauditable remote GitHub Action references."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_WORKFLOW_DIRECTORY = ROOT / ".github" / "workflows"
FULL_COMMIT_SHA = re.compile(r"^[0-9a-f]{40}$")
RELEASE_COMMENT = re.compile(
    r"^v[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?$"
)
REMOTE_ACTION_PATH = re.compile(
    r"^[0-9A-Za-z_.-]+/[0-9A-Za-z_.-]+(?:/[0-9A-Za-z_.-]+)*$"
)
IMMUTABLE_DOCKER_ACTION = re.compile(
    r"^docker://[^@\s]+@sha256:[0-9a-f]{64}$"
)
USES_PREFIX = re.compile(r"^\s*(?:-\s*)?uses\s*:")
USES_LINE = re.compile(
    r"^\s*(?:-\s*)?uses\s*:\s*"
    r"(?:\"(?P<double>[^\"]+)\"|'(?P<single>[^']+)'|(?P<plain>[^#\s]+))"
    r"\s*(?:#\s*(?P<comment>.+?))?\s*$"
)


def workflow_files(workflow_directory: Path) -> tuple[Path, ...]:
    return tuple(
        sorted(
            (*workflow_directory.glob("*.yml"), *workflow_directory.glob("*.yaml")),
            key=lambda path: path.name,
        )
    )


def validate_workflows(workflow_directory: Path) -> list[str]:
    errors: list[str] = []
    files = workflow_files(workflow_directory)
    if not files:
        return [f"{workflow_directory}: no workflow YAML files found"]

    for path in files:
        for line_number, line in enumerate(
            path.read_text(encoding="utf-8").splitlines(), start=1
        ):
            if not USES_PREFIX.match(line):
                continue
            match = USES_LINE.fullmatch(line)
            location = f"{path}:{line_number}"
            if match is None:
                errors.append(f"{location}: malformed uses declaration")
                continue

            reference = next(
                value
                for value in (
                    match.group("double"),
                    match.group("single"),
                    match.group("plain"),
                )
                if value is not None
            )
            comment = (match.group("comment") or "").strip()

            if reference.startswith("./"):
                continue
            if reference.startswith("docker://"):
                if not IMMUTABLE_DOCKER_ACTION.fullmatch(reference):
                    errors.append(
                        f"{location}: Docker action must use an exact sha256 digest"
                    )
                if not comment:
                    errors.append(
                        f"{location}: Docker action digest needs a reviewed image comment"
                    )
                continue

            action_path, separator, revision = reference.rpartition("@")
            if (
                not separator
                or not REMOTE_ACTION_PATH.fullmatch(action_path)
                or not FULL_COMMIT_SHA.fullmatch(revision)
            ):
                errors.append(
                    f"{location}: remote action must use owner/repository@"
                    "<40-character lowercase commit SHA>"
                )
                continue
            if not RELEASE_COMMENT.fullmatch(comment):
                errors.append(
                    f"{location}: pinned action needs an exact release comment such as "
                    "# v4.4.0"
                )

    return errors


def main() -> int:
    errors = validate_workflows(DEFAULT_WORKFLOW_DIRECTORY)
    if errors:
        for error in errors:
            print(f"GitHub Action pin policy error: {error}")
        return 1
    print(
        "GitHub Action pin policy passed for "
        f"{len(workflow_files(DEFAULT_WORKFLOW_DIRECTORY))} workflow files."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
