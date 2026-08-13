#!/usr/bin/env python3
"""Enforce reviewed build-tool wrapper downloads and bootstrap bytes."""

from __future__ import annotations

import hashlib
import stat
from pathlib import Path
from typing import Mapping


ROOT = Path(__file__).resolve().parents[2]
MAVEN_PROPERTIES = ROOT / "backend" / ".mvn" / "wrapper" / "maven-wrapper.properties"
MAVEN_SHELL = ROOT / "backend" / "mvnw"
MAVEN_POWERSHELL = ROOT / "backend" / ".mvn" / "wrapper" / "mvnw.ps1"
GRADLE_PROPERTIES = (
    ROOT / "mobile" / "android" / "gradle" / "wrapper" / "gradle-wrapper.properties"
)
GRADLE_WRAPPER_JAR = (
    ROOT / "mobile" / "android" / "gradle" / "wrapper" / "gradle-wrapper.jar"
)

# Maven's distribution was cross-checked against Apache's published SHA-512
# before recording the SHA-256 required by the wrapper contract.
APPROVED_MAVEN_PROPERTIES = {
    "wrapperVersion": "3.3.4",
    "distributionType": "only-script",
    "distributionUrl": (
        "https://repo.maven.apache.org/maven2/org/apache/maven/apache-maven/"
        "3.9.16/apache-maven-3.9.16-bin.zip"
    ),
    "distributionSha256Sum": (
        "5af3b743dd8b876b5c45da33b676251e5f1687712644abb4ee519ca56e1d89ce"
    ),
}
APPROVED_GRADLE_DISTRIBUTION_SHA256 = (
    "b84e04fa845fecba48551f425957641074fcc00a88a84d2aae5808743b35fc85"
)
APPROVED_GRADLE_CACHE_PATH = (
    f"wrapper/dists/sha256-{APPROVED_GRADLE_DISTRIBUTION_SHA256}"
)
# Distribution and wrapper JAR values come from Gradle's release-checksums
# reference. The existing official 2.10 bootstrap JAR already supports the
# distribution checksum property and remains independently pinned here. The
# checksum-bound namespace invalidates installations cached before that
# property was added, because this wrapper trusts an existing `.ok` marker.
APPROVED_GRADLE_PROPERTIES = {
    "distributionBase": "GRADLE_USER_HOME",
    "distributionPath": APPROVED_GRADLE_CACHE_PATH,
    "zipStoreBase": "GRADLE_USER_HOME",
    "zipStorePath": APPROVED_GRADLE_CACHE_PATH,
    "distributionUrl": (
        "https\\://services.gradle.org/distributions/gradle-9.1.0-all.zip"
    ),
    "distributionSha256Sum": APPROVED_GRADLE_DISTRIBUTION_SHA256,
}
APPROVED_GRADLE_WRAPPER_SHA256 = (
    "16caeaf66d57a0d1d2087fef6a97efa62de8da69afa5b908f40db35afc4342da"
)

SHELL_REQUIRED_SNIPPETS = (
    "DISTRIBUTION_SHA256_COUNT=$(grep -c '^distributionSha256Sum='",
    "INSTALL_DIR=\"$CACHE_ROOT/apache-maven-$MAVEN_VERSION-$DISTRIBUTION_SHA256_SUM\"",
    'ACTUAL_SHA256_SUM=$(sha256sum "$ARCHIVE"',
    'ACTUAL_SHA256_SUM=$(shasum -a 256 "$ARCHIVE"',
    'if [ "$ACTUAL_SHA256_SUM" != "$DISTRIBUTION_SHA256_SUM" ]; then',
    'echo "Maven distribution SHA-256 mismatch"',
    "elif command -v jar >/dev/null 2>&1; then",
    '(cd "$TMP_DIR" && jar xf "$ARCHIVE")',
    'chmod 0555 "$TMP_DIR/apache-maven-$MAVEN_VERSION/bin/mvn"',
)
POWERSHELL_REQUIRED_SNIPPETS = (
    '$DistributionSha256Sum = $Properties["distributionSha256Sum"]',
    '"^[0-9a-f]{64}$"',
    'apache-maven-$MavenVersion-$DistributionSha256Sum',
    "Get-FileHash -Path $Archive -Algorithm SHA256",
    "if ($ActualSha256Sum -cne $DistributionSha256Sum)",
    "Maven distribution SHA-256 mismatch",
)


def _parse_properties(source: str, path: Path) -> tuple[dict[str, str], list[str]]:
    values: dict[str, str] = {}
    errors: list[str] = []
    for line_number, line in enumerate(source.splitlines(), start=1):
        if not line or line.startswith(("#", "!")):
            continue
        if "=" not in line:
            errors.append(f"{path}:{line_number}: property must use key=value form")
            continue
        key, value = line.split("=", 1)
        if not key or key != key.strip() or value != value.strip():
            errors.append(
                f"{path}:{line_number}: property must use canonical key=value form"
            )
            continue
        if key in values:
            errors.append(f"{path}:{line_number}: duplicate property {key}")
            continue
        values[key] = value
    return values, errors


def validate_properties_source(
    source: str,
    expected: Mapping[str, str],
    path: Path,
) -> list[str]:
    values, errors = _parse_properties(source, path)
    for key in sorted(set(expected) - set(values)):
        errors.append(f"{path}: missing reviewed property {key}")
    for key in sorted(set(values) - set(expected)):
        errors.append(f"{path}: unexpected property {key}")
    for key in sorted(set(expected) & set(values)):
        if values[key] != expected[key]:
            errors.append(f"{path}: {key} must equal the reviewed value")
    return errors


def validate_launcher_sources(shell_source: str, powershell_source: str) -> list[str]:
    errors: list[str] = []
    for snippet in SHELL_REQUIRED_SNIPPETS:
        if snippet not in shell_source:
            errors.append(f"{MAVEN_SHELL}: missing checksum enforcement: {snippet}")
    shell_verify = shell_source.find(
        'if [ "$ACTUAL_SHA256_SUM" != "$DISTRIBUTION_SHA256_SUM" ]; then'
    )
    shell_extractors = (
        shell_source.find('unzip -q "$ARCHIVE"'),
        shell_source.find('jar xf "$ARCHIVE"'),
    )
    if (
        shell_verify < 0
        or any(extractor < 0 for extractor in shell_extractors)
        or any(shell_verify > extractor for extractor in shell_extractors)
    ):
        errors.append(
            f"{MAVEN_SHELL}: checksum comparison must precede every extraction path"
        )

    for snippet in POWERSHELL_REQUIRED_SNIPPETS:
        if snippet not in powershell_source:
            errors.append(
                f"{MAVEN_POWERSHELL}: missing checksum enforcement: {snippet}"
            )
    powershell_verify = powershell_source.find(
        "if ($ActualSha256Sum -cne $DistributionSha256Sum)"
    )
    powershell_extract = powershell_source.find("Expand-Archive -Path $Archive")
    if (
        powershell_verify < 0
        or powershell_extract < 0
        or powershell_verify > powershell_extract
    ):
        errors.append(
            f"{MAVEN_POWERSHELL}: checksum comparison must precede extraction"
        )
    return errors


def validate_wrapper_jar_bytes(content: bytes, path: Path) -> list[str]:
    actual = hashlib.sha256(content).hexdigest()
    if actual != APPROVED_GRADLE_WRAPPER_SHA256:
        return [
            f"{path}: Gradle wrapper JAR SHA-256 must equal the reviewed "
            f"{APPROVED_GRADLE_WRAPPER_SHA256}"
        ]
    return []


def _read_text(path: Path) -> tuple[str | None, list[str]]:
    try:
        if path.is_symlink() or not path.is_file():
            return None, [f"{path}: required regular file is missing"]
        return path.read_text(encoding="utf-8"), []
    except (OSError, UnicodeError) as error:
        return None, [f"{path}: cannot read UTF-8 file: {error}"]


def validate_repository() -> list[str]:
    errors: list[str] = []
    maven_properties, read_errors = _read_text(MAVEN_PROPERTIES)
    errors.extend(read_errors)
    if maven_properties is not None:
        errors.extend(
            validate_properties_source(
                maven_properties, APPROVED_MAVEN_PROPERTIES, MAVEN_PROPERTIES
            )
        )

    gradle_properties, read_errors = _read_text(GRADLE_PROPERTIES)
    errors.extend(read_errors)
    if gradle_properties is not None:
        errors.extend(
            validate_properties_source(
                gradle_properties, APPROVED_GRADLE_PROPERTIES, GRADLE_PROPERTIES
            )
        )

    shell_source, read_errors = _read_text(MAVEN_SHELL)
    errors.extend(read_errors)
    powershell_source, read_errors = _read_text(MAVEN_POWERSHELL)
    errors.extend(read_errors)
    if shell_source is not None and powershell_source is not None:
        errors.extend(validate_launcher_sources(shell_source, powershell_source))

    try:
        jar_stat = GRADLE_WRAPPER_JAR.lstat()
        if not stat.S_ISREG(jar_stat.st_mode):
            errors.append(f"{GRADLE_WRAPPER_JAR}: must be a regular file")
        else:
            errors.extend(
                validate_wrapper_jar_bytes(
                    GRADLE_WRAPPER_JAR.read_bytes(), GRADLE_WRAPPER_JAR
                )
            )
    except OSError as error:
        errors.append(f"{GRADLE_WRAPPER_JAR}: cannot read wrapper JAR: {error}")
    return errors


def main() -> int:
    errors = validate_repository()
    if errors:
        for error in errors:
            print(f"Build-tool wrapper pin policy error: {error}")
        return 1
    print(
        "Build-tool wrapper pin policy passed for Maven distribution, "
        "Gradle distribution and Gradle wrapper JAR."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
