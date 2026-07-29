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
  docs/adr/0017-production-authentication-boundary.md \
  docs/adr/0018-mobile-oidc-session.md \
  backend/src/main/java/com/walkingrpg/backend/security/SecurityModeGuard.java \
  mobile/lib/core/auth/auth_session_controller.dart \
  mobile/lib/features/home/data/auth_home_transports.dart \
  backend/src/main/resources/application-local.yml \
  backend/src/main/resources/application-prod.yml \
  privacy/privacy-policy.md \
  scripts/generate-build-metadata.sh; do
  [ -f "$file" ] || fail "missing $file"
done

grep -Eq '^\* +@MKSEgr$' .github/CODEOWNERS || fail 'CODEOWNERS must assign all files to @MKSEgr'

printf '%s\n' 'Checking authentication boundary...'
grep -Fq 'spring-boot-starter-security' backend/pom.xml || fail 'Spring Security starter is required'
grep -Fq 'spring-boot-starter-oauth2-resource-server' backend/pom.xml || fail 'OAuth2 resource server starter is required'
grep -Fq 'mode: ${AUTH_MODE:jwt}' backend/src/main/resources/application.yml || fail 'default authentication mode must fail closed as jwt'
grep -Fq 'demo-endpoints-enabled: ${DEMO_ENDPOINTS_ENABLED:false}' backend/src/main/resources/application.yml || fail 'demo endpoint must be disabled by default'
grep -Fq 'device-claim: ${OIDC_DEVICE_CLAIM:device_id}' backend/src/main/resources/application.yml || fail 'default device claim must be stable device_id'
grep -Fq 'account-deletion-max-authentication-age: ${ACCOUNT_DELETION_MAX_AUTH_AGE:PT5M}' backend/src/main/resources/application.yml || fail 'account deletion must require recent authentication'
grep -Fq 'private Mode mode = Mode.JWT;' backend/src/main/java/com/walkingrpg/backend/security/WalkingRpgSecurityProperties.java || fail 'security properties must fail closed as jwt'
grep -Fq 'private String deviceClaim = "device_id";' backend/src/main/java/com/walkingrpg/backend/security/WalkingRpgSecurityProperties.java || fail 'security properties must default to stable device_id'
grep -Eq '^[[:space:]]+mode: jwt$' backend/src/main/resources/application-prod.yml || fail 'production profile must use jwt mode'
grep -Eq '^[[:space:]]+demo-endpoints-enabled: false$' backend/src/main/resources/application-prod.yml || fail 'production profile must disable demo endpoints'
grep -Eq '^[[:space:]]+mode: dev-header$' backend/src/main/resources/application-local.yml || fail 'local profile must explicitly opt into dev-header mode'
grep -Fq 'matchIfMissing = false' backend/src/main/java/com/walkingrpg/backend/home/api/DemoHomeController.java || fail 'demo endpoint must be fail closed when the property is missing'
grep -Fq 'class SecurityModeGuard implements InitializingBean' backend/src/main/java/com/walkingrpg/backend/security/SecurityModeGuard.java || fail 'runtime security mode guard is required'
grep -Fq 'DEV_HEADER разрешён только в профилях local или test' backend/src/main/java/com/walkingrpg/backend/security/SecurityModeGuard.java || fail 'dev-header must be profile guarded at runtime'
grep -Fq 'SecurityModeGuardTest' .github/workflows/ci.yml || fail 'security mode guard tests must run in CI'

IDENTITY_HEADER_MATCHES=$(grep -RInE 'X-User-Id|X-Device-Id|X-Mock-User|X-Mock-Authorities' backend/src/main/java 2>/dev/null || true)
IDENTITY_HEADER_OUTSIDE_FILTER=$(printf '%s\n' "$IDENTITY_HEADER_MATCHES" | grep -v 'backend/src/main/java/com/walkingrpg/backend/security/DevHeaderAuthenticationFilter.java' || true)
if [ -n "$IDENTITY_HEADER_OUTSIDE_FILTER" ]; then
  printf '%s\n' "$IDENTITY_HEADER_OUTSIDE_FILTER" >&2
  fail 'identity headers are allowed only inside the explicit dev filter'
fi

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

printf '%s\n' 'Checking mobile authentication boundary...'
grep -Fq 'flutter_appauth: 12.0.2' mobile/pubspec.yaml || fail 'flutter_appauth must be pinned'
grep -Fq 'flutter_secure_storage: 10.3.1' mobile/pubspec.yaml || fail 'secure token storage must be pinned'
grep -Fq "defaultValue: 'oidc'" mobile/lib/core/config/app_environment.dart || fail 'mobile auth must fail closed as oidc'
grep -Fq 'Development-аутентификация запрещена в production build' mobile/lib/core/auth/auth_models.dart || fail 'release builds must reject development auth'
grep -Fq '"appAuthRedirectScheme" to "com.walkingrpg.app"' mobile/android/app/build.gradle.kts || fail 'Android AppAuth redirect scheme is missing'
grep -Fq 'android:allowBackup="false"' mobile/android/app/src/main/AndroidManifest.xml || fail 'Android secure storage backup must be disabled'
if grep -Fq 'android:taskAffinity=""' mobile/android/app/src/main/AndroidManifest.xml; then
  fail 'empty Android taskAffinity breaks AppAuth browser return'
fi
grep -Fq '<string>com.walkingrpg.app</string>' mobile/ios/Runner/Info.plist || fail 'iOS AppAuth redirect scheme is missing'
grep -Fq '<key>keychain-access-groups</key>' mobile/ios/Runner/Runner.entitlements || fail 'iOS Keychain capability is missing'
grep -Fq 'diskCapacity: 0' mobile/ios/Runner/AppDelegate.swift || fail 'iOS URL disk cache must be disabled for AppAuth token responses'
grep -Fq 'exact issuer identifier match' mobile/lib/core/auth/auth_models.dart || fail 'OIDC issuer matching must remain exact'
grep -Fq 'writeRefreshedSession' mobile/lib/core/auth/auth_session_store.dart || fail 'refresh persistence must not reactivate invalidated sessions'
grep -Fq "nativeOidcRedirectScheme = 'com.walkingrpg.app'" mobile/lib/core/config/app_environment.dart || fail 'Dart and native OIDC redirect schemes must stay aligned'
MOBILE_IDENTITY_HEADERS=$(grep -RInE 'X-User-Id|X-Device-Id|X-Mock-User|X-Mock-Authorities' mobile/lib/features --include='*.dart' 2>/dev/null || true)
MOBILE_IDENTITY_OUTSIDE_DEV=$(printf '%s\n' "$MOBILE_IDENTITY_HEADERS" | grep -v 'mobile/lib/features/home/data/auth_home_transports.dart' || true)
if [ -n "$MOBILE_IDENTITY_OUTSIDE_DEV" ]; then
  printf '%s\n' "$MOBILE_IDENTITY_OUTSIDE_DEV" >&2
  fail 'mobile identity headers are allowed only inside the explicit development transport'
fi

printf '%s\n' 'Checking tracked credentials and signing material...'
if find . -type f \( -name '*.jks' -o -name '*.keystore' -o -name '*.p12' -o -name '*.p8' -o -name '*.mobileprovision' -o -name 'key.properties' -o -name '.env' \) -not -path './.git/*' -print | grep -q .; then
  fail 'signing material or environment files must not be tracked'
fi
if grep -RIl --exclude-dir=.git --exclude='*.md' -E -- '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----' . | grep -q .; then
  fail 'private key material detected'
fi

printf '%s\n' 'Checking oversized source files...'
if find . -type f -size +5M -not -path './.git/*' -not -path './backend/target/*' -not -path './mobile/.dart_tool/*' -not -path './mobile/build/*' -print | grep -q .; then
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
