#!/usr/bin/env python3
"""Reject mutable container inputs in the protected backend Dockerfile."""

from __future__ import annotations

import re
import sys
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
SHELL_WORD = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


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


@dataclass
class ShellCase:
    expansion_level: int
    phase: str = "awaiting-in"
    pattern_parentheses: int = 0


@dataclass(frozen=True)
class DockerfileScan:
    logical_lines: tuple[tuple[int, str], ...]
    dockerfile_instructions: tuple[tuple[int, str], ...]
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


def _from_lines(
    instructions: tuple[tuple[int, str], ...],
) -> tuple[tuple[int, str], ...]:
    return tuple(
        (line_number, line.strip())
        for line_number, line in instructions
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
    shell_cases: list[ShellCase] = []
    command_starts: dict[int, bool] = {}

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
            command_starts[len(parenthesized_expansions)] = True
            index += 2
            continue
        active_case = (
            shell_cases[-1]
            if shell_cases
            and shell_cases[-1].expansion_level
            == len(parenthesized_expansions)
            else None
        )
        word = SHELL_WORD.match(line, index)
        if parenthesized_expansions and word is not None:
            value = word.group()
            expansion_level = len(parenthesized_expansions)
            in_command = parenthesized_expansions[-1][0] == "command"
            if active_case is None:
                if (
                    in_command
                    and command_starts.get(expansion_level, False)
                    and value == "case"
                ):
                    shell_cases.append(
                        ShellCase(expansion_level)
                    )
            elif active_case.phase == "awaiting-in" and value == "in":
                active_case.phase = "pattern"
            elif active_case.phase == "pattern" and value == "esac":
                shell_cases.pop()
                command_starts[expansion_level] = False
            elif active_case.phase == "body":
                if value == "esac":
                    shell_cases.pop()
                    command_starts[expansion_level] = False
                elif command_starts.get(expansion_level, False) and value == "case":
                    shell_cases.append(
                        ShellCase(expansion_level)
                    )
            if in_command and active_case is None and value != "case":
                command_starts[expansion_level] = value in {
                    "do",
                    "elif",
                    "else",
                    "then",
                }
            elif in_command and active_case is not None and active_case.phase == "body":
                command_starts[expansion_level] = False
            index = word.end()
            continue
        if (
            active_case is not None
            and active_case.phase == "body"
            and (
                line.startswith(";;&", index)
                or line.startswith(";;", index)
                or line.startswith(";&", index)
            )
        ):
            active_case.phase = "pattern"
            command_starts[len(parenthesized_expansions)] = False
            index += 3 if line.startswith(";;&", index) else 2
            continue
        if (
            parenthesized_expansions
            and parenthesized_expansions[-1][0] == "command"
            and character in ";|&"
        ):
            command_starts[len(parenthesized_expansions)] = True
            index += 1
            continue
        if parenthesized_expansions and character == "(":
            if active_case is not None and active_case.phase == "pattern":
                active_case.pattern_parentheses += 1
            kind, depth = parenthesized_expansions[-1]
            parenthesized_expansions[-1] = (kind, depth + 1)
            index += 1
            continue
        if parenthesized_expansions and character == ")":
            if active_case is not None and active_case.phase == "pattern":
                if active_case.pattern_parentheses == 0:
                    active_case.phase = "body"
                    command_starts[len(parenthesized_expansions)] = True
                    index += 1
                    continue
                active_case.pattern_parentheses -= 1
                if active_case.pattern_parentheses == 0:
                    active_case.phase = "body"
                    command_starts[len(parenthesized_expansions)] = True
            kind, depth = parenthesized_expansions[-1]
            if depth == 1:
                closing_level = len(parenthesized_expansions)
                parenthesized_expansions.pop()
                command_starts.pop(closing_level, None)
                shell_cases = [
                    statement
                    for statement in shell_cases
                    if statement.expansion_level < closing_level
                ]
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
    logical_lines: list[tuple[int, str]] = []
    dockerfile_instructions: list[tuple[int, str]] = []
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
        instruction = (start_line, current)
        logical_lines.append(instruction)
        dockerfile_instructions.append(instruction)
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

            logical_lines.extend(
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
                return DockerfileScan(
                    tuple(logical_lines),
                    tuple(dockerfile_instructions),
                    tuple(errors),
                )

    if start_line != 0:
        instruction = (start_line, current)
        logical_lines.append(instruction)
        dockerfile_instructions.append(instruction)
    return DockerfileScan(
        tuple(logical_lines),
        tuple(dockerfile_instructions),
        tuple(errors),
    )


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

    instructions = _from_lines(scan.dockerfile_instructions)
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


def main(arguments: tuple[str, ...] | None = None) -> int:
    if arguments is None:
        arguments = tuple(sys.argv[1:])
    if len(arguments) > 1:
        print(
            "Backend base image pin policy error: usage: "
            "verify_backend_base_pins.py [Dockerfile]"
        )
        return 2

    dockerfile = Path(arguments[0]) if arguments else DEFAULT_DOCKERFILE
    errors = validate_dockerfile(dockerfile)
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
