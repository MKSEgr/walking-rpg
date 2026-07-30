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
  docs/adr/0021-first-journey-observability.md \
  docs/adr/0022-durable-event-result-handoff.md \
  docs/adr/0025-production-provider-isolation.md \
  backend/.env.production.example \
  backend/src/main/java/com/walkingrpg/backend/operations/ProductionEnvironmentPostProcessor.java \
  backend/src/main/java/com/walkingrpg/backend/operations/ProductionRuntimeGuard.java \
  backend/src/main/java/com/walkingrpg/backend/platform/config/PlatformProviderProperties.java \
  backend/src/main/java/com/walkingrpg/backend/platform/payment/DisabledPaymentProvider.java \
  backend/src/main/java/com/walkingrpg/backend/platform/payment/SandboxPaymentProvider.java \
  backend/src/main/java/com/walkingrpg/backend/platform/push/DisabledPushDeliveryProvider.java \
  backend/src/main/java/com/walkingrpg/backend/platform/push/DevelopmentPushDeliveryProvider.java \
  backend/src/main/java/com/walkingrpg/backend/security/SecurityModeGuard.java \
  backend/src/main/resources/META-INF/spring.factories \
  mobile/lib/core/auth/auth_session_controller.dart \
  mobile/lib/features/home/data/auth_home_transports.dart \
  mobile/lib/features/platform/presentation/platform_screen.dart \
  backend/src/main/resources/application-local.yml \
  backend/src/main/resources/application-stage.yml \
  backend/src/main/resources/application-prod.yml \
  backend/src/main/resources/db/migration/V12__disable_development_providers.sql \
  backend/src/test/java/com/walkingrpg/backend/operations/ProductionRuntimeGuardTest.java \
  backend/src/test/java/com/walkingrpg/backend/platform/config/PlatformProviderConfigurationTest.java \
  backend/src/test/java/com/walkingrpg/backend/platform/application/PlatformAdminServiceProviderTest.java \
  backend/src/test/java/com/walkingrpg/backend/migration/ProductionProviderIsolationMigrationTest.java \
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
grep -Fq 'enabled: ${DURABLE_EVENT_RESULT_HANDOFF_ENABLED:false}' backend/src/main/resources/application.yml || fail 'durable event-result handoff must require explicit cluster activation'
grep -Fq 'private Mode mode = Mode.JWT;' backend/src/main/java/com/walkingrpg/backend/security/WalkingRpgSecurityProperties.java || fail 'security properties must fail closed as jwt'
grep -Fq 'private String deviceClaim = "device_id";' backend/src/main/java/com/walkingrpg/backend/security/WalkingRpgSecurityProperties.java || fail 'security properties must default to stable device_id'
grep -Eq '^[[:space:]]+mode: jwt$' backend/src/main/resources/application-stage.yml || fail 'stage profile must use jwt mode'
grep -Eq '^[[:space:]]+demo-endpoints-enabled: false$' backend/src/main/resources/application-stage.yml || fail 'stage profile must disable demo endpoints'
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

printf '%s\n' 'Checking protected runtime and provider isolation...'
grep -Fq 'payment: ${PAYMENT_PROVIDER:disabled}' backend/src/main/resources/application.yml || fail 'base payment provider must fail closed as disabled'
grep -Fq 'push: ${PUSH_PROVIDER:disabled}' backend/src/main/resources/application.yml || fail 'base push provider must fail closed as disabled'
grep -Fq 'SPRING_PROFILES_ACTIVE=prod' backend/.env.production.example || fail 'production environment example must select prod'
grep -Fq 'sslmode=verify-full' backend/.env.production.example || fail 'production environment example must require verified TLS'
grep -Fq 'WALKING_RPG_PROVIDERS_PAYMENT=disabled' backend/.env.production.example || fail 'production environment example must disable payment provider'
grep -Fq 'WALKING_RPG_PROVIDERS_PUSH=disabled' backend/.env.production.example || fail 'production environment example must disable push provider'
grep -Fq 'payment: ${PAYMENT_PROVIDER:sandbox}' backend/src/main/resources/application-local.yml || fail 'local profile must explicitly opt into sandbox payment'
grep -Fq 'push: ${PUSH_PROVIDER:development}' backend/src/main/resources/application-local.yml || fail 'local profile must explicitly opt into development push'
for profile in stage prod; do
  config="backend/src/main/resources/application-$profile.yml"
  grep -Eq '^[[:space:]]+payment: disabled$' "$config" || fail "$profile profile must disable payment provider"
  grep -Eq '^[[:space:]]+push: disabled$' "$config" || fail "$profile profile must disable push provider"
done
grep -Fq 'private String payment = "disabled";' backend/src/main/java/com/walkingrpg/backend/platform/config/PlatformProviderProperties.java || fail 'payment provider properties must fail closed'
grep -Fq 'private String push = "disabled";' backend/src/main/java/com/walkingrpg/backend/platform/config/PlatformProviderProperties.java || fail 'push provider properties must fail closed'
grep -Fq '@Profile({"local", "test"})' backend/src/main/java/com/walkingrpg/backend/platform/payment/SandboxPaymentProvider.java || fail 'sandbox payment must be profile guarded'
grep -Fq 'havingValue = "sandbox"' backend/src/main/java/com/walkingrpg/backend/platform/payment/SandboxPaymentProvider.java || fail 'sandbox payment must require explicit provider mode'
grep -Fq '@Profile({"local", "test"})' backend/src/main/java/com/walkingrpg/backend/platform/push/DevelopmentPushDeliveryProvider.java || fail 'development push must be profile guarded'
grep -Fq 'havingValue = "development"' backend/src/main/java/com/walkingrpg/backend/platform/push/DevelopmentPushDeliveryProvider.java || fail 'development push must require explicit provider mode'
grep -Fq 'havingValue = "disabled"' backend/src/main/java/com/walkingrpg/backend/platform/payment/DisabledPaymentProvider.java || fail 'disabled payment provider must be selectable'
grep -Fq 'matchIfMissing = true' backend/src/main/java/com/walkingrpg/backend/platform/payment/DisabledPaymentProvider.java || fail 'missing payment mode must fail closed'
grep -Fq 'havingValue = "disabled"' backend/src/main/java/com/walkingrpg/backend/platform/push/DisabledPushDeliveryProvider.java || fail 'disabled push provider must be selectable'
grep -Fq 'matchIfMissing = true' backend/src/main/java/com/walkingrpg/backend/platform/push/DisabledPushDeliveryProvider.java || fail 'missing push mode must fail closed'
grep -Fq 'PROTECTED_PROFILES = Set.of("prod", "stage")' backend/src/main/java/com/walkingrpg/backend/operations/ProductionRuntimeGuard.java || fail 'prod and stage must share the provider guard'
grep -Fq 'prod/stage обязаны отключать payment и push providers' backend/src/main/java/com/walkingrpg/backend/operations/ProductionRuntimeGuard.java || fail 'protected profiles must reject development providers at runtime'
grep -Fq 'ProductionEnvironmentPostProcessor' backend/src/main/resources/META-INF/spring.factories || fail 'datasource guard must run before application context creation'
grep -Fq 'ProductionRuntimeGuard.validateProtectedEnvironment(environment);' backend/src/main/java/com/walkingrpg/backend/operations/ProductionEnvironmentPostProcessor.java || fail 'environment post-processor must delegate to the canonical runtime guard'
grep -Fq 'POSTGRESQL_JDBC_PREFIX' backend/src/main/java/com/walkingrpg/backend/operations/ProductionRuntimeGuard.java || fail 'protected datasource must require PostgreSQL JDBC'
grep -Fq 'sslmode=verify-full' backend/src/main/java/com/walkingrpg/backend/operations/ProductionRuntimeGuard.java || fail 'protected datasource must require verified TLS'
grep -Fq 'канонический DNS host' backend/src/main/java/com/walkingrpg/backend/operations/ProductionRuntimeGuard.java || fail 'protected datasource must reject legacy numeric host aliases'
grep -Fq 'multi-host spring.datasource.url запрещён' backend/src/main/java/com/walkingrpg/backend/operations/ProductionRuntimeGuard.java || fail 'protected datasource must reject multi-host URL bypasses'
grep -Fq 'duplicate JDBC parameters запрещены' backend/src/main/java/com/walkingrpg/backend/operations/ProductionRuntimeGuard.java || fail 'protected datasource must reject duplicate JDBC parameters'
grep -Fq 'ALLOWED_JDBC_PARAMETERS = Set.of("sslmode")' backend/src/main/java/com/walkingrpg/backend/operations/ProductionRuntimeGuard.java || fail 'protected datasource URL must allow only canonical sslmode'
grep -Fq 'environment.getDefaultProfiles()' backend/src/main/java/com/walkingrpg/backend/operations/ProductionRuntimeGuard.java || fail 'protected runtime guard must honor the effective default profile'
grep -Fq '"spring.datasource.hikari.jdbc-url"' backend/src/main/java/com/walkingrpg/backend/operations/ProductionRuntimeGuard.java || fail 'protected datasource must reject alternate Hikari URL'
grep -Fq 'HIKARI_DATA_SOURCE_PROPERTIES_PREFIX' backend/src/main/java/com/walkingrpg/backend/operations/ProductionRuntimeGuard.java || fail 'protected datasource must reject Hikari driver property overrides'
grep -Fq 'HIKARI_CONNECTION_PROPERTY_SUFFIXES' backend/src/main/java/com/walkingrpg/backend/operations/ProductionRuntimeGuard.java || fail 'protected datasource must reject relaxed Hikari connection aliases'
grep -Fq 'HIKARI_CONFIGURATION_FILE_PROPERTY' backend/src/main/java/com/walkingrpg/backend/operations/ProductionRuntimeGuard.java || fail 'protected datasource must reject external Hikari configuration files'
grep -Fq '"spring.flyway.url"' backend/src/main/java/com/walkingrpg/backend/operations/ProductionRuntimeGuard.java || fail 'protected datasource must reject alternate Flyway connection settings'
grep -Fq 'FLYWAY_JDBC_PROPERTIES_PREFIX' backend/src/main/java/com/walkingrpg/backend/operations/ProductionRuntimeGuard.java || fail 'protected datasource must reject Flyway driver property overrides'
grep -Fq 'walking_rpg_local' backend/src/main/java/com/walkingrpg/backend/operations/ProductionRuntimeGuard.java || fail 'protected datasource must reject the local password'
grep -Fq 'requireProviderAvailability(commandType);' backend/src/main/java/com/walkingrpg/backend/platform/application/PlatformService.java || fail 'purchase availability must be checked before new state mutation'
grep -Fq 'withEffectiveRemoteConfig(readResponse(processed.responseJson()))' backend/src/main/java/com/walkingrpg/backend/platform/application/PlatformService.java || fail 'idempotent replay must re-project current provider capabilities'
grep -Fq 'paymentProvider.isAvailable()' backend/src/main/java/com/walkingrpg/backend/platform/application/PlatformService.java || fail 'effective sandbox capability must include provider availability'
grep -Fq 'config.put("backgroundHealthSyncEnabled", false);' backend/src/main/java/com/walkingrpg/backend/platform/application/PlatformService.java || fail 'background health must remain disabled'
grep -Fq 'sandboxPaymentsEnabled нельзя включить без payment provider' backend/src/main/java/com/walkingrpg/backend/platform/application/PlatformAdminService.java || fail 'admin config must not enable unavailable sandbox payment'
grep -Fq 'if (!pushDeliveryProvider.isAvailable())' backend/src/main/java/com/walkingrpg/backend/platform/application/PlatformAdminService.java || fail 'disabled push must be rejected before new state mutation'
grep -Fq 'this.sandboxPaymentsSupported = !kReleaseMode' mobile/lib/features/platform/presentation/platform_screen.dart || fail 'release mobile must disable sandbox payments'
grep -Fq '!snapshot.isCached' mobile/lib/features/platform/presentation/platform_screen.dart || fail 'cached platform snapshots must not expose sandbox purchase'
grep -Fq 'snapshot.remoteConfig.sandboxPaymentsEnabled' mobile/lib/features/platform/presentation/platform_screen.dart || fail 'mobile purchase UI must follow effective remote capability'
grep -Fq "'{sandboxPaymentsEnabled}'" backend/src/main/resources/db/migration/V12__disable_development_providers.sql || fail 'V12 must disable sandbox payments'
grep -Fq "'{backgroundHealthSyncEnabled}'" backend/src/main/resources/db/migration/V12__disable_development_providers.sql || fail 'V12 must disable background health'
V12_FALSE_VALUES=$(grep -Fc "'false'::jsonb" backend/src/main/resources/db/migration/V12__disable_development_providers.sql || true)
[ "$V12_FALSE_VALUES" -ge 2 ] || fail 'V12 development capability values must be false'
grep -Fq 'ProductionRuntimeGuardTest' .github/workflows/ci.yml || fail 'production runtime guard tests must run in CI'
grep -Fq 'PlatformProviderConfigurationTest' .github/workflows/ci.yml || fail 'provider configuration tests must run in CI'
grep -Fq 'PlatformAdminServiceProviderTest' .github/workflows/ci.yml || fail 'admin provider tests must run in CI'
grep -Fq 'ProductionProviderIsolationMigrationTest' .github/workflows/ci.yml || fail 'provider isolation migration test must run in CI'

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
if versions != expected or not versions or versions[-1] < 12:
    raise SystemExit(f'Flyway versions must be contiguous through at least V12: {versions}')
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
