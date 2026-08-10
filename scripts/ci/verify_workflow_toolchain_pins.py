#!/usr/bin/env python3
"""Reject mutable or unreviewed GitHub Actions toolchain versions."""

from __future__ import annotations

from collections import Counter
from collections.abc import Mapping
from pathlib import Path

import yaml
from yaml.nodes import MappingNode, Node, ScalarNode, SequenceNode
from yaml.tokens import AliasToken, AnchorToken


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_WORKFLOW_DIRECTORY = ROOT / ".github" / "workflows"
EXPECTED_PYYAML_VERSION = "6.0.3"
STRING_TAG = "tag:yaml.org,2002:str"
MERGE_TAG = "tag:yaml.org,2002:merge"

TOOLCHAIN_INPUTS = {
    "actions/setup-node": ("node-version", frozenset({"22.23.1"})),
    "actions/setup-python": ("python-version", frozenset({"3.12.13"})),
    "actions/setup-java": (
        "java-version",
        frozenset({"17.0.19+10", "21.0.11+10"}),
    ),
}
EXPECTED_TOOLCHAIN_COUNTS = {
    ("actions/setup-node", "22.23.1"): 1,
    ("actions/setup-python", "3.12.13"): 3,
    ("actions/setup-java", "17.0.19+10"): 2,
    ("actions/setup-java", "21.0.11+10"): 3,
}


def parser_version_error() -> str | None:
    if yaml.__version__ == EXPECTED_PYYAML_VERSION:
        return None
    return (
        "workflow toolchain policy requires PyYAML "
        f"{EXPECTED_PYYAML_VERSION}, found {yaml.__version__}"
    )


def workflow_files(workflow_directory: Path) -> tuple[Path, ...]:
    return tuple(
        sorted(
            (*workflow_directory.glob("*.yml"), *workflow_directory.glob("*.yaml")),
            key=lambda path: path.name,
        )
    )


def _location(path: Path, node: Node) -> str:
    return f"{path}:{node.start_mark.line + 1}:{node.start_mark.column + 1}"


def _yaml_error(path: Path, error: yaml.YAMLError) -> str:
    mark = getattr(error, "problem_mark", None)
    if mark is None:
        return f"{path}: invalid workflow YAML: {error}"
    problem = getattr(error, "problem", None) or "invalid YAML"
    return (
        f"{path}:{mark.line + 1}:{mark.column + 1}: "
        f"invalid workflow YAML: {problem}"
    )


def _mapping_values(mapping: MappingNode, name: str) -> tuple[tuple[ScalarNode, Node], ...]:
    return tuple(
        (key, value)
        for key, value in mapping.value
        if isinstance(key, ScalarNode) and key.value == name
    )


def _structure_errors(path: Path, root: Node) -> list[str]:
    errors: list[str] = []
    pending: list[Node] = [root]
    visited: set[int] = set()

    while pending:
        node = pending.pop()
        identity = id(node)
        if identity in visited:
            continue
        visited.add(identity)

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
                            f"{_location(path, key)}: duplicate YAML key {key.value!r}; "
                            f"first declared at line {previous.start_mark.line + 1}"
                        )
                    else:
                        seen[key.value] = key
                pending.extend((key, value))
        elif isinstance(node, SequenceNode):
            pending.extend(node.value)

    return errors


def _literal_input(
    path: Path,
    step: MappingNode,
    action: str,
    input_name: str,
) -> tuple[str | None, list[str]]:
    errors: list[str] = []
    with_declarations = _mapping_values(step, "with")
    if not with_declarations:
        return None, [
            f"{_location(path, step)}: {action} must declare a with mapping"
        ]
    with_node = with_declarations[0][1]
    if not isinstance(with_node, MappingNode):
        return None, [
            f"{_location(path, with_node)}: {action} with must be a mapping"
        ]

    inputs = _mapping_values(with_node, input_name)
    if not inputs:
        return None, [
            f"{_location(path, with_node)}: {action} must declare {input_name}"
        ]
    key, value = inputs[0]
    location = _location(path, key)
    if not isinstance(value, ScalarNode) or value.tag != STRING_TAG:
        return None, [f"{location}: {action} {input_name} must be a string"]
    if (
        key.start_mark.line != value.start_mark.line
        or value.start_mark.line != value.end_mark.line
    ):
        errors.append(
            f"{location}: {action} {input_name} must be an inline literal string"
        )
    return value.value, errors


def _setup_steps(root: Node) -> tuple[tuple[MappingNode, ScalarNode], ...]:
    declarations: list[tuple[MappingNode, ScalarNode]] = []
    pending: list[Node] = [root]
    visited: set[int] = set()

    while pending:
        node = pending.pop()
        identity = id(node)
        if identity in visited:
            continue
        visited.add(identity)

        if isinstance(node, MappingNode):
            uses = _mapping_values(node, "uses")
            if uses:
                value = uses[0][1]
                if isinstance(value, ScalarNode) and value.tag == STRING_TAG:
                    action = value.value.partition("@")[0]
                    if action in TOOLCHAIN_INPUTS:
                        declarations.append((node, value))
            for key, value in node.value:
                pending.extend((key, value))
        elif isinstance(node, SequenceNode):
            pending.extend(node.value)

    return tuple(
        sorted(
            declarations,
            key=lambda declaration: declaration[1].start_mark.line,
        )
    )


def _toolchain_errors(
    path: Path,
    root: Node,
) -> tuple[list[str], Counter[tuple[str, str]]]:
    errors: list[str] = []
    counts: Counter[tuple[str, str]] = Counter()

    for step, uses in _setup_steps(root):
        action = uses.value.partition("@")[0]
        input_name, approved_versions = TOOLCHAIN_INPUTS[action]
        version, input_errors = _literal_input(
            path,
            step,
            action,
            input_name,
        )
        errors.extend(input_errors)
        if version is None:
            continue
        counts[(action, version)] += 1
        if version not in approved_versions:
            approved = ", ".join(sorted(approved_versions))
            errors.append(
                f"{_location(path, uses)}: {action} {input_name} must equal "
                f"a reviewed exact version ({approved}), found {version!r}"
            )

        if action == "actions/setup-java":
            distribution, distribution_errors = _literal_input(
                path,
                step,
                action,
                "distribution",
            )
            errors.extend(distribution_errors)
            if distribution is not None and distribution != "temurin":
                errors.append(
                    f"{_location(path, uses)}: actions/setup-java distribution "
                    f"must equal 'temurin', found {distribution!r}"
                )

    return errors, counts


def validate_workflows(
    workflow_directory: Path,
    expected_counts: Mapping[tuple[str, str], int] | None = EXPECTED_TOOLCHAIN_COUNTS,
) -> list[str]:
    version_error = parser_version_error()
    if version_error is not None:
        return [version_error]

    files = workflow_files(workflow_directory)
    if not files:
        return [f"{workflow_directory}: no workflow YAML files found"]

    errors: list[str] = []
    actual_counts: Counter[tuple[str, str]] = Counter()
    for path in files:
        source = path.read_text(encoding="utf-8")
        try:
            tokens = tuple(yaml.scan(source, Loader=yaml.SafeLoader))
            documents = tuple(yaml.compose_all(source, Loader=yaml.SafeLoader))
        except yaml.YAMLError as error:
            errors.append(_yaml_error(path, error))
            continue

        for token in tokens:
            if isinstance(token, (AnchorToken, AliasToken)):
                errors.append(
                    f"{path}:{token.start_mark.line + 1}:"
                    f"{token.start_mark.column + 1}: YAML anchors and aliases are forbidden"
                )

        if len(documents) != 1 or documents[0] is None:
            errors.append(f"{path}: workflow must contain exactly one YAML document")
            continue
        root = documents[0]
        errors.extend(_structure_errors(path, root))
        toolchain_errors, counts = _toolchain_errors(path, root)
        errors.extend(toolchain_errors)
        actual_counts.update(counts)

    if expected_counts is not None:
        keys = set(expected_counts) | set(actual_counts)
        for action, version in sorted(keys):
            expected = expected_counts.get((action, version), 0)
            actual = actual_counts.get((action, version), 0)
            if actual != expected:
                errors.append(
                    f"{workflow_directory}: expected {expected} occurrence(s) of "
                    f"{action} {version}, found {actual}"
                )

    return errors


def main() -> int:
    errors = validate_workflows(DEFAULT_WORKFLOW_DIRECTORY)
    if errors:
        for error in errors:
            print(f"GitHub workflow toolchain policy error: {error}")
        return 1
    print(
        "GitHub workflow toolchain policy passed for "
        f"{len(workflow_files(DEFAULT_WORKFLOW_DIRECTORY))} workflow files."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
