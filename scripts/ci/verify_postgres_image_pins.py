#!/usr/bin/env python3
"""Reject mutable or divergent PostgreSQL test infrastructure images."""

from __future__ import annotations

import re
from pathlib import Path

import yaml
from yaml.events import AliasEvent
from yaml.nodes import MappingNode, Node, ScalarNode, SequenceNode


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_COMPOSE = ROOT / "compose.yaml"
DEFAULT_TEST_ROOT = ROOT / "backend" / "src" / "test" / "java"
DEFAULT_FACTORY = (
    DEFAULT_TEST_ROOT
    / "com"
    / "walkingrpg"
    / "backend"
    / "testsupport"
    / "PostgresTestContainer.java"
)
EXPECTED_PYYAML_VERSION = "6.0.3"
APPROVED_TAG = "postgres:17.10-alpine3.24"
APPROVED_DIGEST = (
    "sha256:742f40ea20b9ff2ff31db5458d127452988a2164df9e17441e191f3b72252193"
)
APPROVED_COMPOSE_IMAGE = f"{APPROVED_TAG}@{APPROVED_DIGEST}"
FACTORY_IMPORT = (
    "import com.walkingrpg.backend.testsupport.PostgresTestContainer;"
)
FACTORY_CALL = "PostgresTestContainer.create("
DIRECT_POSTGRES_CONSTRUCTOR = re.compile(
    r"\bnew\b[^;{}]{0,256}\bPostgreSQLContainer"
    r"(?:\s*<[^;{}()]{0,80}>)?\s*\(",
    re.DOTALL,
)
DIRECT_GENERIC_CONSTRUCTOR = re.compile(
    r"\bnew\b[^;{}]{0,256}\bGenericContainer"
    r"(?:\s*<[^;{}()]{0,80}>)?\s*\(",
    re.DOTALL,
)
POSTGRES_CONTAINER_SUBCLASS = re.compile(
    r"\bextends\b[^;{}]{0,160}\bPostgreSQLContainer\b",
    re.DOTALL,
)
POSTGRES_IMAGE_LITERAL = re.compile(r'"postgres(?::|@)[^"\r\n]*"')


def parser_version_error() -> str | None:
    if yaml.__version__ == EXPECTED_PYYAML_VERSION:
        return None
    return (
        "PostgreSQL image pin policy requires PyYAML "
        f"{EXPECTED_PYYAML_VERSION}, found {yaml.__version__}"
    )


def _yaml_error(path: Path, error: yaml.YAMLError) -> str:
    mark = getattr(error, "problem_mark", None)
    if mark is None:
        return f"{path}: invalid Compose YAML: {error}"
    problem = getattr(error, "problem", None) or "invalid YAML"
    return (
        f"{path}:{mark.line + 1}:{mark.column + 1}: "
        f"invalid Compose YAML: {problem}"
    )


def _validate_yaml_nodes(node: Node, path: Path, errors: list[str]) -> None:
    pending: list[Node] = [node]
    visited: set[int] = set()
    while pending:
        current = pending.pop()
        identity = id(current)
        if identity in visited:
            continue
        visited.add(identity)
        if isinstance(current, MappingNode):
            seen: set[str] = set()
            for key, value in current.value:
                location = (
                    f"{path}:{key.start_mark.line + 1}:"
                    f"{key.start_mark.column + 1}"
                )
                if (
                    not isinstance(key, ScalarNode)
                    or key.tag != "tag:yaml.org,2002:str"
                ):
                    errors.append(f"{location}: Compose mapping key must be a string")
                elif key.value in seen:
                    errors.append(f"{location}: duplicate Compose key {key.value!r}")
                else:
                    seen.add(key.value)
                pending.extend((key, value))
        elif isinstance(current, SequenceNode):
            pending.extend(current.value)


def _mapping_value(node: Node, key_name: str) -> Node | None:
    if not isinstance(node, MappingNode):
        return None
    for key, value in node.value:
        if isinstance(key, ScalarNode) and key.value == key_name:
            return value
    return None


def validate_compose_source(source: str, path: Path) -> list[str]:
    errors: list[str] = []
    try:
        events = tuple(yaml.parse(source, Loader=yaml.SafeLoader))
        documents = tuple(yaml.compose_all(source, Loader=yaml.SafeLoader))
    except yaml.YAMLError as error:
        return [_yaml_error(path, error)]

    if any(
        isinstance(event, AliasEvent) or getattr(event, "anchor", None) is not None
        for event in events
    ):
        errors.append(f"{path}: Compose anchors and aliases are not allowed")
    if len(documents) != 1 or documents[0] is None:
        errors.append(f"{path}: Compose must contain exactly one YAML document")
        return errors

    root = documents[0]
    _validate_yaml_nodes(root, path, errors)
    services = _mapping_value(root, "services")
    postgres = _mapping_value(services, "postgres") if services is not None else None
    image = _mapping_value(postgres, "image") if postgres is not None else None
    if not isinstance(services, MappingNode):
        errors.append(f"{path}: Compose services must be a mapping")
    if not isinstance(postgres, MappingNode):
        errors.append(f"{path}: Compose must declare the postgres service as a mapping")
    if (
        not isinstance(image, ScalarNode)
        or image.tag != "tag:yaml.org,2002:str"
    ):
        errors.append(f"{path}: services.postgres.image must be a literal string")
    elif image.value != APPROVED_COMPOSE_IMAGE:
        errors.append(
            f"{path}:{image.start_mark.line + 1}:{image.start_mark.column + 1}: "
            "services.postgres.image must use the reviewed "
            f"tag@digest {APPROVED_COMPOSE_IMAGE}"
        )
    return errors


def validate_compose(path: Path) -> list[str]:
    try:
        source = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
        return [f"{path}: cannot read Compose contract: {error}"]
    return validate_compose_source(source, path)


def _sanitize_java(source: str, *, remove_literals: bool) -> str:
    """Remove comments and optionally literals while preserving token positions."""
    result = list(source)
    index = 0
    length = len(source)
    while index < length:
        if source.startswith("//", index):
            end = source.find("\n", index + 2)
            end = length if end < 0 else end
            for position in range(index, end):
                result[position] = " "
            index = end
            continue
        if source.startswith("/*", index):
            end = source.find("*/", index + 2)
            end = length if end < 0 else end + 2
            for position in range(index, end):
                if result[position] not in "\r\n":
                    result[position] = " "
            index = end
            continue
        if source.startswith('"""', index):
            end = source.find('"""', index + 3)
            end = length if end < 0 else end + 3
            if remove_literals:
                for position in range(index, end):
                    if result[position] not in "\r\n":
                        result[position] = " "
            index = end
            continue
        if source[index] in {'"', "'"}:
            quote = source[index]
            end = index + 1
            while end < length:
                if source[end] == "\\":
                    end += 2
                    continue
                end += 1
                if source[end - 1] == quote:
                    break
            if remove_literals:
                for position in range(index, min(end, length)):
                    if result[position] not in "\r\n":
                        result[position] = " "
            index = end
            continue
        index += 1
    return "".join(result)


def _java_tokens(source: str) -> tuple[str, ...]:
    """Tokenize the policy-relevant Java subset without trusting decoy text."""
    source = _sanitize_java(source, remove_literals=False)
    tokens: list[str] = []
    index = 0
    while index < len(source):
        if source[index].isspace():
            index += 1
            continue
        if source.startswith('"""', index):
            end = source.find('"""', index + 3)
            end = len(source) if end < 0 else end + 3
            tokens.append(source[index:end])
            index = end
            continue
        if source[index] in {'"', "'"}:
            quote = source[index]
            end = index + 1
            while end < len(source):
                if source[end] == "\\":
                    end += 2
                    continue
                end += 1
                if source[end - 1] == quote:
                    break
            tokens.append(source[index : min(end, len(source))])
            index = end
            continue
        if source[index].isalpha() or source[index] in {"_", "$"}:
            end = index + 1
            while end < len(source) and (
                source[end].isalnum() or source[end] in {"_", "$"}
            ):
                end += 1
            tokens.append(source[index:end])
            index = end
            continue
        tokens.append(source[index])
        index += 1
    return tuple(tokens)


def _token_sequence_count(tokens: tuple[str, ...], expected: tuple[str, ...]) -> int:
    width = len(expected)
    return sum(
        tokens[index : index + width] == expected
        for index in range(len(tokens) - width + 1)
    )


def _validate_factory(source: str, path: Path) -> list[str]:
    contract_source = _sanitize_java(source, remove_literals=False)
    tokens = _java_tokens(source)
    required_sequences = (
        (
            "IMAGE_TAG declaration",
            (
                "public", "static", "final", "String", "IMAGE_TAG", "=",
                f'"{APPROVED_TAG}"', ";",
            ),
        ),
        (
            "IMAGE_DIGEST declaration",
            (
                "public", "static", "final", "String", "IMAGE_DIGEST", "=",
                f'"{APPROVED_DIGEST}"', ";",
            ),
        ),
        (
            "IMAGE declaration",
            (
                "public", "static", "final", "String", "IMAGE", "=",
                '"postgres@"', "+", "IMAGE_DIGEST", ";",
            ),
        ),
        (
            "DOCKER_IMAGE declaration",
            (
                "private", "static", "final", "DockerImageName",
                "DOCKER_IMAGE", "=", "DockerImageName", ".", "parse", "(",
                "IMAGE", ")", ".", "asCompatibleSubstituteFor", "(",
                '"postgres"', ")", ";",
            ),
        ),
        (
            "create method",
            (
                "public", "static", "PostgreSQLContainer", "create", "(", ")",
                "{", "return", "new", "PostgreSQLContainer", "(",
                "DOCKER_IMAGE", ")", ";", "}",
            ),
        ),
    )
    errors: list[str] = []
    for description, expected in required_sequences:
        if _token_sequence_count(tokens, expected) != 1:
            errors.append(
                f"{path}: shared factory must contain exactly one reviewed "
                f"{description}"
            )
    code = _sanitize_java(source, remove_literals=True)
    if len(DIRECT_POSTGRES_CONSTRUCTOR.findall(code)) != 1:
        errors.append(
            f"{path}: shared factory must contain exactly one "
            "PostgreSQLContainer constructor"
        )
    if code.count("DockerImageName.parse(") != 1:
        errors.append(
            f"{path}: shared factory must contain exactly one Docker image parser"
        )
    if DIRECT_GENERIC_CONSTRUCTOR.search(code):
        errors.append(f"{path}: shared factory must not create GenericContainer")
    if POSTGRES_CONTAINER_SUBCLASS.search(code):
        errors.append(f"{path}: shared factory must not subclass PostgreSQLContainer")
    allowed_literals = {f'"{APPROVED_TAG}"', '"postgres@"'}
    for literal in POSTGRES_IMAGE_LITERAL.findall(contract_source):
        if literal not in allowed_literals:
            errors.append(f"{path}: unreviewed PostgreSQL image literal {literal}")
    return errors


def validate_java_sources(test_root: Path, factory_path: Path) -> list[str]:
    errors: list[str] = []
    files = tuple(sorted(test_root.rglob("*.java")))
    if not files:
        return [f"{test_root}: no Java test sources found"]
    if factory_path not in files:
        errors.append(f"{factory_path}: shared PostgreSQL test factory is missing")

    for path in files:
        try:
            source = path.read_text(encoding="utf-8")
        except (OSError, UnicodeError) as error:
            errors.append(f"{path}: cannot read Java test source: {error}")
            continue
        if path == factory_path:
            errors.extend(_validate_factory(source, path))
            continue

        contract_source = _sanitize_java(source, remove_literals=False)
        code = _sanitize_java(source, remove_literals=True)
        if DIRECT_POSTGRES_CONSTRUCTOR.search(code):
            errors.append(
                f"{path}: direct PostgreSQLContainer construction is forbidden; "
                "use PostgresTestContainer.create()"
            )
        if DIRECT_GENERIC_CONSTRUCTOR.search(code):
            errors.append(
                f"{path}: direct GenericContainer construction requires a "
                "reviewed shared image factory"
            )
        if POSTGRES_CONTAINER_SUBCLASS.search(code):
            errors.append(
                f"{path}: PostgreSQLContainer subclasses cannot bypass the "
                "shared factory"
            )
        if "PostgreSQLContainer" in code:
            if FACTORY_IMPORT not in code:
                errors.append(
                    f"{path}: PostgreSQL tests must import the shared factory"
                )
            if FACTORY_CALL not in code:
                errors.append(f"{path}: PostgreSQL tests must use the shared factory")
            if "DockerImageName.parse(" in code:
                errors.append(
                    f"{path}: PostgreSQL tests must not parse an image outside "
                    "the shared factory"
                )
        for literal in POSTGRES_IMAGE_LITERAL.findall(contract_source):
            errors.append(
                f"{path}: PostgreSQL image literal must live in the shared "
                f"factory: {literal}"
            )
    return errors


def validate_repository(
    compose_path: Path = DEFAULT_COMPOSE,
    test_root: Path = DEFAULT_TEST_ROOT,
    factory_path: Path = DEFAULT_FACTORY,
) -> list[str]:
    version_error = parser_version_error()
    if version_error is not None:
        return [version_error]
    return [
        *validate_compose(compose_path),
        *validate_java_sources(test_root, factory_path),
    ]


def main() -> int:
    errors = validate_repository()
    if errors:
        for error in errors:
            print(f"PostgreSQL image pin policy error: {error}")
        return 1
    print(
        "PostgreSQL image pin policy passed for Compose and "
        f"{len(tuple(DEFAULT_TEST_ROOT.rglob('*.java')))} Java test sources."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
