#!/usr/bin/env python3
"""Reject mutable container inputs in the protected backend Dockerfile."""

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
FORBIDDEN_PACKAGE_MANAGER = re.compile(
    r"(?<![0-9A-Za-z_.-])(?:apt-get|apt|apk|dnf|yum|microdnf)"
    r"(?![0-9A-Za-z_.-])",
    re.IGNORECASE,
)
PARSER_DIRECTIVE = re.compile(
    r"^[ \t]*#[ \t]*(?P<key>[A-Za-z][A-Za-z0-9-]*)[ \t]*="
    r"[ \t]*(?P<value>.*?)[ \t]*$"
)
SUPPORTED_PARSER_DIRECTIVES = frozenset(("check", "escape", "syntax"))


@dataclass(frozen=True)
class ApprovedStage:
    image: str
    alias: str | None = None

    @property
    def instruction(self) -> str:
        suffix = f" AS {self.alias}" if self.alias is not None else ""
        return f"FROM {self.image}{suffix}"


@dataclass(frozen=True)
class HereDocument:
    delimiter: str
    strip_tabs: bool


@dataclass(frozen=True)
class DockerfileScan:
    logical_lines: tuple[tuple[int, str], ...]
    errors: tuple[tuple[int, str], ...]


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


def _dockerfile_escape(source: str) -> str:
    escape = "\\"
    for line in source.splitlines():
        if not line.strip():
            break
        match = PARSER_DIRECTIVE.fullmatch(line)
        if match is None:
            break
        key = match.group("key").lower()
        if key not in SUPPORTED_PARSER_DIRECTIVES:
            break
        if key == "escape" and match.group("value") in ("\\", "`"):
            escape = match.group("value")
    return escape


def _here_document_declarations(
    line: str,
) -> tuple[tuple[HereDocument, ...], tuple[str, ...]]:
    declarations: list[HereDocument] = []
    errors: list[str] = []
    index = 0
    quote: str | None = None
    parenthesized_expansions: list[tuple[str, int]] = []

    while index < len(line):
        character = line[index]
        if quote == "'":
            if character == "'":
                quote = None
            index += 1
            continue
        if quote == '"':
            if character == "\\":
                index += 2
            elif character == '"':
                quote = None
                index += 1
            else:
                index += 1
            continue
        if character == "\\":
            index += 2
            continue
        if character in {"'", '"'}:
            quote = character
            index += 1
            continue
        if character == "#" and (
            index == 0 or line[index - 1] in " \t;&|()<>"
        ):
            break
        if line.startswith("$((", index):
            parenthesized_expansions.append(("arithmetic", 2))
            index += 3
            continue
        if parenthesized_expansions and line.startswith("$(", index):
            parenthesized_expansions.append(("command", 1))
            index += 2
            continue
        if parenthesized_expansions and character == "(":
            kind, depth = parenthesized_expansions[-1]
            parenthesized_expansions[-1] = (kind, depth + 1)
            index += 1
            continue
        if parenthesized_expansions and character == ")":
            kind, depth = parenthesized_expansions[-1]
            if depth == 1:
                parenthesized_expansions.pop()
            else:
                parenthesized_expansions[-1] = (kind, depth - 1)
            index += 1
            continue
        if line.startswith("<<<", index):
            index += 3
            continue
        if (
            parenthesized_expansions
            and parenthesized_expansions[-1][0] == "arithmetic"
        ) or not line.startswith("<<", index):
            index += 1
            continue

        index += 2
        strip_tabs = index < len(line) and line[index] == "-"
        if strip_tabs:
            index += 1
        while index < len(line) and line[index] in " \t":
            index += 1

        delimiter: list[str] = []
        delimiter_quote: str | None = None
        consumed = False
        while index < len(line):
            character = line[index]
            if delimiter_quote == "'":
                consumed = True
                if character == "'":
                    delimiter_quote = None
                else:
                    delimiter.append(character)
                index += 1
                continue
            if delimiter_quote == '"':
                consumed = True
                if character == "\\" and index + 1 < len(line):
                    delimiter.append(line[index + 1])
                    index += 2
                elif character == '"':
                    delimiter_quote = None
                    index += 1
                else:
                    delimiter.append(character)
                    index += 1
                continue
            if character in " \t;&|()<>":
                break
            consumed = True
            if character in {"'", '"'}:
                delimiter_quote = character
                index += 1
            elif character == "\\":
                if index + 1 >= len(line):
                    errors.append("here-document delimiter ends with an escape")
                    index = len(line)
                else:
                    delimiter.append(line[index + 1])
                    index += 2
            else:
                delimiter.append(character)
                index += 1

        if delimiter_quote is not None:
            errors.append("unterminated quote in here-document delimiter")
        elif not consumed:
            errors.append("here-document redirection must provide a delimiter")
        else:
            declarations.append(HereDocument("".join(delimiter), strip_tabs))

    return tuple(declarations), tuple(errors)


def _shell_logical_lines(
    body: list[tuple[int, str]], strip_tabs: bool
) -> tuple[tuple[int, str], ...]:
    logical_lines: list[tuple[int, str]] = []
    current = ""
    start_line = 0

    for line_number, raw_line in body:
        line = raw_line.lstrip("\t") if strip_tabs else raw_line
        if start_line == 0:
            start_line = line_number

        trailing_backslashes = len(line) - len(line.rstrip("\\"))
        if trailing_backslashes % 2 == 1:
            current += line[:-1]
            continue

        current += line
        if current.strip() and not current.lstrip().startswith("#"):
            logical_lines.append((start_line, current))
        current = ""
        start_line = 0

    if start_line != 0 and current.strip():
        logical_lines.append((start_line, current))
    return tuple(logical_lines)


def _logical_instruction_lines(source: str) -> DockerfileScan:
    escape = _dockerfile_escape(source)
    continuation = re.compile(rf"{re.escape(escape)}[ \t]*$")
    instructions: list[tuple[int, str]] = []
    errors: list[tuple[int, str]] = []
    physical_lines = source.splitlines()
    current = ""
    start_line = 0
    line_index = 0

    while line_index < len(physical_lines):
        line = physical_lines[line_index]
        line_number = line_index + 1
        line_index += 1
        if line.lstrip().startswith("#") or not line.strip():
            continue
        if start_line == 0:
            start_line = line_number

        match = continuation.search(line)
        if match is not None:
            current += line[: match.start()]
            continue

        current += line
        instructions.append((start_line, current))
        declarations, declaration_errors = _here_document_declarations(current)
        errors.extend((start_line, error) for error in declaration_errors)
        current = ""
        start_line = 0

        for declaration in declarations:
            body: list[tuple[int, str]] = []
            found = False
            while line_index < len(physical_lines):
                body_line = physical_lines[line_index]
                body_line_number = line_index + 1
                line_index += 1
                candidate = (
                    body_line.lstrip("\t")
                    if declaration.strip_tabs
                    else body_line
                )
                if candidate == declaration.delimiter:
                    found = True
                    break
                body.append((body_line_number, body_line))

            instructions.extend(
                _shell_logical_lines(body, declaration.strip_tabs)
            )
            if not found:
                errors.append(
                    (
                        line_number,
                        "unterminated here-document delimiter "
                        f"{declaration.delimiter!r}",
                    )
                )
                return DockerfileScan(tuple(instructions), tuple(errors))

    if start_line != 0:
        instructions.append((start_line, current))
    return DockerfileScan(tuple(instructions), tuple(errors))


def validate_dockerfile_source(source: str, path: Path) -> list[str]:
    errors: list[str] = []
    scan = _logical_instruction_lines(source)
    for line_number, message in scan.errors:
        errors.append(
            f"{path}:{line_number}: cannot safely parse Dockerfile: {message}"
        )
    for line_number, line in scan.logical_lines:
        if FORBIDDEN_PACKAGE_MANAGER.search(line) is None:
            continue
        errors.append(
            f"{path}:{line_number}: protected build must not fetch mutable "
            "OS packages through a package manager"
        )

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
    print(
        "Backend container input policy passed for 2 protected stages "
        "without package-manager fetches."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
