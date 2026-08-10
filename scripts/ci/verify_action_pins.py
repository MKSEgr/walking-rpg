#!/usr/bin/env python3
"""Reject mutable or unauditable remote GitHub Action references."""

from __future__ import annotations

import re
from pathlib import Path

import yaml
from yaml.nodes import MappingNode, Node, ScalarNode, SequenceNode


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
EXPECTED_PYYAML_VERSION = "6.0.3"


def parser_version_error() -> str | None:
    if yaml.__version__ == EXPECTED_PYYAML_VERSION:
        return None
    return (
        "action pin policy requires PyYAML "
        f"{EXPECTED_PYYAML_VERSION}, found {yaml.__version__}"
    )


def workflow_files(workflow_directory: Path) -> tuple[Path, ...]:
    return tuple(
        sorted(
            (*workflow_directory.glob("*.yml"), *workflow_directory.glob("*.yaml")),
            key=lambda path: path.name,
        )
    )


def _yaml_error(path: Path, error: yaml.YAMLError) -> str:
    mark = getattr(error, "problem_mark", None)
    if mark is None:
        return f"{path}: invalid workflow YAML: {error}"
    problem = getattr(error, "problem", None) or "invalid YAML"
    return (
        f"{path}:{mark.line + 1}:{mark.column + 1}: "
        f"invalid workflow YAML: {problem}"
    )


def _uses_nodes(root: Node) -> tuple[tuple[ScalarNode, Node], ...]:
    declarations: list[tuple[ScalarNode, Node]] = []
    pending: list[Node] = [root]
    visited: set[int] = set()

    while pending:
        node = pending.pop()
        identity = id(node)
        if identity in visited:
            continue
        visited.add(identity)

        if isinstance(node, MappingNode):
            for key, value in node.value:
                if isinstance(key, ScalarNode) and key.value == "uses":
                    declarations.append((key, value))
                pending.extend((key, value))
        elif isinstance(node, SequenceNode):
            pending.extend(node.value)

    return tuple(
        sorted(
            declarations,
            key=lambda declaration: (
                declaration[0].start_mark.line,
                declaration[0].start_mark.column,
            ),
        )
    )


def _inline_comment(lines: list[str], value: ScalarNode) -> str:
    if value.start_mark.line != value.end_mark.line:
        return ""
    remainder = lines[value.end_mark.line][value.end_mark.column :]
    marker = remainder.find("#")
    if marker < 0:
        return ""
    return remainder[marker + 1 :].strip()


def _validate_reference(location: str, reference: str, comment: str) -> list[str]:
    errors: list[str] = []
    if reference.startswith("./"):
        return errors
    if reference.startswith("docker://"):
        if not IMMUTABLE_DOCKER_ACTION.fullmatch(reference):
            errors.append(
                f"{location}: Docker action must use an exact sha256 digest"
            )
        if not comment:
            errors.append(
                f"{location}: Docker action digest needs a reviewed image comment"
            )
        return errors

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
        return errors
    if not RELEASE_COMMENT.fullmatch(comment):
        errors.append(
            f"{location}: pinned action needs an exact release comment such as "
            "# v4.4.0"
        )
    return errors


def validate_workflows(workflow_directory: Path) -> list[str]:
    errors: list[str] = []
    version_error = parser_version_error()
    if version_error is not None:
        return [version_error]

    files = workflow_files(workflow_directory)
    if not files:
        return [f"{workflow_directory}: no workflow YAML files found"]

    for path in files:
        source = path.read_text(encoding="utf-8")
        lines = source.splitlines()
        try:
            documents = tuple(yaml.compose_all(source, Loader=yaml.SafeLoader))
        except yaml.YAMLError as error:
            errors.append(_yaml_error(path, error))
            continue
        if len(documents) != 1 or documents[0] is None:
            errors.append(f"{path}: workflow must contain exactly one YAML document")
            continue

        for key, value in _uses_nodes(documents[0]):
            location = f"{path}:{key.start_mark.line + 1}:{key.start_mark.column + 1}"
            if not isinstance(value, ScalarNode) or value.tag != "tag:yaml.org,2002:str":
                errors.append(f"{location}: uses value must be a string")
                continue
            if (
                key.start_mark.line != value.start_mark.line
                or value.start_mark.line != value.end_mark.line
            ):
                errors.append(f"{location}: uses value must be an inline string")
                continue
            errors.extend(
                _validate_reference(
                    location,
                    value.value,
                    _inline_comment(lines, value),
                )
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
