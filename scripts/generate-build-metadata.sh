#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUTPUT_PATH=${1:-"$ROOT_DIR/build/release/build-metadata.json"}

: "${GIT_SHA:=$(git -C "$ROOT_DIR" rev-parse HEAD 2>/dev/null || printf '%s' unknown)}"
: "${SOURCE_DATE_EPOCH:=$(git -C "$ROOT_DIR" show -s --format=%ct HEAD 2>/dev/null || printf '%s' 0)}"
: "${FLUTTER_VERSION:=3.44.7}"
: "${JAVA_VERSION:=21}"

export ROOT_DIR OUTPUT_PATH GIT_SHA SOURCE_DATE_EPOCH FLUTTER_VERSION JAVA_VERSION
python3 - <<'PY'
import datetime as dt
import json
import os
import pathlib
import re

root = pathlib.Path(os.environ['ROOT_DIR'])
out = pathlib.Path(os.environ['OUTPUT_PATH'])
sha = os.environ['GIT_SHA'].strip()
if not re.fullmatch(r'(?:[0-9a-f]{40}|unknown)', sha):
    raise SystemExit('GIT_SHA must be a 40-character lowercase SHA or unknown')
epoch = int(os.environ['SOURCE_DATE_EPOCH'])
if epoch < 0:
    raise SystemExit('SOURCE_DATE_EPOCH must be non-negative')

pubspec = (root / 'mobile/pubspec.yaml').read_text(encoding='utf-8')
version = re.search(r'^version:\s*([^+\s]+)\+(\d+)\s*$', pubspec, re.MULTILINE)
if not version:
    raise SystemExit('Unable to read mobile version')

migrations = sorted(
    int(match.group(1))
    for path in (root / 'backend/src/main/resources/db/migration').glob('V*__*.sql')
    if (match := re.match(r'V(\d+)__', path.name))
)
content_java = (root / 'backend/src/main/java/com/walkingrpg/backend/expedition/application/StarterExpeditionContent.java').read_text(encoding='utf-8')
content = re.search(r'CONTENT_VERSION\s*=\s*"([^"]+)"', content_java)
gradle = (root / 'mobile/android/app/build.gradle.kts').read_text(encoding='utf-8')
android_id = re.search(r'applicationId\s*=\s*"([^"]+)"', gradle)
min_sdk = re.search(r'minSdk\s*=\s*(\d+)', gradle)
if not migrations or not content or not android_id or not min_sdk:
    raise SystemExit('Unable to derive release metadata from source')

metadata = {
    'android': {
        'applicationId': android_id.group(1),
        'minSdk': int(min_sdk.group(1)),
        'releaseSigning': 'external-protected-environment',
    },
    'application': {
        'buildNumber': int(version.group(2)),
        'version': version.group(1),
    },
    'backend': {
        'flywayLatestVersion': max(migrations),
        'javaVersion': os.environ['JAVA_VERSION'],
    },
    'contentVersion': content.group(1),
    'flutterVersion': os.environ['FLUTTER_VERSION'],
    'ios': {
        'bundleIdentifier': 'com.walkingrpg.walkingRpgMobile',
        'deploymentTarget': '14.0',
        'releaseSigning': 'external-protected-environment',
    },
    'schemaVersion': 1,
    'source': {
        'commitSha': sha,
        'dateUtc': dt.datetime.fromtimestamp(epoch, tz=dt.timezone.utc).isoformat().replace('+00:00', 'Z'),
        'epoch': epoch,
    },
}
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(metadata, ensure_ascii=False, indent=2, sort_keys=True) + '\n', encoding='utf-8')
PY

printf '%s\n' "Generated deterministic metadata: $OUTPUT_PATH"
