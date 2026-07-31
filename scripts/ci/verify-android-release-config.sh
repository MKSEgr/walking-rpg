#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
ANDROID_DIR="$ROOT_DIR/mobile/android"
APP_BUILD_FILE="$ANDROID_DIR/app/build.gradle.kts"
MODE="${1:---static}"

fail() {
  printf 'Android release configuration error: %s\n' "$1" >&2
  exit 1
}

case "$MODE" in
  --static|--rehearse)
    ;;
  *)
    fail "usage: $0 [--static|--rehearse]"
    ;;
esac

python3 - "$APP_BUILD_FILE" <<'PY'
from pathlib import Path
import re
import sys

build_file = Path(sys.argv[1])
source = build_file.read_text(encoding="utf-8")

required_patterns = {
    "compileSdk must be pinned to API 36": r"(?m)^\s*compileSdk\s*=\s*36\s*$",
    "targetSdk must be pinned to API 36": r"(?m)^\s*targetSdk\s*=\s*36\s*$",
    "minSdk must remain API 26": r"(?m)^\s*minSdk\s*=\s*26\s*$",
    "signing must use the opt-in Gradle project property": (
        r'providers\.gradleProperty\("walkingRpgSigningProperties"\)'
    ),
    "release signing must remain nullable when the property is absent": (
        r"signingConfig\s*=\s*productionSigningConfig"
    ),
    "the production signing config must be isolated": (
        r'signingConfigs\.create\("walkingRpgProduction"\)'
    ),
    "the external-path repository boundary must be enforced": (
        r"must be outside the repository"
    ),
    "signing paths must be absolute": (
        r"configuredFile\.isAbsolute"
    ),
    "the signing properties schema must reject unknown or missing keys": (
        r"signingValues\.keys\s*==\s*requiredSigningKeys"
    ),
    "duplicate signing keys must be rejected": (
        r"require\(!signingValues\.containsKey\(key\)\)"
    ),
    "properties continuation syntax must be rejected": (
        r'require\(!rawLine\.endsWith\("\\\\"\)\)'
    ),
    "effective signing fields must be verified": (
        r'configuredReleaseSigning\.keyPassword\s*==\s*'
        r'properties\.getValue\("keyPassword"\)'
    ),
    "the configured keystore must be opened": (
        r"keyStore\.load\("
    ),
    "the configured private key must be unlocked": (
        r"key\s+is\s+PrivateKey"
    ),
    "the private key must have a certificate chain": (
        r"getCertificateChain\(alias\)"
    ),
}

for message, pattern in required_patterns.items():
    if re.search(pattern, source) is None:
        raise SystemExit(f"Android release configuration error: {message}")

required_keys = {"storeFile", "storePassword", "keyAlias", "keyPassword"}
declared_keys_match = re.search(
    r"val requiredSigningKeys\s*=\s*setOf\((.*?)\n\s*\)",
    source,
    flags=re.DOTALL,
)
if declared_keys_match is None:
    raise SystemExit(
        "Android release configuration error: required signing keys are not declared"
    )
declared_keys = set(re.findall(r'"([^"]+)"', declared_keys_match.group(1)))
if declared_keys != required_keys:
    raise SystemExit(
        "Android release configuration error: signing properties must use exactly "
        + ", ".join(sorted(required_keys))
    )

for forbidden in (
    'signingConfigs.getByName("debug")',
    'signingConfigs["debug"]',
    "signingConfig = signingConfigs.debug",
):
    if forbidden in source:
        raise SystemExit(
            "Android release configuration error: release signing must never use debug keys"
        )

print("Android API 36 and fail-closed signing scaffold verified statically.")
PY

if [[ "$MODE" == "--static" ]]; then
  exit 0
fi

command -v keytool >/dev/null 2>&1 || fail "keytool is required for the signing rehearsal"
[[ -x "$ANDROID_DIR/gradlew" ]] || fail "Android Gradle wrapper is not executable"

umask 077
rehearsal_parent=${RUNNER_TEMP:-${TMPDIR:-/tmp}}
[[ -d "$rehearsal_parent" ]] || fail "temporary directory does not exist"
rehearsal_dir=$(mktemp -d "$rehearsal_parent/walking-rpg-signing.XXXXXX")
keystore_file="$rehearsal_dir/synthetic-release.p12"
valid_properties="$rehearsal_dir/valid-signing.properties"
invalid_properties="$rehearsal_dir/invalid-signing.properties"
missing_properties="$rehearsal_dir/missing-signing.properties"
blank_properties="$rehearsal_dir/blank-signing.properties"
duplicate_properties="$rehearsal_dir/duplicate-signing.properties"
symlink_properties="$rehearsal_dir/symlink-signing.properties"
symlink_keystore="$rehearsal_dir/synthetic-release-link.p12"
symlink_keystore_properties="$rehearsal_dir/symlink-keystore-signing.properties"
inside_keystore_properties="$rehearsal_dir/inside-keystore-signing.properties"
inside_properties="$ANDROID_DIR/.gradle/synthetic-signing.properties"

cleanup() {
  rm -f -- \
    "$valid_properties" \
    "$invalid_properties" \
    "$missing_properties" \
    "$blank_properties" \
    "$duplicate_properties" \
    "$symlink_properties" \
    "$symlink_keystore" \
    "$symlink_keystore_properties" \
    "$inside_keystore_properties" \
    "$inside_properties" \
    "$keystore_file"
  rmdir -- "$rehearsal_dir" 2>/dev/null || true
}
trap cleanup EXIT

expect_rejected_signing_properties() {
  local properties_path=$1
  local failure_message=$2
  if (
    cd "$ANDROID_DIR"
    ./gradlew --no-daemon --console=plain \
      "-PwalkingRpgSigningProperties=$properties_path" \
      :app:verifyWalkingRpgAndroidReleaseConfiguration \
      >/dev/null 2>&1
  ); then
    fail "$failure_message"
  fi
}

synthetic_password=$(od -An -N24 -tx1 /dev/urandom | tr -d ' \n')
synthetic_alias="walking-rpg-synthetic"

keytool -genkeypair \
  -keystore "$keystore_file" \
  -storetype PKCS12 \
  -storepass "$synthetic_password" \
  -keypass "$synthetic_password" \
  -alias "$synthetic_alias" \
  -dname "CN=Walking RPG Synthetic Signing, OU=CI, O=Walking RPG, L=Berlin, C=DE" \
  -keyalg RSA \
  -keysize 2048 \
  -validity 1 \
  -noprompt \
  >/dev/null 2>&1

printf '%s\n' \
  "storeFile=$keystore_file" \
  "storePassword=$synthetic_password" \
  "keyAlias=$synthetic_alias" \
  "keyPassword=$synthetic_password" \
  > "$valid_properties"

printf '%s\n' \
  "storeFile=$keystore_file" \
  "storePassword=$synthetic_password" \
  "keyAlias=$synthetic_alias" \
  "keyPassword=$synthetic_password" \
  "unexpectedKey=rejected" \
  > "$invalid_properties"

printf '%s\n' \
  "storeFile=$keystore_file" \
  "storePassword=$synthetic_password" \
  "keyAlias=$synthetic_alias" \
  > "$missing_properties"

printf '%s\n' \
  "storeFile=$keystore_file" \
  "storePassword=$synthetic_password" \
  "keyAlias=$synthetic_alias" \
  "keyPassword=" \
  > "$blank_properties"

printf '%s\n' \
  "storeFile=$keystore_file" \
  "storePassword=$synthetic_password" \
  "keyAlias=$synthetic_alias" \
  "keyPassword=$synthetic_password" \
  "keyAlias=duplicate-must-fail" \
  > "$duplicate_properties"

printf '%s\n' \
  "storeFile=$APP_BUILD_FILE" \
  "storePassword=$synthetic_password" \
  "keyAlias=$synthetic_alias" \
  "keyPassword=$synthetic_password" \
  > "$inside_keystore_properties"

ln -s -- "$valid_properties" "$symlink_properties"
ln -s -- "$keystore_file" "$symlink_keystore"
printf '%s\n' \
  "storeFile=$symlink_keystore" \
  "storePassword=$synthetic_password" \
  "keyAlias=$synthetic_alias" \
  "keyPassword=$synthetic_password" \
  > "$symlink_keystore_properties"

(
  cd "$ANDROID_DIR"
  ./gradlew --no-daemon --console=plain \
    :app:verifyWalkingRpgAndroidReleaseConfiguration
)

expect_rejected_signing_properties \
  "$invalid_properties" \
  "a signing properties file with an unknown key was accepted"
expect_rejected_signing_properties \
  "$missing_properties" \
  "a signing properties file with a missing key was accepted"
expect_rejected_signing_properties \
  "$blank_properties" \
  "a signing properties file with a blank value was accepted"
expect_rejected_signing_properties \
  "$duplicate_properties" \
  "a signing properties file with a duplicate key was accepted"
expect_rejected_signing_properties \
  "$symlink_properties" \
  "a symlinked signing properties file was accepted"
expect_rejected_signing_properties \
  "relative-signing.properties" \
  "a relative signing properties path was accepted"
expect_rejected_signing_properties \
  "$symlink_keystore_properties" \
  "a symlinked keystore path was accepted"
expect_rejected_signing_properties \
  "$inside_keystore_properties" \
  "a repository-local keystore path was accepted"

mkdir -p -- "$(dirname -- "$inside_properties")"
printf '%s\n' \
  "storeFile=$keystore_file" \
  "storePassword=$synthetic_password" \
  "keyAlias=$synthetic_alias" \
  "keyPassword=$synthetic_password" \
  > "$inside_properties"

expect_rejected_signing_properties \
  "$inside_properties" \
  "a signing properties file inside the repository was accepted"

(
  cd "$ANDROID_DIR"
  ORG_GRADLE_PROJECT_walkingRpgSigningProperties="$valid_properties" \
    ./gradlew --no-daemon --console=plain \
      :app:verifyWalkingRpgAndroidReleaseConfiguration \
      :app:validateSigningRelease
)

printf '%s\n' \
  "Unsigned default and ephemeral signing-scaffold validation passed; no signed artifact was built."
