#!/usr/bin/env python3
"""Reject mutable or superseded base images in the protected Dockerfile."""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DOCKERFILE = ROOT / "backend" / "Dockerfile"
FROM_START = re.compile(r"^\s*from(?:\s|$)", re.IGNORECASE)
FROM_INSTRUCTION = re.compile(
    r"^FROM\s+(?P<image>\S+)(?:\s+AS\s+(?P<alias>[0-9A-Za-z_.-]+))?$",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class ApprovedStage:
    image: str
    alias: str | None = None

    @property
    def instruction(self) -> str:
        suffix = f" AS {self.alias}" if self.alias is not None else ""
        return f"FROM {self.image}{suffix}"


# These are reviewed multi-platform OCI index digests. Keep the publisher's
# independent constants aligned so historical sources cannot weaken this gate.
APPROVED_STAGES = (
    ApprovedStage(
        "eclipse-temurin:21-jdk-jammy@sha256:"
        "55fb9bf738f5d9b4a6c01b39337e3070d3e27370dd3c478fd1d5d3cd2233c6d8",
        "build",
    ),
    ApprovedStage(
        "eclipse-temurin:21-jre-jammy@sha256:"
        "3097cbbebb7d490494a98aed2301f284b38f79eba158eef098c6fc8c8af11c23"
    ),
)


def _from_lines(source: str) -> tuple[tuple[int, str], ...]:
    return tuple(
        (line_number, line.strip())
        for line_number, line in enumerate(source.splitlines(), start=1)
        if FROM_START.match(line)
    )


def validate_dockerfile_source(source: str, path: Path) -> list[str]:
    errors: list[str] = []
    instructions = _from_lines(source)
    if len(instructions) != len(APPROVED_STAGES):
        errors.append(
            f"{path}: expected exactly {len(APPROVED_STAGES)} FROM instructions, "
            f"found {len(instructions)}"
        )

    for index, approved in enumerate(APPROVED_STAGES):
        if index >= len(instructions):
            errors.append(
                f"{path}: missing protected stage {index + 1}: "
                f"{approved.instruction}"
            )
            continue

        line_number, instruction = instructions[index]
        location = f"{path}:{line_number}"
        match = FROM_INSTRUCTION.fullmatch(instruction)
        if match is None:
            errors.append(
                f"{location}: FROM instruction must be the literal reviewed "
                "tag@sha256 reference without platform or expressions"
            )
            continue

        if match.group("image") != approved.image:
            errors.append(
                f"{location}: protected stage {index + 1} must use "
                f"{approved.image}"
            )
        if match.group("alias") != approved.alias:
            expected_alias = approved.alias or "no alias"
            errors.append(
                f"{location}: protected stage {index + 1} must use "
                f"{expected_alias}"
            )
        if instruction != approved.instruction:
            errors.append(
                f"{location}: protected FROM instruction must use canonical "
                f"form: {approved.instruction}"
            )

    for line_number, _ in instructions[len(APPROVED_STAGES) :]:
        errors.append(f"{path}:{line_number}: unexpected additional build stage")

    return errors


def validate_dockerfile(path: Path) -> list[str]:
    try:
        source = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
        return [f"{path}: cannot read protected Dockerfile: {error}"]
    return validate_dockerfile_source(source, path)


def main() -> int:
    errors = validate_dockerfile(DEFAULT_DOCKERFILE)
    if errors:
        for error in errors:
            print(f"Backend base image pin policy error: {error}")
        return 1
    print("Backend base image pin policy passed for 2 protected stages.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
