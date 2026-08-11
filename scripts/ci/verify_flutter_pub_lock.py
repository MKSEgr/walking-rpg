#!/usr/bin/env python3
"""Require a reviewed Flutter pub lock in every protected mobile build."""

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
DEFAULT_LOCKFILE = ROOT / "mobile" / "pubspec.lock"
DEFAULT_WORKFLOW_DIRECTORY = ROOT / ".github" / "workflows"
EXPECTED_PYYAML_VERSION = "6.0.3"
APPROVED_LOCK_SHA256 = (
    "23fe967b74d9fa01df73cff26f40fd055e1802c9e5382f44cd43f19b02573df2"
)
EXPECTED_FLUTTER_JOBS = {
    "ci.yml": frozenset({"mobile", "android-host", "ios-host"}),
    "release-quality.yml": frozenset({"android-release", "ios-release"}),
}
INSTALL_STEP_NAME = "Install dependencies"
INSTALL_SCRIPT = ("flutter pub get --enforce-lockfile",)
REQUIRED_LOCK_KEYS = {"packages", "sdks"}
REQUIRED_PACKAGE_KEYS = {"dependency", "description", "source", "version"}
ALLOWED_DEPENDENCY_KINDS = {"direct main", "direct dev", "transitive"}
PACKAGE_NAME = re.compile(r"^[a-z][a-z0-9_]*$")
EXACT_VERSION = re.compile(
    r"^(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)"
    r"(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?"
    r"(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$"
)
LOWERCASE_SHA256 = re.compile(r"^[0-9a-f]{64}$")
MERGE_TAG = "tag:yaml.org,2002:merge"
CONTROL_CHARACTERS = frozenset(";&|()\n")
ASSIGNMENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=.*$", re.DOTALL)
RESOLVING_SUBCOMMANDS = frozenset({"add", "downgrade", "get", "remove", "upgrade"})
SHELLS = frozenset({"bash", "dash", "sh", "zsh"})
SIMPLE_WRAPPERS = frozenset(
    {"builtin", "command", "exec", "fvm", "nohup", "time", "xargs"}
)
RESERVED_PREFIXES = frozenset(
    {"!", "do", "elif", "else", "if", "then", "until", "while", "{", "}"}
)
COMMAND_SUBSTITUTION_PLACEHOLDER = "__reviewed_command_substitution__"


def _location(path: Path, node: Node) -> str:
    return f"{path}:{node.start_mark.line + 1}:{node.start_mark.column + 1}"


def _yaml_error(path: Path, error: yaml.YAMLError, kind: str) -> str:
    mark = getattr(error, "problem_mark", None)
    if mark is None:
        return f"{path}: invalid {kind} YAML: {error}"
    problem = getattr(error, "problem", None) or f"invalid {kind} YAML"
    return (
        f"{path}:{mark.line + 1}:{mark.column + 1}: "
        f"invalid {kind} YAML: {problem}"
    )


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


def _load_yaml(path: Path, source: str, kind: str) -> tuple[object | None, list[str]]:
    errors: list[str] = []
    try:
        tokens = tuple(yaml.scan(source, Loader=yaml.SafeLoader))
        documents = tuple(yaml.compose_all(source, Loader=yaml.SafeLoader))
    except yaml.YAMLError as error:
        return None, [_yaml_error(path, error, kind)]

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
        return None, [_yaml_error(path, error, kind)]


def _package_errors(name: object, package: object, path: Path) -> list[str]:
    prefix = f"{path}: package {name!r}"
    if not isinstance(name, str) or PACKAGE_NAME.fullmatch(name) is None:
        return [f"{prefix} must use a canonical pub package name"]
    if not isinstance(package, Mapping):
        return [f"{prefix} must be a mapping"]

    errors: list[str] = []
    missing = sorted(REQUIRED_PACKAGE_KEYS - set(package))
    unexpected = sorted(set(package) - REQUIRED_PACKAGE_KEYS, key=str)
    if missing:
        errors.append(f"{prefix} is missing required keys: {missing}")
    if unexpected:
        errors.append(f"{prefix} has unexpected keys: {unexpected}")

    dependency = package.get("dependency")
    if dependency not in ALLOWED_DEPENDENCY_KINDS:
        errors.append(f"{prefix} has invalid dependency kind {dependency!r}")

    version = package.get("version")
    if not isinstance(version, str) or EXACT_VERSION.fullmatch(version) is None:
        errors.append(f"{prefix} must contain one exact semantic version")

    source = package.get("source")
    description = package.get("description")
    if source == "hosted":
        if not isinstance(description, Mapping):
            errors.append(f"{prefix} hosted description must be a mapping")
        else:
            if set(description) != {"name", "sha256", "url"}:
                errors.append(
                    f"{prefix} hosted description must contain only name, sha256 and url"
                )
            if description.get("name") != name:
                errors.append(f"{prefix} hosted description name must match the package")
            digest = description.get("sha256")
            if not isinstance(digest, str) or LOWERCASE_SHA256.fullmatch(digest) is None:
                errors.append(f"{prefix} hosted content hash must be lowercase SHA-256")
            if description.get("url") != "https://pub.dev":
                errors.append(f"{prefix} hosted source must equal https://pub.dev")
    elif source == "sdk":
        if description != "flutter" or version != "0.0.0":
            errors.append(
                f"{prefix} SDK dependency must use Flutter with version 0.0.0"
            )
    else:
        errors.append(f"{prefix} source must be reviewed hosted or Flutter SDK content")
    return errors


def validate_lockfile(
    lockfile: Path,
    *,
    approved_sha256: str = APPROVED_LOCK_SHA256,
) -> list[str]:
    if yaml.__version__ != EXPECTED_PYYAML_VERSION:
        return [
            f"Flutter pub lock policy requires PyYAML {EXPECTED_PYYAML_VERSION}, "
            f"found {yaml.__version__}"
        ]
    try:
        lock_bytes = lockfile.read_bytes()
        source = lock_bytes.decode("utf-8")
    except (OSError, UnicodeError) as error:
        return [f"{lockfile}: unable to read Flutter pub lock: {error}"]

    errors: list[str] = []
    actual_sha256 = hashlib.sha256(lock_bytes).hexdigest()
    if actual_sha256 != approved_sha256:
        errors.append(
            f"{lockfile}: reviewed SHA-256 must equal {approved_sha256}, "
            f"found {actual_sha256}"
        )

    document, yaml_errors = _load_yaml(lockfile, source, "lockfile")
    errors.extend(yaml_errors)
    if not isinstance(document, Mapping):
        if not yaml_errors:
            errors.append(f"{lockfile}: lockfile root must be a mapping")
        return errors

    missing = sorted(REQUIRED_LOCK_KEYS - set(document))
    unexpected = sorted(set(document) - REQUIRED_LOCK_KEYS, key=str)
    if missing:
        errors.append(f"{lockfile}: missing required sections: {missing}")
    if unexpected:
        errors.append(f"{lockfile}: unexpected top-level sections: {unexpected}")

    packages = document.get("packages")
    hosted_count = 0
    sdk_count = 0
    if not isinstance(packages, Mapping) or not packages:
        errors.append(f"{lockfile}: packages must be a non-empty mapping")
    else:
        for name, package in packages.items():
            errors.extend(_package_errors(name, package, lockfile))
            if isinstance(package, Mapping):
                hosted_count += package.get("source") == "hosted"
                sdk_count += package.get("source") == "sdk"
        if hosted_count == 0 or sdk_count == 0:
            errors.append(
                f"{lockfile}: reviewed graph must contain hosted and Flutter SDK packages"
            )

    sdks = document.get("sdks")
    if not isinstance(sdks, Mapping) or set(sdks) != {"dart", "flutter"}:
        errors.append(f"{lockfile}: sdks must contain only dart and flutter constraints")
    elif not all(isinstance(value, str) and value.strip() for value in sdks.values()):
        errors.append(f"{lockfile}: SDK constraints must be non-empty strings")
    return errors


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


def _command_from_segment(tokens: Sequence[str]) -> tuple[str, ...] | None:
    index = 0
    for _ in range(12):
        while index < len(tokens) and tokens[index] in RESERVED_PREFIXES:
            index += 1
        while index < len(tokens) and ASSIGNMENT.fullmatch(tokens[index]):
            index += 1
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
            punctuation_chars=";&|()\n",
        )
        lexer.whitespace = " \t\r"
        lexer.whitespace_split = True
        lexer.commenters = "#"
        return list(lexer), None
    except ValueError as error:
        return [], str(error)


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


def _extract_command_substitutions(
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
    substitutions, masked_source, errors = _extract_command_substitutions(source)
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


def _resolver(command: Sequence[str]) -> tuple[str, str] | None:
    if len(command) < 3:
        return None
    executable = _basename(command[0])
    if executable not in {"dart", "flutter"}:
        return None
    namespace = command[1]
    subcommand = command[2]
    if namespace == "pub" and subcommand in RESOLVING_SUBCOMMANDS:
        return executable, subcommand
    if executable == "flutter" and namespace == "packages" and subcommand in {
        "get",
        "upgrade",
    }:
        return executable, subcommand
    return None


def _script_lines(value: object) -> tuple[str, ...]:
    if not isinstance(value, str):
        return ()
    return tuple(line.strip() for line in value.splitlines() if line.strip())


def _action(step: object, expected: str) -> bool:
    return (
        isinstance(step, Mapping)
        and isinstance(step.get("uses"), str)
        and step["uses"].partition("@")[0] == expected
    )


def _job_errors(path: Path, job_name: str, job: object) -> list[str]:
    prefix = f"{path}: jobs.{job_name}"
    if not isinstance(job, Mapping):
        return [f"{prefix} must be a mapping"]
    errors: list[str] = []
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

    checkout_indexes = [
        index for index, step in enumerate(steps) if _action(step, "actions/checkout")
    ]
    setup_indexes = [
        index
        for index, step in enumerate(steps)
        if _action(step, "subosito/flutter-action")
    ]
    install_indexes: list[int] = []
    consumer_indexes: list[int] = []
    for index, step in enumerate(steps):
        if not isinstance(step, Mapping):
            errors.append(f"{prefix}.steps[{index}] must be a mapping")
            continue
        lines = _script_lines(step.get("run"))
        if step.get("name") == INSTALL_STEP_NAME:
            install_indexes.append(index)
            if set(step) != {"name", "run"} or lines != INSTALL_SCRIPT:
                errors.append(
                    f"{prefix}.{INSTALL_STEP_NAME!r} must use the canonical "
                    "flutter pub get --enforce-lockfile step"
                )
        if isinstance(step.get("run"), str):
            commands, shell_errors = _shell_commands(step["run"])
            errors.extend(
                f"{prefix}.steps[{index}] {error}" for error in shell_errors
            )
            for command in commands:
                if (
                    len(command) >= 2
                    and _basename(command[0]) == "flutter"
                    and command[1] in {"analyze", "build", "test"}
                ):
                    consumer_indexes.append(index)
                    if command.count("--no-pub") != 1 or "--pub" in command:
                        errors.append(
                            f"{prefix}.steps[{index}] Flutter consumers must disable "
                            "implicit dependency resolution with exactly one --no-pub"
                        )

    if len(checkout_indexes) != 1:
        errors.append(f"{prefix} must check out source exactly once")
    if len(setup_indexes) != 1:
        errors.append(f"{prefix} must set up Flutter exactly once")
    if len(install_indexes) != 1:
        errors.append(
            f"{prefix} must install the reviewed Flutter pub lock exactly once"
        )
    if not consumer_indexes:
        errors.append(f"{prefix} must consume Flutter dependencies after installation")
    if (
        len(checkout_indexes) == 1
        and len(setup_indexes) == 1
        and len(install_indexes) == 1
        and consumer_indexes
        and not (
            checkout_indexes[0]
            < setup_indexes[0]
            < install_indexes[0]
            < min(consumer_indexes)
        )
    ):
        errors.append(
            f"{prefix} must check out source, set up Flutter, enforce the lock, "
            "then analyze, test or build without implicit pub resolution"
        )
    return errors


def validate_workflows(
    workflow_directory: Path,
    *,
    expected_jobs: Mapping[str, frozenset[str]] = EXPECTED_FLUTTER_JOBS,
) -> list[str]:
    if yaml.__version__ != EXPECTED_PYYAML_VERSION:
        return [
            f"Flutter pub lock policy requires PyYAML {EXPECTED_PYYAML_VERSION}, "
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
    resolver_locations: list[tuple[str, str, int, str, str]] = []
    for path in files:
        try:
            source = path.read_text(encoding="utf-8")
        except (OSError, UnicodeError) as error:
            errors.append(f"{path}: unable to read workflow: {error}")
            continue
        document, yaml_errors = _load_yaml(path, source, "workflow")
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
                    if not isinstance(step, Mapping) or not isinstance(
                        step.get("run"), str
                    ):
                        continue
                    commands, shell_errors = _shell_commands(step["run"])
                    errors.extend(
                        f"{path}: jobs.{job_name}.steps[{index}] {error}"
                        for error in shell_errors
                    )
                    for command in commands:
                        resolver = _resolver(command)
                        if resolver is not None:
                            resolver_locations.append(
                                (path.name, job_name, index, *resolver)
                            )
            if job_name in expected_jobs.get(path.name, frozenset()):
                seen_jobs.add((path.name, job_name))
                errors.extend(_job_errors(path, job_name, job))

    expected = {
        (filename, job_name)
        for filename, job_names in expected_jobs.items()
        for job_name in job_names
    }
    missing = sorted(expected - seen_jobs)
    if missing:
        errors.append(f"{workflow_directory}: missing protected Flutter jobs: {missing}")
    actual_resolver_jobs = {
        (filename, job_name) for filename, job_name, _, _, _ in resolver_locations
    }
    if actual_resolver_jobs != expected or len(resolver_locations) != len(expected):
        errors.append(
            f"{workflow_directory}: dependency resolvers must occur exactly once in "
            f"each protected Flutter job; found {resolver_locations}"
        )
    return errors


def validate_tracking(root: Path) -> list[str]:
    errors: list[str] = []
    override = root / "mobile/pubspec_overrides.yaml"
    if override.exists():
        errors.append("mobile/pubspec_overrides.yaml must not exist in protected builds")
    try:
        tracked = subprocess.run(
            [
                "git",
                "-C",
                str(root),
                "ls-files",
                "--error-unmatch",
                "--",
                "mobile/pubspec.lock",
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        if tracked.returncode != 0:
            errors.append("mobile/pubspec.lock must be tracked by Git")
        ignored = subprocess.run(
            [
                "git",
                "-C",
                str(root),
                "check-ignore",
                "--no-index",
                "--quiet",
                "--",
                "mobile/pubspec.lock",
            ],
            check=False,
        )
        if ignored.returncode == 0:
            errors.append("mobile/pubspec.lock must not be ignored")
        elif ignored.returncode != 1:
            errors.append("unable to determine whether mobile/pubspec.lock is ignored")
        generated = subprocess.run(
            [
                "git",
                "-C",
                str(root),
                "ls-files",
                "--",
                "mobile/.dart_tool/**",
                "mobile/.packages",
                "mobile/pubspec_overrides.yaml",
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        if generated.returncode != 0:
            errors.append("unable to inspect tracked generated Flutter pub paths")
        elif generated.stdout.strip():
            errors.append(
                "generated or overriding Flutter pub paths must not be tracked: "
                + ", ".join(generated.stdout.splitlines())
            )
    except OSError as error:
        errors.append(f"unable to inspect Git tracking state: {error}")
    return errors


def validate_repository(root: Path = ROOT) -> list[str]:
    return [
        *validate_lockfile(root / "mobile/pubspec.lock"),
        *validate_workflows(root / ".github/workflows"),
        *validate_tracking(root),
    ]


def main() -> int:
    errors = validate_repository()
    if errors:
        for error in errors:
            print(f"Flutter pub lock policy error: {error}")
        return 1
    print(
        "Flutter pub lock policy passed for the reviewed lock and "
        f"{sum(map(len, EXPECTED_FLUTTER_JOBS.values()))} protected jobs."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
