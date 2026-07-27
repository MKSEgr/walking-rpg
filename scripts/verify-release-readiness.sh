#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT_DIR"

fail() {
  printf 'Release readiness error: %s\n' "$1" >&2
  exit 1
}

printf '%s\n' 'Checking required release files...'
for file in \
  .github/CODEOWNERS \
  .github/workflows/release-quality.yml \
  docs/ROADMAP.md \
  docs/RELEASE_CHECKLIST.md \
  docs/EXTERNAL_GATES.md \
  docs/DEVICE_VALIDATION_PROTOCOL.md \
  docs/evidence/health-device-validation-template.md \
  docs/STORE_DECLARATIONS.md \
  docs/CLOSED_BETA_RUNBOOK.md \
  docs/BRANCH_PROTECTION.md \
  docs/adr/0015-release-quality-and-external-gates.md \
  privacy/privacy-policy.md \
  scripts/generate-build-metadata.sh; do
  [ -f "$file" ] || fail "missing $file"
done

grep -Eq '^\* +@MKSEgr$' .github/CODEOWNERS || fail 'CODEOWNERS must assign all files to @MKSEgr'

printf '%s\n' 'Checking temporary transport files...'
if find .github -type f \( -name '*overlay*' -o -name 'export-*-source.yml' -o -name 'apply-*.yml' -o -name '*ci-trigger*' \) -print | grep -q .; then
  find .github -type f \( -name '*overlay*' -o -name 'export-*-source.yml' -o -name 'apply-*.yml' -o -name '*ci-trigger*' \) -print >&2
  fail 'temporary transport files are tracked'
fi

printf '%s\n' 'Checking Flyway sequence...'
python3 - <<'PY'
from pathlib import Path
import re
versions=[]
for path in Path('backend/src/main/resources/db/migration').glob('V*__*.sql'):
    match=re.fullmatch(r'V(\d+)__[^/]+\.sql', path.name)
    if not match:
        raise SystemExit(f'Unexpected migration name: {path.name}')
    versions.append(int(match.group(1)))
versions.sort()
expected=list(range(1, max(versions)+1)) if versions else []
if versions != expected or not versions or versions[-1] < 6:
    raise SystemExit(f'Flyway versions must be contiguous through at least V6: {versions}')
print('Flyway versions:', versions)
PY

printf '%s\n' 'Checking mobile release configuration...'
grep -Fq 'minSdk = 26' mobile/android/app/build.gradle.kts || fail 'Android minSdk must remain 26'
grep -Fq 'signingConfig = null' mobile/android/app/build.gradle.kts || fail 'Android CI release candidate must be unsigned'
if grep -Fq 'signingConfigs.getByName("debug")' mobile/android/app/build.gradle.kts; then
  fail 'Android release must never use the debug signing key'
fi
grep -Fq "platform :ios, '14.0'" mobile/ios/Podfile || fail 'Podfile deployment target must be iOS 14.0'

printf '%s\n' 'Checking tracked credentials and signing material...'
if find . -type f \( -name '*.jks' -o -name '*.keystore' -o -name '*.p12' -o -name '*.p8' -o -name '*.mobileprovision' -o -name 'key.properties' -o -name '.env' \) -not -path './.git/*' -print | grep -q .; then
  fail 'signing material or environment files must not be tracked'
fi
if grep -RIl --exclude-dir=.git --exclude='*.md' -E -- '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----' . | grep -q .; then
  fail 'private key material detected'
fi

printf '%s\n' 'Checking oversized source files...'
if find . -type f -size +5M -not -path './.git/*' -not -path './backend/target/*' -not -path './mobile/build/*' -print | grep -q .; then
  fail 'source file exceeds 5 MiB'
fi

printf '%s\n' 'Checking reproducible metadata...'
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
for output in one two; do
  GIT_SHA=0000000000000000000000000000000000000000 \
  SOURCE_DATE_EPOCH=1785139200 \
  FLUTTER_VERSION=3.44.7 \
  JAVA_VERSION=21 \
    sh scripts/generate-build-metadata.sh "$TMP_DIR/$output.json" >/dev/null
done
cmp "$TMP_DIR/one.json" "$TMP_DIR/two.json" || fail 'build metadata is not reproducible'

if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git diff --check
fi

printf '%s\n' 'Release readiness checks passed.'
