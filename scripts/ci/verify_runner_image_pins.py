#!/usr/bin/env python3
"""Reject mutable or unreviewed GitHub-hosted runner image labels."""

from __future__ import annotations

import re
from pathlib import Path

import yaml
from yaml.nodes import MappingNode, Node, ScalarNode, SequenceNode
from yaml.tokens import AliasToken, AnchorToken


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_WORKFLOW_DIRECTORY = ROOT / ".github" / "workflows"
EXPECTED_PYYAML_VERSION = "6.0.3"
APPROVED_RUNNER_LABELS = frozenset({"ubuntu-24.04", "macos-26"})
STRING_TAG = "tag:yaml.org,2002:str"
BOOL_TAG = "tag:yaml.org,2002:bool"
MERGE_TAG = "tag:yaml.org,2002:merge"
JOB_ID_PATTERN = re.compile(r"^[A-Za-z_][A-Za-z0-9_-]*$")
YAML_1_2_STRING_JOB_IDS = frozenset({"on", "off", "yes", "no"})


def parser_version_error() -> str | None:
    if yaml.__version__ == EXPECTED_PYYAML_VERSION:
        return None
    return (
        "runner image policy requires PyYAML "
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


def _is_string_job_id(node: ScalarNode) -> bool:
    if node.tag == STRING_TAG:
        return True
    return node.tag == BOOL_TAG and node.value.lower() in YAML_1_2_STRING_JOB_IDS


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


def _validate_runner(
    path: Path,
    job_name: str,
    key: ScalarNode,
    value: Node,
) -> list[str]:
    location = _location(path, key)
    if not isinstance(value, ScalarNode) or value.tag != STRING_TAG:
        return [f"{location}: job {job_name!r} runs-on must be a string"]
    if (
        key.start_mark.line != value.start_mark.line
        or value.start_mark.line != value.end_mark.line
    ):
        return [
            f"{location}: job {job_name!r} runs-on must be an inline literal string"
        ]
    if value.value not in APPROVED_RUNNER_LABELS:
        approved = ", ".join(sorted(APPROVED_RUNNER_LABELS))
        return [
            f"{location}: job {job_name!r} uses unreviewed runner label "
            f"{value.value!r}; expected one of: {approved}"
        ]
    return []


def _runner_errors(path: Path, root: Node) -> list[str]:
    if not isinstance(root, MappingNode):
        return [f"{_location(path, root)}: workflow root must be a mapping"]

    jobs_values = _mapping_values(root, "jobs")
    if not jobs_values:
        return [f"{path}: workflow must define a jobs mapping"]
    jobs = jobs_values[0][1]
    if not isinstance(jobs, MappingNode) or not jobs.value:
        return [f"{_location(path, jobs)}: workflow jobs must be a non-empty mapping"]

    errors: list[str] = []
    for job_key, job in jobs.value:
        if (
            not isinstance(job_key, ScalarNode)
            or not _is_string_job_id(job_key)
            or JOB_ID_PATTERN.fullmatch(job_key.value) is None
        ):
            errors.append(
                f"{_location(path, job_key)}: workflow job id must be a YAML 1.2 "
                "string starting with a letter or underscore and containing only "
                "letters, digits, hyphens or underscores"
            )
            continue
        job_name = job_key.value
        if not isinstance(job, MappingNode):
            errors.append(
                f"{_location(path, job)}: job {job_name!r} must be a mapping"
            )
            continue
        declarations = _mapping_values(job, "runs-on")
        if not declarations:
            errors.append(
                f"{_location(path, job_key)}: job {job_name!r} must declare runs-on"
            )
            continue
        key, value = declarations[0]
        errors.extend(_validate_runner(path, job_name, key, value))

    return errors


def validate_workflows(workflow_directory: Path) -> list[str]:
    version_error = parser_version_error()
    if version_error is not None:
        return [version_error]

    files = workflow_files(workflow_directory)
    if not files:
        return [f"{workflow_directory}: no workflow YAML files found"]

    errors: list[str] = []
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
        errors.extend(_runner_errors(path, root))

    return errors


def main() -> int:
    errors = validate_workflows(DEFAULT_WORKFLOW_DIRECTORY)
    if errors:
        for error in errors:
            print(f"GitHub runner image policy error: {error}")
        return 1
    print(
        "GitHub runner image policy passed for "
        f"{len(workflow_files(DEFAULT_WORKFLOW_DIRECTORY))} workflow files."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
