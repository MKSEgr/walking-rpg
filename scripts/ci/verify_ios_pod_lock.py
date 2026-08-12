#!/usr/bin/env python3
"""Require a reviewed CocoaPods lock and frozen installs in protected iOS CI."""

from __future__ import annotations

import hashlib
import re
import shlex
import subprocess
from collections.abc import Mapping, Sequence
from pathlib import Path

import yaml
from yaml.nodes import MappingNode, Node, ScalarNode, SequenceNode
from yaml.tokens import AliasToken, AnchorToken


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_LOCKFILE = ROOT / "mobile" / "ios" / "Podfile.lock"
DEFAULT_PODFILE = ROOT / "mobile" / "ios" / "Podfile"
DEFAULT_WORKFLOW_DIRECTORY = ROOT / ".github" / "workflows"
EXPECTED_PYYAML_VERSION = "6.0.3"
APPROVED_COCOAPODS_VERSION = "1.17.0"
APPROVED_LOCK_SHA256 = (
    "4c2f02da8db46306fa8b80d6a3afc6810976f658ae6db0a9c9474cb23357637a"
)
EXPECTED_IOS_JOBS = {
    "ci.yml": "ios-host",
    "release-quality.yml": "ios-release",
}
INSTALL_STEP_NAME = "Install locked iOS pods"
VERIFY_STEP_NAME = "Verify iOS pod lock unchanged"
INSTALL_SCRIPT = (
    "set -euo pipefail",
    "cd ios",
    "test \"$(pod --version)\" = '1.17.0'",
    "pod install --deployment",
    "git diff --exit-code -- Podfile.lock",
)
VERIFY_SCRIPT = ("git diff --exit-code -- ios/Podfile.lock",)
REQUIRED_LOCK_KEYS = {
    "PODS",
    "DEPENDENCIES",
    "SPEC REPOS",
    "EXTERNAL SOURCES",
    "SPEC CHECKSUMS",
    "PODFILE CHECKSUM",
    "COCOAPODS",
}
MERGE_TAG = "tag:yaml.org,2002:merge"
CONTROL_CHARACTERS = frozenset(";&|()\n")
ASSIGNMENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=.*$", re.DOTALL)
REDIRECTION_FD = re.compile(r"^(?:[0-9]+|\{[A-Za-z_][A-Za-z0-9_]*\})$")
REDIRECTION_OPERATORS = frozenset(
    {"<", ">", "<<", "<<-", "<<<", ">>", "<>", ">|", "<&", ">&", "&>", "&>>"}
)
SHELLS = frozenset({"bash", "dash", "sh", "zsh"})
SIMPLE_WRAPPERS = frozenset(
    {"builtin", "command", "exec", "fvm", "nohup", "time"}
)
XARGS_SHORT_OPTIONS_WITH_VALUES = frozenset(
    {"a", "d", "E", "I", "J", "L", "n", "P", "R", "S", "s"}
)
XARGS_SHORT_OPTIONS_WITH_OPTIONAL_VALUES = frozenset({"e", "i", "l"})
XARGS_LONG_OPTIONS_WITH_VALUES = frozenset(
    {
        "--arg-file",
        "--delimiter",
        "--max-args",
        "--max-chars",
        "--max-lines",
        "--max-procs",
        "--process-slot-var",
    }
)
RESERVED_PREFIXES = frozenset(
    {"!", "do", "elif", "else", "if", "then", "until", "while", "{", "}"}
)
COMMAND_SUBSTITUTION_PLACEHOLDER = "__reviewed_command_substitution__"
POD_DECLARATION = re.compile(
    r"^(?P<name>[A-Za-z0-9_.+-]+(?:/[A-Za-z0-9_.+-]+)?) "
    r"\((?P<version>[^)]+)\)$"
)
PLUGIN_PATH = re.compile(
    r"^(?:Flutter|\.symlinks/plugins/[A-Za-z0-9_.+-]+/(?:ios|darwin))$"
)


def _location(path: Path, node: Node) -> str:
    return f"{path}:{node.start_mark.line + 1}:{node.start_mark.column + 1}"


def _yaml_error(path: Path, error: yaml.YAMLError) -> str:
    mark = getattr(error, "problem_mark", None)
    if mark is None:
        return f"{path}: invalid YAML: {error}"
    problem = getattr(error, "problem", None) or "invalid YAML"
    return f"{path}:{mark.line + 1}:{mark.column + 1}: invalid YAML: {problem}"


def _structure_errors(path: Path, root: Node) -> list[str]:
    errors: list[str] = []
    pending: list[Node] = [root]
    visited: set[int] = set()
    while pending:
        node = pending.pop()
        if id(node) in visited:
            continue
        visited.add(id(node))
        if isinstance(node, MappingNode):
            seen: dict[str, ScalarNode] = {}
            for key, value in node.value:
                if not isinstance(key, ScalarNode):
                    errors.append(
                        f"{_location(path, key)}: mapping keys must be scalar values"
                    )
                else:
                    if key.tag == MERGE_TAG or key.value == "<<":
                        errors.append(
                            f"{_location(path, key)}: YAML merge keys are forbidden"
                        )
                    previous = seen.get(key.value)
                    if previous is not None:
                        errors.append(
                            f"{_location(path, key)}: duplicate YAML key "
                            f"{key.value!r}; first declared at line "
                            f"{previous.start_mark.line + 1}"
                        )
                    else:
                        seen[key.value] = key
                pending.extend((key, value))
        elif isinstance(node, SequenceNode):
            pending.extend(node.value)
    return errors


def _load_yaml(path: Path, source: str) -> tuple[object | None, list[str]]:
    errors: list[str] = []
    try:
        tokens = tuple(yaml.scan(source, Loader=yaml.SafeLoader))
        documents = tuple(yaml.compose_all(source, Loader=yaml.SafeLoader))
    except yaml.YAMLError as error:
        return None, [_yaml_error(path, error)]

    for token in tokens:
        if isinstance(token, (AnchorToken, AliasToken)):
            errors.append(
                f"{path}:{token.start_mark.line + 1}:"
                f"{token.start_mark.column + 1}: YAML anchors and aliases are forbidden"
            )
    if len(documents) != 1 or documents[0] is None:
        return None, errors + [f"{path}: file must contain exactly one YAML document"]
    errors.extend(_structure_errors(path, documents[0]))
    if errors:
        return None, errors
    try:
        return yaml.safe_load(source), []
    except yaml.YAMLError as error:
        return None, [_yaml_error(path, error)]


def _basename(value: str) -> str:
    return value.rsplit("/", 1)[-1]


def _skip_options(
    tokens: Sequence[str],
    index: int,
    options_with_values: frozenset[str] = frozenset(),
) -> int:
    while index < len(tokens):
        token = tokens[index]
        if token == "--":
            return index + 1
        if not token.startswith("-") or token == "-":
            return index
        index += 1
        if token in options_with_values and index < len(tokens):
            index += 1
    return index


def _skip_redirection(tokens: Sequence[str], index: int) -> int | None:
    operator_index = index
    if (
        REDIRECTION_FD.fullmatch(tokens[index])
        and index + 1 < len(tokens)
        and tokens[index + 1] in REDIRECTION_OPERATORS
    ):
        operator_index += 1
    elif tokens[index] not in REDIRECTION_OPERATORS:
        return None

    target_index = operator_index + 1
    if target_index >= len(tokens):
        return len(tokens)
    return target_index + 1


def _skip_xargs_options(tokens: Sequence[str], index: int) -> int:
    while index < len(tokens):
        token = tokens[index]
        if token == "--":
            return index + 1
        if not token.startswith("-") or token == "-":
            return index

        index += 1
        if token.startswith("--"):
            option, separator, _ = token.partition("=")
            if (
                not separator
                and option in XARGS_LONG_OPTIONS_WITH_VALUES
                and index < len(tokens)
            ):
                index += 1
            continue

        cluster = token[1:]
        for position, option in enumerate(cluster):
            if option in XARGS_SHORT_OPTIONS_WITH_VALUES:
                if position == len(cluster) - 1 and index < len(tokens):
                    index += 1
                break
            if option in XARGS_SHORT_OPTIONS_WITH_OPTIONAL_VALUES:
                break
    return index


def _command_from_segment(tokens: Sequence[str]) -> tuple[str, ...] | None:
    index = 0
    for _ in range(16):
        while index < len(tokens):
            if (
                tokens[index] in RESERVED_PREFIXES
                or ASSIGNMENT.fullmatch(tokens[index])
            ):
                index += 1
                continue
            redirection_end = _skip_redirection(tokens, index)
            if redirection_end is not None:
                index = redirection_end
                continue
            break
        if index >= len(tokens):
            return None
        executable = _basename(tokens[index])
        if executable == "env":
            index = _skip_options(
                tokens,
                index + 1,
                frozenset({"-C", "-S", "--chdir", "--split-string", "-u", "--unset"}),
            )
            while index < len(tokens) and ASSIGNMENT.fullmatch(tokens[index]):
                index += 1
            continue
        if executable == "sudo":
            index = _skip_options(
                tokens,
                index + 1,
                frozenset(
                    {
                        "-C",
                        "-D",
                        "-g",
                        "-h",
                        "-p",
                        "-R",
                        "-T",
                        "-u",
                        "--chdir",
                        "--group",
                        "--host",
                        "--prompt",
                        "--role",
                        "--type",
                        "--user",
                    }
                ),
            )
            continue
        if executable == "nice":
            index = _skip_options(
                tokens,
                index + 1,
                frozenset({"-n", "--adjustment"}),
            )
            continue
        if executable == "bundle" and index + 1 < len(tokens):
            if tokens[index + 1] == "exec":
                index = _skip_options(tokens, index + 2)
                continue
        if executable == "xargs":
            index = _skip_xargs_options(tokens, index + 1)
            continue
        if executable in SIMPLE_WRAPPERS:
            index = _skip_options(tokens, index + 1)
            continue
        return tuple(tokens[index:])
    return None


def _tokenize_script(source: str) -> tuple[list[str], str | None]:
    normalized = source.replace("\\\r\n", " ").replace("\\\n", " ")
    try:
        lexer = shlex.shlex(
            normalized,
            posix=True,
            punctuation_chars=";&|()<>\n",
        )
        lexer.whitespace = " \t\r"
        lexer.whitespace_split = True
        lexer.commenters = "#"
        return list(lexer), None
    except ValueError as error:
        return [], str(error)


def _here_document_declarations(
    line: str,
) -> tuple[list[tuple[str, bool, bool]], list[str]]:
    declarations: list[tuple[str, bool, bool]] = []
    errors: list[str] = []
    index = 0
    quote: str | None = None
    while index < len(line):
        character = line[index]
        if character in "\r\n":
            break
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
            index == 0 or line[index - 1] in " \t\r\n;&|()<>"
        ):
            break
        if line.startswith("<<<", index):
            index += 3
            continue
        if not line.startswith("<<", index):
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
        quoted = False
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
                    quoted = True
                    delimiter.append(line[index + 1])
                    index += 2
                elif character == '"':
                    delimiter_quote = None
                    index += 1
                else:
                    delimiter.append(character)
                    index += 1
                continue
            if character in " \t\r\n;&|()<>":
                break
            consumed = True
            if character in {"'", '"'}:
                quoted = True
                delimiter_quote = character
                index += 1
            elif character == "\\":
                quoted = True
                if index + 1 >= len(line) or line[index + 1] in "\r\n":
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
            declarations.append(("".join(delimiter), strip_tabs, quoted))
    return declarations, errors


def _mask_here_document_line(line: str) -> str:
    content = line.rstrip("\r\n")
    return " " * len(content) + line[len(content) :]


def _strip_here_document_bodies(
    source: str,
) -> tuple[str, list[str], list[str]]:
    lines = source.splitlines(keepends=True)
    masked: list[str] = []
    expanding_bodies: list[str] = []
    errors: list[str] = []
    line_index = 0
    while line_index < len(lines):
        header = lines[line_index]
        declarations, declaration_errors = _here_document_declarations(header)
        errors.extend(declaration_errors)
        masked.append(header)
        line_index += 1

        for delimiter, strip_tabs, quoted in declarations:
            body: list[str] = []
            found = False
            while line_index < len(lines):
                line = lines[line_index]
                candidate = line.rstrip("\r\n")
                if strip_tabs:
                    candidate = candidate.lstrip("\t")
                masked.append(_mask_here_document_line(line))
                line_index += 1
                if candidate == delimiter:
                    found = True
                    break
                body.append(line)
            if not found:
                errors.append(
                    f"unterminated here-document delimiter {delimiter!r}"
                )
                return "".join(masked), expanding_bodies, errors
            if not quoted:
                expanding_bodies.append("".join(body))
    return "".join(masked), expanding_bodies, errors


def _backtick_end(source: str, start: int) -> int | None:
    index = start
    while index < len(source):
        if source[index] == "\\":
            index += 2
        elif source[index] == "`":
            return index
        else:
            index += 1
    return None


def _dollar_paren_end(source: str, start: int) -> int | None:
    index = start
    quote: str | None = None
    paren_depth = 0
    while index < len(source):
        character = source[index]
        if quote == "'":
            if character == "'":
                quote = None
            index += 1
            continue
        if character == "\\":
            index += 2
            continue
        if quote == '"':
            if character == '"':
                quote = None
                index += 1
            elif source.startswith("$(", index) and not source.startswith(
                "$((", index
            ):
                nested_end = _dollar_paren_end(source, index + 2)
                if nested_end is None:
                    return None
                index = nested_end + 1
            elif character == "`":
                nested_end = _backtick_end(source, index + 1)
                if nested_end is None:
                    return None
                index = nested_end + 1
            else:
                index += 1
            continue
        if character in {"'", '"'}:
            quote = character
            index += 1
        elif character == "`":
            nested_end = _backtick_end(source, index + 1)
            if nested_end is None:
                return None
            index = nested_end + 1
        elif source.startswith("$(", index) and not source.startswith("$((", index):
            nested_end = _dollar_paren_end(source, index + 2)
            if nested_end is None:
                return None
            index = nested_end + 1
        elif character == "(":
            paren_depth += 1
            index += 1
        elif character == ")":
            if paren_depth == 0:
                return index
            paren_depth -= 1
            index += 1
        else:
            index += 1
    return None


def _expanding_here_document_substitutions(
    source: str,
) -> tuple[list[str], list[str]]:
    # Bash removes these pairs before expanding an unquoted here-document.
    # Preserve adjacency: `$\` + newline + `(` becomes an executable `$(`.
    source = source.replace("\\\r\n", "").replace("\\\n", "")
    substitutions: list[str] = []
    errors: list[str] = []
    index = 0
    while index < len(source):
        if source[index] == "\\":
            index += 2
            continue
        if source.startswith("$(", index) and not source.startswith("$((", index):
            end = _dollar_paren_end(source, index + 2)
            if end is None:
                errors.append(
                    "unterminated shell command substitution in here-document"
                )
                break
            substitutions.append(source[index + 2 : end])
            index = end + 1
            continue
        if source[index] == "`":
            end = _backtick_end(source, index + 1)
            if end is None:
                errors.append(
                    "unterminated legacy command substitution in here-document"
                )
                break
            substitutions.append(source[index + 1 : end])
            index = end + 1
            continue
        index += 1
    return substitutions, errors


def _extract_executable_substitutions(
    source: str,
) -> tuple[list[str], str, list[str]]:
    substitutions: list[str] = []
    masked: list[str] = []
    errors: list[str] = []
    index = 0
    quote: str | None = None
    while index < len(source):
        character = source[index]
        if quote == "'":
            masked.append(character)
            if character == "'":
                quote = None
            index += 1
            continue
        if character == "\\":
            masked.append(source[index : index + 2])
            index += 2
            continue
        if quote == '"' and character == '"':
            quote = None
            masked.append(character)
            index += 1
            continue
        if quote is None and character in {"'", '"'}:
            quote = character
            masked.append(character)
            index += 1
            continue
        if (
            quote is None
            and character == "#"
            and (index == 0 or source[index - 1] in " \t\r\n;&|()")
        ):
            line_end = source.find("\n", index)
            if line_end == -1:
                masked.append(source[index:])
                break
            masked.append(source[index : line_end + 1])
            index = line_end + 1
            continue
        if source.startswith("$(", index) and not source.startswith("$((", index):
            end = _dollar_paren_end(source, index + 2)
            if end is None:
                errors.append("unterminated shell command substitution")
                masked.append(source[index:])
                break
            substitutions.append(source[index + 2 : end])
            masked.append(COMMAND_SUBSTITUTION_PLACEHOLDER)
            index = end + 1
            continue
        if quote is None and source.startswith(("<(", ">("), index):
            end = _dollar_paren_end(source, index + 2)
            if end is None:
                errors.append("unterminated shell process substitution")
                masked.append(source[index:])
                break
            substitutions.append(source[index + 2 : end])
            masked.append(COMMAND_SUBSTITUTION_PLACEHOLDER)
            index = end + 1
            continue
        if character == "`":
            end = _backtick_end(source, index + 1)
            if end is None:
                errors.append("unterminated legacy shell command substitution")
                masked.append(source[index:])
                break
            substitutions.append(source[index + 1 : end])
            masked.append(COMMAND_SUBSTITUTION_PLACEHOLDER)
            index = end + 1
            continue
        masked.append(character)
        index += 1
    return substitutions, "".join(masked), errors


def _nested_shell_sources(source: str) -> tuple[str, ...]:
    # shlex preserves some expansion escapes that the invoking shell consumes
    # before passing a command string to `sh -c` or `eval`. Inspect both forms.
    deescaped = re.sub(r"\\+(?=(?:\$\(|`))", "", source)
    if deescaped == source:
        return (source,)
    return source, deescaped


def _shell_commands(
    source: str,
    *,
    depth: int = 0,
) -> tuple[list[tuple[str, ...]], list[str]]:
    if depth > 4:
        return [], ["nested shell command depth exceeds the reviewed limit"]
    masked_source, expanding_bodies, errors = _strip_here_document_bodies(source)
    substitutions, masked_source, substitution_errors = (
        _extract_executable_substitutions(masked_source)
    )
    errors.extend(substitution_errors)
    for body in expanding_bodies:
        body_substitutions, body_errors = (
            _expanding_here_document_substitutions(body)
        )
        substitutions.extend(body_substitutions)
        errors.extend(body_errors)
    tokens, token_error = _tokenize_script(masked_source)
    if token_error is not None:
        return [], errors + [f"unable to parse run script: {token_error}"]

    segments: list[list[str]] = [[]]
    for token in tokens:
        if token and set(token) <= CONTROL_CHARACTERS:
            if segments[-1]:
                segments.append([])
        else:
            segments[-1].append(token)

    commands: list[tuple[str, ...]] = []
    for substitution in substitutions:
        nested, nested_errors = _shell_commands(substitution, depth=depth + 1)
        commands.extend(nested)
        errors.extend(nested_errors)
    for segment in segments:
        command = _command_from_segment(segment)
        if command is None:
            continue
        executable = _basename(command[0])
        command_index = None
        if executable in SHELLS:
            for index, argument in enumerate(command[1:], start=1):
                if argument == "-c" or (
                    argument.startswith("-")
                    and not argument.startswith("--")
                    and "c" in argument[1:]
                ):
                    command_index = index + 1
                    break
        if command_index is not None:
            if command_index >= len(command):
                errors.append(f"{executable} -c must provide a command string")
                continue
            for nested_source in _nested_shell_sources(command[command_index]):
                nested, nested_errors = _shell_commands(
                    nested_source,
                    depth=depth + 1,
                )
                commands.extend(nested)
                errors.extend(nested_errors)
        elif executable == "eval" and len(command) > 1:
            for nested_source in _nested_shell_sources(" ".join(command[1:])):
                nested, nested_errors = _shell_commands(
                    nested_source,
                    depth=depth + 1,
                )
                commands.extend(nested)
                errors.extend(nested_errors)
        else:
            commands.append(command)
    return commands, errors


def _is_pod_dependency_command(command: Sequence[str]) -> bool:
    return (
        len(command) >= 2
        and _basename(command[0]) == "pod"
        and command[1] in {"install", "update"}
    )


def _pod_names(pods: object, path: Path) -> tuple[set[str], list[str]]:
    if not isinstance(pods, list) or not pods:
        return set(), [f"{path}: PODS must be a non-empty sequence"]
    names: set[str] = set()
    errors: list[str] = []
    for index, item in enumerate(pods):
        declaration: object
        if isinstance(item, str):
            declaration = item
        elif isinstance(item, Mapping) and len(item) == 1:
            declaration = next(iter(item))
            dependencies = item[declaration]
            if not isinstance(dependencies, list):
                errors.append(
                    f"{path}: PODS entry {index} dependencies must be a sequence"
                )
        else:
            errors.append(f"{path}: PODS entry {index} has an invalid structure")
            continue
        if not isinstance(declaration, str):
            errors.append(f"{path}: PODS entry {index} name must be a string")
            continue
        match = POD_DECLARATION.fullmatch(declaration)
        if match is None:
            errors.append(
                f"{path}: PODS entry {declaration!r} must contain one exact resolved version"
            )
            continue
        version = match.group("version")
        if any(marker in version for marker in (">", "<", "~", "*", "$", "{")):
            errors.append(
                f"{path}: PODS entry {declaration!r} is not an exact resolved version"
            )
        names.add(match.group("name").partition("/")[0])
    return names, errors


def validate_lockfile(
    lockfile: Path,
    podfile: Path,
    *,
    approved_sha256: str = APPROVED_LOCK_SHA256,
) -> list[str]:
    if yaml.__version__ != EXPECTED_PYYAML_VERSION:
        return [
            f"iOS pod lock policy requires PyYAML {EXPECTED_PYYAML_VERSION}, "
            f"found {yaml.__version__}"
        ]
    try:
        lock_bytes = lockfile.read_bytes()
        source = lock_bytes.decode("utf-8")
        podfile_bytes = podfile.read_bytes()
    except (OSError, UnicodeError) as error:
        return [f"{lockfile}: unable to read CocoaPods inputs: {error}"]

    errors: list[str] = []
    actual_sha256 = hashlib.sha256(lock_bytes).hexdigest()
    if actual_sha256 != approved_sha256:
        errors.append(
            f"{lockfile}: reviewed SHA-256 must equal {approved_sha256}, "
            f"found {actual_sha256}"
        )

    document, yaml_errors = _load_yaml(lockfile, source)
    errors.extend(yaml_errors)
    if not isinstance(document, Mapping):
        if not yaml_errors:
            errors.append(f"{lockfile}: lockfile root must be a mapping")
        return errors

    missing = sorted(REQUIRED_LOCK_KEYS - set(document))
    unexpected = sorted(set(document) - REQUIRED_LOCK_KEYS)
    if missing:
        errors.append(f"{lockfile}: missing required sections: {missing}")
    if unexpected:
        errors.append(f"{lockfile}: unexpected top-level sections: {unexpected}")

    if document.get("COCOAPODS") != APPROVED_COCOAPODS_VERSION:
        errors.append(
            f"{lockfile}: COCOAPODS must equal reviewed version "
            f"{APPROVED_COCOAPODS_VERSION}"
        )
    expected_podfile_checksum = hashlib.sha1(podfile_bytes).hexdigest()
    if document.get("PODFILE CHECKSUM") != expected_podfile_checksum:
        errors.append(
            f"{lockfile}: PODFILE CHECKSUM does not match mobile/ios/Podfile"
        )

    pod_names, pod_errors = _pod_names(document.get("PODS"), lockfile)
    errors.extend(pod_errors)

    checksums = document.get("SPEC CHECKSUMS")
    if not isinstance(checksums, Mapping) or not checksums:
        errors.append(f"{lockfile}: SPEC CHECKSUMS must be a non-empty mapping")
        checksum_names: set[str] = set()
    else:
        checksum_names = set()
        for name, checksum in checksums.items():
            if not isinstance(name, str) or not isinstance(checksum, str):
                errors.append(f"{lockfile}: SPEC CHECKSUMS entries must be strings")
                continue
            checksum_names.add(name)
            if re.fullmatch(r"[0-9a-f]{40}", checksum) is None:
                errors.append(
                    f"{lockfile}: spec checksum for {name!r} must be lowercase SHA-1"
                )
        if pod_names != checksum_names:
            errors.append(
                f"{lockfile}: PODS and SPEC CHECKSUMS names differ: "
                f"pods={sorted(pod_names)}, checksums={sorted(checksum_names)}"
            )

    dependencies = document.get("DEPENDENCIES")
    if not isinstance(dependencies, list) or not dependencies or not all(
        isinstance(item, str) for item in dependencies
    ):
        errors.append(f"{lockfile}: DEPENDENCIES must be a non-empty string sequence")

    external = document.get("EXTERNAL SOURCES")
    if not isinstance(external, Mapping) or not external:
        errors.append(f"{lockfile}: EXTERNAL SOURCES must be a non-empty mapping")
    else:
        for name, settings in external.items():
            if (
                not isinstance(name, str)
                or not isinstance(settings, Mapping)
                or set(settings) != {":path"}
                or not isinstance(settings.get(":path"), str)
                or PLUGIN_PATH.fullmatch(settings[":path"]) is None
            ):
                errors.append(
                    f"{lockfile}: external source {name!r} must use one reviewed "
                    "relative Flutter plugin path"
                )

    repos = document.get("SPEC REPOS")
    if not isinstance(repos, Mapping) or set(repos) != {"trunk"}:
        errors.append(f"{lockfile}: SPEC REPOS must contain only CocoaPods trunk")
    elif not isinstance(repos.get("trunk"), list) or not repos["trunk"]:
        errors.append(f"{lockfile}: CocoaPods trunk pod list must be non-empty")

    return errors


def _script_lines(value: object) -> tuple[str, ...]:
    if not isinstance(value, str):
        return ()
    return tuple(line.strip() for line in value.splitlines() if line.strip())


def _job_errors(path: Path, job_name: str, job: object) -> list[str]:
    prefix = f"{path}: jobs.{job_name}"
    if not isinstance(job, Mapping):
        return [f"{prefix} must be a mapping"]
    errors: list[str] = []
    if job.get("runs-on") != "macos-26":
        errors.append(f"{prefix} must run on reviewed macos-26")
    defaults = job.get("defaults")
    working_directory = None
    if isinstance(defaults, Mapping) and isinstance(defaults.get("run"), Mapping):
        working_directory = defaults["run"].get("working-directory")
    if working_directory != "mobile":
        errors.append(f"{prefix} must use mobile as the run working-directory")
    if "if" in job or job.get("continue-on-error") is not None:
        errors.append(f"{prefix} must not be conditional or continue on error")

    steps = job.get("steps")
    if not isinstance(steps, list):
        return errors + [f"{prefix}.steps must be a sequence"]

    install_indexes: list[int] = []
    verify_indexes: list[int] = []
    dependency_indexes: list[int] = []
    build_indexes: list[int] = []
    for index, step in enumerate(steps):
        if not isinstance(step, Mapping):
            errors.append(f"{prefix}.steps[{index}] must be a mapping")
            continue
        lines = _script_lines(step.get("run"))
        if lines == ("flutter pub get --enforce-lockfile",):
            dependency_indexes.append(index)
        if any(line.startswith("flutter build ios ") for line in lines):
            build_indexes.append(index)
        if step.get("name") == INSTALL_STEP_NAME:
            install_indexes.append(index)
            if step.get("shell") != "bash" or lines != INSTALL_SCRIPT:
                errors.append(
                    f"{prefix}.{INSTALL_STEP_NAME!r} must use the canonical frozen script"
                )
            if "if" in step or step.get("continue-on-error") is not None:
                errors.append(
                    f"{prefix}.{INSTALL_STEP_NAME!r} must fail closed unconditionally"
                )
        if step.get("name") == VERIFY_STEP_NAME:
            verify_indexes.append(index)
            if step.get("shell") != "bash" or lines != VERIFY_SCRIPT:
                errors.append(
                    f"{prefix}.{VERIFY_STEP_NAME!r} must use the canonical diff check"
                )
            if "if" in step or step.get("continue-on-error") is not None:
                errors.append(
                    f"{prefix}.{VERIFY_STEP_NAME!r} must fail closed unconditionally"
                )

    if len(dependency_indexes) != 1:
        errors.append(
            f"{prefix} must run flutter pub get --enforce-lockfile exactly once"
        )
    if len(install_indexes) != 1:
        errors.append(f"{prefix} must install locked iOS pods exactly once")
    if len(build_indexes) != 1:
        errors.append(f"{prefix} must build iOS exactly once")
    if len(verify_indexes) != 1:
        errors.append(f"{prefix} must verify the iOS pod lock exactly once")
    if all(
        len(indexes) == 1
        for indexes in (
            dependency_indexes,
            install_indexes,
            build_indexes,
            verify_indexes,
        )
    ) and not (
        dependency_indexes[0]
        < install_indexes[0]
        < build_indexes[0]
        < verify_indexes[0]
    ):
        errors.append(
            f"{prefix} must resolve Dart, freeze pods, build iOS, then verify the lock"
        )
    return errors


def validate_workflows(
    workflow_directory: Path,
    *,
    expected_jobs: Mapping[str, str] = EXPECTED_IOS_JOBS,
) -> list[str]:
    if yaml.__version__ != EXPECTED_PYYAML_VERSION:
        return [
            f"iOS pod lock policy requires PyYAML {EXPECTED_PYYAML_VERSION}, "
            f"found {yaml.__version__}"
        ]
    files = tuple(
        sorted(
            (*workflow_directory.glob("*.yml"), *workflow_directory.glob("*.yaml")),
            key=lambda path: path.name,
        )
    )
    if not files:
        return [f"{workflow_directory}: no workflow YAML files found"]

    errors: list[str] = []
    seen_jobs: set[tuple[str, str]] = set()
    pod_command_locations: list[tuple[str, str, int]] = []
    for path in files:
        try:
            source = path.read_text(encoding="utf-8")
        except OSError as error:
            errors.append(f"{path}: unable to read workflow: {error}")
            continue
        document, yaml_errors = _load_yaml(path, source)
        errors.extend(yaml_errors)
        if not isinstance(document, Mapping):
            if not yaml_errors:
                errors.append(f"{path}: workflow root must be a mapping")
            continue
        jobs = document.get("jobs")
        if not isinstance(jobs, Mapping):
            errors.append(f"{path}: jobs must be a mapping")
            continue
        for job_name, job in jobs.items():
            if not isinstance(job_name, str) or not isinstance(job, Mapping):
                continue
            steps = job.get("steps")
            if isinstance(steps, list):
                for index, step in enumerate(steps):
                    if isinstance(step, Mapping) and isinstance(step.get("run"), str):
                        commands, shell_errors = _shell_commands(step["run"])
                        errors.extend(
                            f"{path.name}.jobs.{job_name}.steps[{index}] {error}"
                            for error in shell_errors
                        )
                        if any(
                            _is_pod_dependency_command(command)
                            for command in commands
                        ):
                            pod_command_locations.append((path.name, job_name, index))
            if expected_jobs.get(path.name) == job_name:
                seen_jobs.add((path.name, job_name))
                errors.extend(_job_errors(path, job_name, job))

    expected = set(expected_jobs.items())
    missing = sorted(expected - seen_jobs)
    if missing:
        errors.append(f"{workflow_directory}: missing protected iOS jobs: {missing}")
    expected_commands = {
        (filename, job_name) for filename, job_name in expected_jobs.items()
    }
    actual_command_jobs = {(filename, job) for filename, job, _ in pod_command_locations}
    if actual_command_jobs != expected_commands or len(pod_command_locations) != len(expected):
        errors.append(
            f"{workflow_directory}: pod commands must occur exactly once in each "
            f"protected iOS job; found {pod_command_locations}"
        )
    return errors


def validate_tracking(root: Path) -> list[str]:
    errors: list[str] = []
    try:
        tracked = subprocess.run(
            [
                "git",
                "-C",
                str(root),
                "ls-files",
                "--error-unmatch",
                "--",
                "mobile/ios/Podfile.lock",
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        if tracked.returncode != 0:
            errors.append("mobile/ios/Podfile.lock must be tracked by Git")
        ignored = subprocess.run(
            [
                "git",
                "-C",
                str(root),
                "check-ignore",
                "--no-index",
                "--quiet",
                "--",
                "mobile/ios/Podfile.lock",
            ],
            check=False,
        )
        if ignored.returncode == 0:
            errors.append("mobile/ios/Podfile.lock must not be ignored")
        elif ignored.returncode not in (1,):
            errors.append("unable to determine whether mobile/ios/Podfile.lock is ignored")
        generated = subprocess.run(
            [
                "git",
                "-C",
                str(root),
                "ls-files",
                "--",
                "mobile/ios/Pods/**",
                "mobile/ios/.symlinks/**",
                "mobile/ios/Pods/Manifest.lock",
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        if generated.returncode != 0:
            errors.append("unable to inspect tracked generated CocoaPods paths")
        elif generated.stdout.strip():
            errors.append(
                "generated CocoaPods paths must not be tracked: "
                + ", ".join(generated.stdout.splitlines())
            )
    except OSError as error:
        errors.append(f"unable to inspect Git tracking state: {error}")
    return errors


def validate_repository(root: Path = ROOT) -> list[str]:
    return [
        *validate_lockfile(
            root / "mobile/ios/Podfile.lock",
            root / "mobile/ios/Podfile",
        ),
        *validate_workflows(root / ".github/workflows"),
        *validate_tracking(root),
    ]


def main() -> int:
    errors = validate_repository()
    if errors:
        for error in errors:
            print(f"iOS CocoaPods lock policy error: {error}")
        return 1
    print(
        "iOS CocoaPods lock policy passed for the reviewed lock and "
        f"{len(EXPECTED_IOS_JOBS)} protected jobs."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
