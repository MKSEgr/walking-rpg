#!/usr/bin/env python3
"""Reject mutable container inputs in the protected backend Dockerfile."""

from __future__ import annotations

import re
import shlex
import sys
from dataclasses import dataclass
from fnmatch import translate as translate_fnmatch
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DOCKERFILE = ROOT / "backend" / "Dockerfile"
FROM_START = re.compile(r"^\s*from(?:\s|$)", re.IGNORECASE)
HEREDOC_INSTRUCTION = re.compile(
    r"^\s*(?P<instruction>copy|run)(?:\s|$)", re.IGNORECASE
)
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
SHELL_TOKEN_BOUNDARIES = frozenset(" \t\r\n;&|()<>")
SHELL_COMMAND_START_WORDS = frozenset(("do", "elif", "else", "then"))
DOCKERFILE_VARIABLE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
ARG_INSTRUCTION = re.compile(
    r"^\s*arg\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)"
    r"(?:=(?P<value>.*))?$",
    re.IGNORECASE,
)
ENV_INSTRUCTION = re.compile(r"^\s*env(?:\s|$)(?P<body>.*)$", re.IGNORECASE)
SHELL_ASSIGNMENT = re.compile(
    r"(?P<name>[A-Za-z_][A-Za-z0-9_]*)=(?P<value>.*)"
)
SHELL_PERSISTENT_ASSIGNMENT_COMMANDS = frozenset(
    ("declare", "export", "local", "readonly", "typeset")
)
SHELL_GLOB_LITERAL_SENTINELS = {
    "*": "\ue000",
    "?": "\ue001",
    "[": "\ue002",
    "]": "\ue003",
}


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
class DockerVariable:
    value: str | None
    package_manager: bool


@dataclass(frozen=True)
class VariableExpansion:
    start: int
    end: int
    name: str
    modifier: str


@dataclass(frozen=True)
class ShellLine:
    line_number: int
    text: str
    variables: tuple[tuple[str, DockerVariable], ...]
    run_start: bool


@dataclass(frozen=True)
class DockerfileScan:
    shell_lines: tuple[ShellLine, ...]
    dockerfile_instructions: tuple[tuple[int, str], ...]
    errors: tuple[tuple[int, str], ...]


def _is_complete_shell_word(line: str, start: int, end: int) -> bool:
    return (
        (start == 0 or line[start - 1] in SHELL_TOKEN_BOUNDARIES)
        and (end == len(line) or line[end] in SHELL_TOKEN_BOUNDARIES)
    )


def _variable_expansions(value: str) -> tuple[VariableExpansion, ...]:
    expansions: list[VariableExpansion] = []
    index = 0
    while index < len(value):
        if value[index] != "$":
            index += 1
            continue

        if value.startswith("${", index):
            name = SHELL_WORD.match(value, index + 2)
            if name is None:
                index += 2
                continue
            depth = 1
            cursor = name.end()
            while cursor < len(value):
                if value.startswith("${", cursor):
                    depth += 1
                    cursor += 2
                    continue
                if value[cursor] == "}":
                    depth -= 1
                    if depth == 0:
                        expansions.append(
                            VariableExpansion(
                                index,
                                cursor + 1,
                                name.group(),
                                value[name.end() : cursor],
                            )
                        )
                        index = cursor + 1
                        break
                cursor += 1
            else:
                index += 2
            continue

        name = SHELL_WORD.match(value, index + 1)
        if name is None:
            index += 1
            continue
        expansions.append(
            VariableExpansion(index, name.end(), name.group(), "")
        )
        index = name.end()
    return tuple(expansions)


def _variable_references(value: str) -> frozenset[str]:
    references: set[str] = set()
    pending = [value]
    while pending:
        for expansion in _variable_expansions(pending.pop()):
            references.add(expansion.name)
            if expansion.modifier:
                pending.append(expansion.modifier)
    return frozenset(references)


def _trim_pattern_spans(value: str) -> tuple[tuple[int, int], ...]:
    spans: list[tuple[int, int]] = []
    pending = [(value, 0)]
    while pending:
        fragment, offset = pending.pop()
        for expansion in _variable_expansions(fragment):
            modifier_start = expansion.start + 2 + len(expansion.name)
            trim_operator = next(
                (
                    operator
                    for operator in ("##", "%%", "#", "%")
                    if expansion.modifier.startswith(operator)
                ),
                None,
            )
            if trim_operator is not None:
                spans.append(
                    (
                        offset + modifier_start + len(trim_operator),
                        offset + expansion.end - 1,
                    )
                )
            if expansion.modifier:
                pending.append(
                    (expansion.modifier, offset + modifier_start)
                )
    return tuple(sorted(spans))


def _protect_quoted_glob_characters(value: str) -> str:
    protected: list[str] = []
    quote: str | None = None
    pattern_starts = dict(_trim_pattern_spans(value))
    pattern_quotes: list[tuple[int, str | None]] = []
    index = 0
    while index < len(value):
        while pattern_quotes and pattern_quotes[-1][0] == index:
            _, quote = pattern_quotes.pop()
        pattern_end = pattern_starts.get(index)
        if pattern_end is not None and quote != "'":
            pattern_quotes.append((pattern_end, quote))
            quote = None

        character = value[index]
        if quote is not None:
            if (
                quote == '"'
                and character == "\\"
                and index + 1 < len(value)
                and value[index + 1] in {'$', '`', '"', "\\", "\n"}
            ):
                protected.extend((character, value[index + 1]))
                index += 2
                continue
            if character == quote:
                quote = None
                protected.append(character)
            else:
                protected.append(
                    SHELL_GLOB_LITERAL_SENTINELS.get(character, character)
                )
            index += 1
            continue
        if character in {"'", '"'}:
            quote = character
            protected.append(character)
            index += 1
            continue
        if character == "\\" and index + 1 < len(value):
            protected.append(character)
            index += 1
            character = value[index]
            protected.append(
                SHELL_GLOB_LITERAL_SENTINELS.get(character, character)
            )
            index += 1
            continue
        protected.append(character)
        index += 1
    return "".join(protected)


def _restore_quoted_glob_characters(value: str) -> str:
    for character, sentinel in SHELL_GLOB_LITERAL_SENTINELS.items():
        value = value.replace(sentinel, character)
    return value


def _resolve_variable_expansion(
    expansion: VariableExpansion,
    variables: dict[str, DockerVariable],
    *,
    depth: int,
    preserve_glob_literals: bool,
) -> DockerVariable:
    variable = variables.get(expansion.name)
    known_value = "" if variable is None else variable.value
    package_manager = False if variable is None else variable.package_manager
    modifier = expansion.modifier

    if not modifier:
        return DockerVariable(known_value, package_manager)
    if modifier.startswith(":-"):
        fallback = _resolve_docker_variable(
            modifier[2:],
            variables,
            depth=depth + 1,
            preserve_glob_literals=preserve_glob_literals,
        )
        if known_value:
            return DockerVariable(known_value, package_manager)
        if known_value is None:
            return DockerVariable(
                None, package_manager or fallback.package_manager
            )
        return fallback
    if modifier.startswith(":+"):
        alternate = _resolve_docker_variable(
            modifier[2:],
            variables,
            depth=depth + 1,
            preserve_glob_literals=preserve_glob_literals,
        )
        if known_value is None:
            return DockerVariable(None, alternate.package_manager)
        if not known_value:
            return DockerVariable("", False)
        return alternate

    trim_operator = next(
        (
            operator
            for operator in ("##", "%%", "#", "%")
            if modifier.startswith(operator)
        ),
        None,
    )
    if trim_operator is not None:
        pattern = _resolve_docker_variable(
            modifier[len(trim_operator) :],
            variables,
            depth=depth + 1,
            preserve_glob_literals=True,
        )
        if known_value is None or pattern.value is None:
            return DockerVariable(None, True)
        trimmed = _trim_variable_value(
            known_value, pattern.value, trim_operator
        )
        return DockerVariable(
            trimmed,
            FORBIDDEN_PACKAGE_MANAGER.search(trimmed) is not None,
        )

    return DockerVariable(None, True)


def _trim_variable_value(value: str, pattern: str, operator: str) -> str:
    if operator == "#":
        ends = range(len(value) + 1)
        return next(
            (
                value[end:]
                for end in ends
                if _shell_pattern_matches(value[:end], pattern)
            ),
            value,
        )
    if operator == "##":
        ends = range(len(value), -1, -1)
        return next(
            (
                value[end:]
                for end in ends
                if _shell_pattern_matches(value[:end], pattern)
            ),
            value,
        )
    if operator == "%":
        starts = range(len(value), -1, -1)
        return next(
            (
                value[:start]
                for start in starts
                if _shell_pattern_matches(value[start:], pattern)
            ),
            value,
        )

    starts = range(len(value) + 1)
    return next(
        (
            value[:start]
            for start in starts
            if _shell_pattern_matches(value[start:], pattern)
        ),
        value,
    )


def _shell_pattern_matches(value: str, pattern: str) -> bool:
    translated = translate_fnmatch(pattern)
    for character, sentinel in SHELL_GLOB_LITERAL_SENTINELS.items():
        translated = translated.replace(sentinel, re.escape(character))
    return re.match(translated, value) is not None


def _resolve_docker_variable(
    value: str,
    variables: dict[str, DockerVariable],
    *,
    depth: int = 0,
    preserve_glob_literals: bool = False,
) -> DockerVariable:
    if depth > 20:
        return DockerVariable(None, True)

    resolved: list[str] = []
    package_manager = False
    unresolved = False
    position = 0
    for expansion in _variable_expansions(value):
        literal = value[position : expansion.start]
        resolved.append(literal)
        package_manager = package_manager or (
            FORBIDDEN_PACKAGE_MANAGER.search(literal) is not None
        )
        replacement = _resolve_variable_expansion(
            expansion,
            variables,
            depth=depth,
            preserve_glob_literals=preserve_glob_literals,
        )
        package_manager = package_manager or replacement.package_manager
        if replacement.value is None:
            unresolved = True
        else:
            resolved.append(replacement.value)
        position = expansion.end

    literal = value[position:]
    resolved.append(literal)
    package_manager = package_manager or (
        FORBIDDEN_PACKAGE_MANAGER.search(literal) is not None
    )
    resolved_value = None if unresolved else "".join(resolved)
    if resolved_value is not None and not preserve_glob_literals:
        resolved_value = _restore_quoted_glob_characters(resolved_value)
    return DockerVariable(
        resolved_value,
        package_manager
        or (
            resolved_value is not None
            and FORBIDDEN_PACKAGE_MANAGER.search(resolved_value) is not None
        ),
    )


def _docker_variable(
    value: str, variables: dict[str, DockerVariable]
) -> DockerVariable:
    return _resolve_docker_variable(value, variables)


def _environment_assignments(instruction: str) -> tuple[tuple[str, str], ...]:
    match = ENV_INSTRUCTION.fullmatch(instruction)
    if match is None:
        return ()
    try:
        words = shlex.split(
            _protect_quoted_glob_characters(match.group("body")),
            comments=False,
            posix=True,
        )
    except ValueError:
        return ()
    if not words:
        return ()

    if "=" not in words[0]:
        name = words[0]
        if DOCKERFILE_VARIABLE.fullmatch(name) is None:
            return ()
        return ((name, " ".join(words[1:])),)

    assignments: list[tuple[str, str]] = []
    for word in words:
        name, separator, value = word.partition("=")
        if not separator or DOCKERFILE_VARIABLE.fullmatch(name) is None:
            return ()
        assignments.append((name, value))
    return tuple(assignments)


def _effective_variables(
    argument_values: dict[str, DockerVariable],
    environment_values: dict[str, DockerVariable],
) -> dict[str, DockerVariable]:
    variables = dict(argument_values)
    variables.update(environment_values)
    return variables


def _effective_package_manager_aliases(
    argument_values: dict[str, DockerVariable],
    environment_values: dict[str, DockerVariable],
) -> frozenset[str]:
    return frozenset(
        name
        for name, variable in _effective_variables(
            argument_values, environment_values
        ).items()
        if variable.package_manager
    )


def _variable_snapshot(
    argument_values: dict[str, DockerVariable],
    environment_values: dict[str, DockerVariable],
) -> tuple[tuple[str, DockerVariable], ...]:
    return tuple(
        sorted(_effective_variables(argument_values, environment_values).items())
    )


def _shell_command_uses_package_manager_assignment(
    tokens: list[str], variables: dict[str, DockerVariable]
) -> bool:
    if not tokens:
        return False

    command_variables = dict(variables)
    assignments: list[tuple[str, DockerVariable]] = []
    index = 0
    while index < len(tokens):
        assignment = SHELL_ASSIGNMENT.fullmatch(tokens[index])
        if assignment is None:
            break
        variable = _docker_variable(
            assignment.group("value"), command_variables
        )
        command_variables[assignment.group("name")] = variable
        assignments.append((assignment.group("name"), variable))
        index += 1

    dangerous = any(variable.package_manager for _, variable in assignments)
    if index == len(tokens):
        variables.update(assignments)
        return dangerous

    dangerous = (
        _shell_executable_uses_package_manager(
            tokens, index, variables
        )
        or dangerous
    )

    if tokens[index] not in SHELL_PERSISTENT_ASSIGNMENT_COMMANDS:
        return dangerous

    for token in tokens[index + 1 :]:
        assignment = SHELL_ASSIGNMENT.fullmatch(token)
        if assignment is None:
            continue
        variable = _docker_variable(assignment.group("value"), variables)
        variables[assignment.group("name")] = variable
        dangerous = dangerous or variable.package_manager
    return dangerous


def _shell_executable_uses_package_manager(
    tokens: list[str],
    index: int,
    variables: dict[str, DockerVariable],
) -> bool:
    while index < len(tokens):
        executable = _docker_variable(tokens[index], variables)
        if executable.package_manager or executable.value is None:
            return True
        command = executable.value.rsplit("/", 1)[-1]
        index += 1

        if command == "command":
            while index < len(tokens):
                resolved_option = _docker_variable(tokens[index], variables)
                if resolved_option.value is None:
                    return True
                option = resolved_option.value
                if option == "--":
                    index += 1
                    break
                if option == "-p":
                    index += 1
                    continue
                if option in {"-v", "-V"}:
                    return False
                if option.startswith("-"):
                    return True
                break
            continue

        if command == "exec":
            while index < len(tokens):
                resolved_option = _docker_variable(tokens[index], variables)
                if resolved_option.value is None:
                    return True
                option = resolved_option.value
                if option == "--":
                    index += 1
                    break
                if option == "-a":
                    if index + 1 >= len(tokens):
                        return True
                    index += 2
                    continue
                if option.startswith("-") and set(option[1:]) <= {"c", "l"}:
                    index += 1
                    continue
                if option.startswith("-"):
                    return True
                break
            continue

        if command == "nohup":
            if index < len(tokens):
                resolved_option = _docker_variable(tokens[index], variables)
                if resolved_option.value is None:
                    return True
                if resolved_option.value == "--":
                    index += 1
                elif resolved_option.value.startswith("-"):
                    return resolved_option.value not in {
                        "--help",
                        "--version",
                    }
            continue

        if command == "env":
            while index < len(tokens):
                resolved_option = _docker_variable(tokens[index], variables)
                if resolved_option.value is None:
                    return True
                option = resolved_option.value
                if option in {"--", "-"}:
                    index += 1
                    break
                if option in {"-i", "--ignore-environment"}:
                    index += 1
                    continue
                if option in {"-u", "--unset", "-C", "--chdir", "-a", "--argv0"}:
                    if index + 1 >= len(tokens):
                        return True
                    index += 2
                    continue
                if option.startswith(
                    ("--unset=", "--chdir=", "--argv0=")
                ):
                    index += 1
                    continue
                if option in {"-S", "--split-string"} or option.startswith(
                    "--split-string="
                ):
                    return True
                if option.startswith("-"):
                    return True
                break

            while index < len(tokens):
                resolved = _docker_variable(tokens[index], variables)
                if resolved.package_manager or resolved.value is None:
                    return True
                assignment = SHELL_ASSIGNMENT.fullmatch(resolved.value)
                if assignment is None:
                    break
                index += 1
            continue

        return False
    return False


def _shell_line_uses_package_manager_assignment(
    line: str,
    variables: dict[str, DockerVariable],
    *,
    run_start: bool,
) -> bool:
    if run_start:
        instruction = HEREDOC_INSTRUCTION.match(line)
        if instruction is not None:
            line = line[instruction.end() :]
    line = _protect_quoted_glob_characters(line)
    try:
        lexer = shlex.shlex(
            line,
            posix=True,
            punctuation_chars=";&|()",
        )
        lexer.whitespace_split = True
        lexer.commenters = ""
        tokens = list(lexer)
    except ValueError:
        return False

    dangerous = False
    command: list[str] = []
    for token in tokens:
        if token and all(character in ";&|()" for character in token):
            dangerous = (
                _shell_command_uses_package_manager_assignment(
                    command, variables
                )
                or dangerous
            )
            command = []
        else:
            command.append(token)
    return (
        _shell_command_uses_package_manager_assignment(command, variables)
        or dangerous
    )


def _update_dockerfile_variables(
    instruction: str,
    *,
    seen_from: bool,
    global_argument_values: dict[str, DockerVariable],
    argument_values: dict[str, DockerVariable],
    environment_values: dict[str, DockerVariable],
) -> None:
    argument = ARG_INSTRUCTION.fullmatch(instruction)
    if argument is not None:
        name = argument.group("name")
        value = argument.group("value")
        if not seen_from:
            global_argument_values[name] = (
                DockerVariable("", False)
                if value is None
                else _docker_variable(value, global_argument_values)
            )
        elif value is None:
            argument_values[name] = argument_values.get(
                name,
                global_argument_values.get(name, DockerVariable("", False)),
            )
        else:
            variables = dict(global_argument_values)
            variables.update(
                _effective_variables(argument_values, environment_values)
            )
            argument_values[name] = _docker_variable(value, variables)
        return

    assignments = _environment_assignments(instruction)
    if not assignments:
        return
    variables = _effective_variables(
        argument_values, environment_values
    )
    updates = {
        name: _docker_variable(value, variables)
        for name, value in assignments
    }
    environment_values.update(updates)


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
            complete_word = _is_complete_shell_word(
                line,
                word.start(),
                word.end(),
            )
            expansion_level = len(parenthesized_expansions)
            in_command = parenthesized_expansions[-1][0] == "command"
            if active_case is None:
                if (
                    in_command
                    and command_starts.get(expansion_level, False)
                    and complete_word
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
                if (
                    command_starts.get(expansion_level, False)
                    and complete_word
                    and value == "esac"
                ):
                    shell_cases.pop()
                    command_starts[expansion_level] = False
                elif (
                    command_starts.get(expansion_level, False)
                    and complete_word
                    and value == "case"
                ):
                    shell_cases.append(
                        ShellCase(expansion_level)
                    )
            if in_command and active_case is None and value != "case":
                command_starts[expansion_level] = (
                    complete_word and value in SHELL_COMMAND_START_WORDS
                )
            elif in_command and active_case is not None and active_case.phase == "body":
                command_starts[expansion_level] = (
                    complete_word and value in SHELL_COMMAND_START_WORDS
                )
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
    shell_lines: list[ShellLine] = []
    dockerfile_instructions: list[tuple[int, str]] = []
    errors: list[tuple[int, str]] = []
    physical_lines = source.splitlines()
    current = ""
    start_line = 0
    line_index = 0
    seen_from = False
    global_argument_values: dict[str, DockerVariable] = {}
    argument_values: dict[str, DockerVariable] = {}
    environment_values: dict[str, DockerVariable] = {}

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
        dockerfile_instructions.append(instruction)
        if FROM_START.match(current):
            seen_from = True
            argument_values = {}
            environment_values = {}
        else:
            _update_dockerfile_variables(
                current,
                seen_from=seen_from,
                global_argument_values=global_argument_values,
                argument_values=argument_values,
                environment_values=environment_values,
            )
        heredoc_instruction = HEREDOC_INSTRUCTION.match(current)
        run_instruction = (
            heredoc_instruction is not None
            and heredoc_instruction.group("instruction").lower() == "run"
        )
        if run_instruction:
            shell_lines.append(
                ShellLine(
                    start_line,
                    current,
                    _variable_snapshot(argument_values, environment_values),
                    True,
                )
            )
        if heredoc_instruction is not None:
            declarations, declaration_errors = _here_document_declarations(current)
        else:
            declarations, declaration_errors = (), ()
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

            if run_instruction:
                variables = _variable_snapshot(
                    argument_values, environment_values
                )
                shell_lines.extend(
                    ShellLine(line_number, text, variables, False)
                    for line_number, text in _shell_logical_lines(
                        body, declaration.strip_tabs
                    )
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
                    tuple(shell_lines),
                    tuple(dockerfile_instructions),
                    tuple(errors),
                )

    if start_line != 0:
        instruction = (start_line, current)
        dockerfile_instructions.append(instruction)
        if FROM_START.match(current):
            argument_values = {}
            environment_values = {}
        else:
            _update_dockerfile_variables(
                current,
                seen_from=seen_from,
                global_argument_values=global_argument_values,
                argument_values=argument_values,
                environment_values=environment_values,
            )
        heredoc_instruction = HEREDOC_INSTRUCTION.match(current)
        if (
            heredoc_instruction is not None
            and heredoc_instruction.group("instruction").lower() == "run"
        ):
            shell_lines.append(
                ShellLine(
                    start_line,
                    current,
                    _variable_snapshot(argument_values, environment_values),
                    True,
                )
            )
    return DockerfileScan(
        tuple(shell_lines),
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
    shell_variables: dict[str, DockerVariable] = {}
    for shell_line in scan.shell_lines:
        if shell_line.run_start:
            shell_variables = dict(shell_line.variables)
        package_manager_aliases = frozenset(
            name
            for name, variable in shell_variables.items()
            if variable.package_manager
        )
        aliases = _variable_references(shell_line.text).intersection(
            package_manager_aliases
        )
        composed_assignment = _shell_line_uses_package_manager_assignment(
            shell_line.text,
            shell_variables,
            run_start=shell_line.run_start,
        )
        if (
            FORBIDDEN_PACKAGE_MANAGER.search(shell_line.text) is None
            and not aliases
            and not composed_assignment
        ):
            continue
        alias_suffix = (
            f" via alias ${sorted(aliases)[0]}" if aliases else ""
        )
        assignment_suffix = (
            " via a composed shell assignment"
            if composed_assignment and not aliases
            else ""
        )
        errors.append(
            f"{path}:{shell_line.line_number}: protected build must not fetch "
            "mutable OS packages through a package manager"
            f"{alias_suffix}"
            f"{assignment_suffix}"
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
