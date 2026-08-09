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
  .github/workflows/release-pr-finalizer.yml \
  .github/workflows/release-quality.yml \
  docs/ROADMAP.md \
  docs/RELEASE_CHECKLIST.md \
  docs/EXTERNAL_GATES.md \
  docs/DIGITALOCEAN_STAGE_RUNBOOK.md \
  docs/PROTECTED_MOBILE_SIGNING.md \
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
  docs/adr/0026-production-operational-controls.md \
  docs/adr/0027-api-36-and-protected-mobile-signing.md \
  docs/adr/0028-internal-device-validation-center.md \
  docs/adr/0029-server-authoritative-crafting.md \
  docs/adr/0030-equipment-and-gated-routes.md \
  docs/adr/0031-compass-beta-funnel.md \
  docs/adr/0032-server-authoritative-cosmetic-slots.md \
  docs/adr/0033-canonical-platform-command-fingerprints.md \
  docs/adr/0035-auth0-alpha-authentication-contract.md \
  docs/adr/0036-digitalocean-alpha-stage.md \
  docs/adr/0037-telegram-login-through-auth0.md \
  docs/evidence/digitalocean-stage-deployment-template.md \
  docs/evidence/telegram-login-validation-template.md \
  infra/digitalocean/app.yaml.template \
  auth0/README.md \
  auth0/actions/step-beyond-token-contract.js \
  auth0/actions/step-beyond-token-contract.test.js \
  auth0/telegram/README.md \
  auth0/telegram/connection.template.json \
  auth0/telegram/telegram-oidc-connection.test.js \
  docs/PRODUCTION_OPERATIONS_RUNBOOK.md \
  docs/evidence/backup-restore-drill-template.md \
  .dockerignore \
  backend/Dockerfile \
  backend/docker-entrypoint.sh \
  backend/.env.production.example \
  backend/src/main/java/com/walkingrpg/backend/operations/BoundedDataSourceHealthIndicator.java \
  backend/src/main/java/com/walkingrpg/backend/operations/ProductionEnvironmentPostProcessor.java \
  backend/src/main/java/com/walkingrpg/backend/operations/JdbcStatementTimeouts.java \
  backend/src/main/java/com/walkingrpg/backend/operations/ProductionOperationsGuard.java \
  backend/src/main/java/com/walkingrpg/backend/operations/ProductionRuntimeGuard.java \
  backend/src/main/java/com/walkingrpg/backend/operations/ingress/PublicIngressProtectionFilter.java \
  backend/src/main/java/com/walkingrpg/backend/operations/ingress/PublicIngressRateLimiter.java \
  backend/src/main/java/com/walkingrpg/backend/platform/config/PlatformProviderProperties.java \
  backend/src/main/java/com/walkingrpg/backend/platform/payment/DisabledPaymentProvider.java \
  backend/src/main/java/com/walkingrpg/backend/platform/payment/SandboxPaymentProvider.java \
  backend/src/main/java/com/walkingrpg/backend/platform/push/DisabledPushDeliveryProvider.java \
  backend/src/main/java/com/walkingrpg/backend/platform/push/DevelopmentPushDeliveryProvider.java \
  backend/src/main/java/com/walkingrpg/backend/security/SecurityModeGuard.java \
  backend/src/main/resources/META-INF/spring.factories \
  mobile/lib/core/auth/auth_session_controller.dart \
  mobile/lib/core/auth/installation_id_store.dart \
  mobile/lib/features/home/data/auth_home_transports.dart \
  mobile/lib/features/platform/presentation/platform_screen.dart \
  mobile/lib/features/validation/application/validation_evidence_controller.dart \
  mobile/lib/features/validation/application/validation_evidence_exporter.dart \
  mobile/lib/features/validation/domain/device_validation_evidence.dart \
  mobile/lib/features/validation/validation_center_policy.dart \
  backend/src/main/resources/application-local.yml \
  backend/src/main/resources/application-stage.yml \
  backend/src/main/resources/application-prod.yml \
  backend/src/main/resources/db/migration/V12__disable_development_providers.sql \
  backend/src/main/resources/db/migration/V13__server_authoritative_crafting.sql \
  backend/src/main/resources/db/migration/V14__equipment_and_resonance_route.sql \
  backend/src/main/resources/db/migration/V15__immutable_content_activation_time.sql \
  backend/src/main/resources/db/migration/V16__platform_event_receipt_time_index.sql \
  backend/src/main/resources/db/migration/V17__server_authoritative_cosmetic_slots.sql \
  backend/src/test/java/com/walkingrpg/backend/operations/ProductionRuntimeGuardTest.java \
  backend/src/test/java/com/walkingrpg/backend/operations/ProductionOperationsGuardTest.java \
  backend/src/test/java/com/walkingrpg/backend/operations/BoundedDataSourceHealthIndicatorTest.java \
  backend/src/test/java/com/walkingrpg/backend/operations/OperationalEndpointsIntegrationTest.java \
  backend/src/test/java/com/walkingrpg/backend/operations/BackupRestoreDrillIntegrationTest.java \
  backend/src/test/java/com/walkingrpg/backend/operations/PostgresDrillManifest.java \
  backend/src/test/java/com/walkingrpg/backend/operations/PostgresDrillManifestTest.java \
  backend/src/test/java/com/walkingrpg/backend/platform/config/PlatformProviderConfigurationTest.java \
  backend/src/test/java/com/walkingrpg/backend/platform/application/PlatformAdminServiceProviderTest.java \
  backend/src/test/java/com/walkingrpg/backend/platform/analytics/CompassJourneyAnalyticsIntegrationTest.java \
  backend/src/test/java/com/walkingrpg/backend/migration/ProductionProviderIsolationMigrationTest.java \
  backend/src/test/java/com/walkingrpg/backend/migration/ServerAuthoritativeCraftingMigrationTest.java \
  backend/src/test/java/com/walkingrpg/backend/migration/EquipmentAndResonanceRouteMigrationTest.java \
  backend/src/test/java/com/walkingrpg/backend/migration/ContentReleaseActivationHistoryMigrationTest.java \
  backend/src/test/java/com/walkingrpg/backend/migration/CosmeticSlotStateMigrationTest.java \
  privacy/privacy-policy.md \
  scripts/generate-build-metadata.sh \
  scripts/ci/verify-android-release-config.sh \
  scripts/ci/verify_backend_test_selection.py \
  scripts/ci/wait_for_required_checks.py \
  scripts/ci/test_wait_for_required_checks.py \
  scripts/operations/run-synthetic-backup-restore-drill.sh \
  scripts/operations/render_digitalocean_stage_spec.py \
  scripts/operations/test_render_digitalocean_stage_spec.py \
  scripts/operations/test-backend-container-entrypoint.sh \
  scripts/operations/verify-backup-restore-evidence.py \
  scripts/operations/test_verify_backup_restore_evidence.py; do
  [ -f "$file" ] || fail "missing $file"
done

grep -Eq '^\* +@MKSEgr$' .github/CODEOWNERS || fail 'CODEOWNERS must assign all files to @MKSEgr'

printf '%s\n' 'Checking authentication boundary...'
grep -Fq 'spring-boot-starter-security' backend/pom.xml || fail 'Spring Security starter is required'
grep -Fq 'spring-boot-starter-oauth2-resource-server' backend/pom.xml || fail 'OAuth2 resource server starter is required'
grep -Fq 'mode: ${AUTH_MODE:jwt}' backend/src/main/resources/application.yml || fail 'default authentication mode must fail closed as jwt'
grep -Fq 'demo-endpoints-enabled: ${DEMO_ENDPOINTS_ENABLED:false}' backend/src/main/resources/application.yml || fail 'demo endpoint must be disabled by default'
grep -Fq 'device-claim: ${OIDC_DEVICE_CLAIM:device_id}' backend/src/main/resources/application.yml || fail 'default device claim must be stable device_id'
grep -Fq 'authentication-time-claim: ${OIDC_AUTHENTICATION_TIME_CLAIM:auth_time}' backend/src/main/resources/application.yml || fail 'authentication-time claim must be explicit and configurable'
grep -Fq 'account-deletion-max-authentication-age: ${ACCOUNT_DELETION_MAX_AUTH_AGE:PT5M}' backend/src/main/resources/application.yml || fail 'account deletion must require recent authentication'
grep -Fq 'shouldApplyClockSkewToExactFractionalAuthenticationTime' backend/src/test/java/com/walkingrpg/backend/security/SecurityContextRequestIdentityProviderTest.java || fail 'fractional auth_time regression must remain covered'
grep -Fq 'shouldRejectLossyFloatingPointAuthenticationTime' backend/src/test/java/com/walkingrpg/backend/security/SecurityContextRequestIdentityProviderTest.java || fail 'lossy auth_time regression must remain covered'
grep -Fq '.movePointRight(9)' backend/src/main/java/com/walkingrpg/backend/security/SecurityContextRequestIdentityProvider.java || fail 'auth_time must preserve exact nanosecond precision'
grep -Fq '.toBigIntegerExact();' backend/src/main/java/com/walkingrpg/backend/security/SecurityContextRequestIdentityProvider.java || fail 'auth_time must reject lossy numeric conversion'
grep -Fq 'Lossy floating-point auth_time' backend/src/main/java/com/walkingrpg/backend/security/SecurityContextRequestIdentityProvider.java || fail 'floating auth_time must fail closed'
grep -Fq 'shouldRejectIdentityClaimsThatWouldCollapseAfterNormalization' backend/src/test/java/com/walkingrpg/backend/security/SecurityContextRequestIdentityProviderTest.java || fail 'signed identity normalization regression must remain covered'
grep -Fq 'shouldRejectNonStringSubjectBeforeClaimCoercion' backend/src/test/java/com/walkingrpg/backend/security/SecurityContextRequestIdentityProviderTest.java || fail 'raw OIDC subject type regression must remain covered'
grep -Fq 'requiredExactStringClaim(' backend/src/main/java/com/walkingrpg/backend/security/SecurityContextRequestIdentityProvider.java || fail 'OIDC subject must be validated before Spring string coercion'
grep -Fq 'shouldRejectNonStringSubjectBeforePrincipalConversion' backend/src/test/java/com/walkingrpg/backend/security/JwtAuthorityConverterTest.java || fail 'JWT principal conversion must reject non-string subjects'
grep -Fq '.claim("sub", 42)' backend/src/test/java/com/walkingrpg/backend/security/JwtSecurityIntegrationTest.java || fail 'protected actuator must reject a numeric subject before authorization'
grep -Fq 'implements BeanPostProcessor' backend/src/main/java/com/walkingrpg/backend/security/ExactSubjectJwtDecoderBeanPostProcessor.java || fail 'auto-configured JWT decoder must be wrapped with raw subject validation'
grep -Fq 'JWSObject.parse(token).getPayload().toJSONObject()' backend/src/main/java/com/walkingrpg/backend/security/ExactSubjectJwtDecoderBeanPostProcessor.java || fail 'raw subject validation must inspect the compact payload before registered-claim conversion'
grep -Fq 'shouldRejectSignedNumericSubjectBeforeClaimSetConversion' backend/src/test/java/com/walkingrpg/backend/security/JwtSecurityIntegrationTest.java || fail 'signed decoder subject-type regression must remain covered'
grep -Fq '"Bearer " + signedAdminToken(42)' backend/src/test/java/com/walkingrpg/backend/security/JwtSecurityIntegrationTest.java || fail 'signed numeric subject must exercise the real decoder path'
if grep -Fq 'getSubject()' backend/src/main/java/com/walkingrpg/backend/security/SecurityContextRequestIdentityProvider.java backend/src/main/java/com/walkingrpg/backend/security/JwtAuthorityConverter.java; then
  fail 'identity boundary must not coerce the raw OIDC subject through getSubject()'
fi
grep -Fq 'shouldRejectPresentMalformedOptionalIdentityClaims' backend/src/test/java/com/walkingrpg/backend/security/SecurityContextRequestIdentityProviderTest.java || fail 'present malformed optional identity claims must remain fail-closed'
grep -Fq 'shouldReadAnExactNamespacedDeviceClaimBeforeNestedPaths' backend/src/test/java/com/walkingrpg/backend/security/SecurityContextRequestIdentityProviderTest.java || fail 'exact namespaced device claim regression must remain covered'
grep -Fq 'shouldReadConfiguredNamespacedAuthenticationTimeForDeletion' backend/src/test/java/com/walkingrpg/backend/security/SecurityContextRequestIdentityProviderTest.java || fail 'configured fresh-auth claim regression must remain covered'
grep -Fq 'if (!map.containsKey(part))' backend/src/main/java/com/walkingrpg/backend/security/SecurityContextRequestIdentityProvider.java || fail 'optional identity claim fallback must distinguish absent paths from malformed values'
grep -Fq 'shouldRejectMalformedIdentityClaimsFromProtectedPrometheus' backend/src/test/java/com/walkingrpg/backend/security/JwtSecurityIntegrationTest.java || fail 'protected actuator identity validation regression must remain covered'
grep -Fq 'identityProvider.requireValidatedIdentity();' backend/src/main/java/com/walkingrpg/backend/security/ActiveAccountFilter.java || fail 'actuator JWT claims must be validated without account lookup'
grep -Fq 'hasBoundaryWhitespace(value)' backend/src/main/java/com/walkingrpg/backend/security/SecurityContextRequestIdentityProvider.java || fail 'signed identity claims must reject boundary whitespace'
grep -Fq 'value.codePoints().anyMatch(Character::isISOControl)' backend/src/main/java/com/walkingrpg/backend/security/SecurityContextRequestIdentityProvider.java || fail 'signed identity claims must reject control characters'
grep -Fq 'enabled: ${DURABLE_EVENT_RESULT_HANDOFF_ENABLED:false}' backend/src/main/resources/application.yml || fail 'durable event-result handoff must require explicit cluster activation'
grep -Fq 'private Mode mode = Mode.JWT;' backend/src/main/java/com/walkingrpg/backend/security/WalkingRpgSecurityProperties.java || fail 'security properties must fail closed as jwt'
grep -Fq 'private String deviceClaim = "device_id";' backend/src/main/java/com/walkingrpg/backend/security/WalkingRpgSecurityProperties.java || fail 'security properties must default to stable device_id'
grep -Fq 'private String authenticationTimeClaim = "auth_time";' backend/src/main/java/com/walkingrpg/backend/security/WalkingRpgSecurityProperties.java || fail 'security properties must default to auth_time outside protected profiles'
grep -Eq '^[[:space:]]+mode: jwt$' backend/src/main/resources/application-stage.yml || fail 'stage profile must use jwt mode'
grep -Eq '^[[:space:]]+demo-endpoints-enabled: false$' backend/src/main/resources/application-stage.yml || fail 'stage profile must disable demo endpoints'
grep -Fq 'device-claim: ${OIDC_DEVICE_CLAIM}' backend/src/main/resources/application-stage.yml || fail 'stage profile must require an explicit device claim'
grep -Fq 'authentication-time-claim: ${OIDC_AUTHENTICATION_TIME_CLAIM}' backend/src/main/resources/application-stage.yml || fail 'stage profile must require an explicit authentication-time claim'
grep -Eq '^[[:space:]]+mode: jwt$' backend/src/main/resources/application-prod.yml || fail 'production profile must use jwt mode'
grep -Eq '^[[:space:]]+demo-endpoints-enabled: false$' backend/src/main/resources/application-prod.yml || fail 'production profile must disable demo endpoints'
grep -Fq 'device-claim: ${OIDC_DEVICE_CLAIM}' backend/src/main/resources/application-prod.yml || fail 'production profile must require an explicit device claim'
grep -Fq 'authentication-time-claim: ${OIDC_AUTHENTICATION_TIME_CLAIM}' backend/src/main/resources/application-prod.yml || fail 'production profile must require an explicit authentication-time claim'
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
grep -Fq 'requireProviderAvailability(commandType, remoteConfig);' backend/src/main/java/com/walkingrpg/backend/platform/application/PlatformService.java || fail 'purchase availability must use the frozen command config before new state mutation'
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

printf '%s\n' 'Checking DigitalOcean protected stage contract...'
for profile in stage prod; do
  config="backend/src/main/resources/application-$profile.yml"
  grep -Fq 'url: jdbc:postgresql://${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}?sslmode=verify-full' "$config" \
    || fail "$profile profile must compose one verified-TLS JDBC URL from runtime bindings"
  grep -Fq 'username: ${POSTGRES_USER}' "$config" \
    || fail "$profile profile must require a runtime PostgreSQL user"
  grep -Fq 'password: ${POSTGRES_PASSWORD}' "$config" \
    || fail "$profile profile must require a runtime PostgreSQL password"
done
grep -Fq 'FROM eclipse-temurin:21-jdk-jammy AS build' backend/Dockerfile || fail 'protected backend container must build with Java 21'
grep -Fq 'FROM eclipse-temurin:21-jre-jammy' backend/Dockerfile || fail 'protected backend container must use the Java 21 JRE runtime'
grep -Fq 'USER walkingrpg:walkingrpg' backend/Dockerfile || fail 'protected backend container must run as a non-root user'
grep -Fq 'ENTRYPOINT ["/usr/local/bin/walking-rpg-entrypoint"]' backend/Dockerfile || fail 'protected backend container must use the reviewed entrypoint'
grep -Fq -- '--tag walking-rpg-backend:release-candidate' .github/workflows/release-quality.yml || fail 'release quality must build the protected backend container'
grep -Fq -- '--build-arg "SOURCE_GIT_SHA=$(git -C .. rev-parse HEAD)"' .github/workflows/release-quality.yml || fail 'release container build must embed its exact source commit'
grep -Fq -- '--build-arg "SOURCE_GIT_TREE=$(git -C .. rev-parse '\''HEAD^{tree}'\'')"' .github/workflows/release-quality.yml || fail 'release container build must embed its exact source tree'
grep -Fq 'IMAGE_SOURCE_GIT_SHA=${SOURCE_GIT_SHA}' backend/Dockerfile || fail 'protected backend image must embed its source commit'
grep -Fq 'IMAGE_SOURCE_GIT_TREE=${SOURCE_GIT_TREE}' backend/Dockerfile || fail 'protected backend image must embed its source tree'
grep -Fq 'SPRING_PROFILES_ACTIVE must be exactly stage or prod' backend/docker-entrypoint.sh || fail 'container entrypoint must reject unprotected profiles'
grep -Fq 'container source Git SHA does not match the approved deployment SHA' backend/docker-entrypoint.sh || fail 'container entrypoint must bind runtime to the approved source commit'
grep -Fq 'container source Git tree does not match the approved deployment tree' backend/docker-entrypoint.sh || fail 'container entrypoint must bind runtime to the approved source tree'
grep -Fq 'POSTGRES_CA_CERT must contain a PEM certificate' backend/docker-entrypoint.sh || fail 'container entrypoint must reject a malformed database CA'
grep -Fq 'root.crt' backend/docker-entrypoint.sh || fail 'container entrypoint must install the pgJDBC default root certificate'
grep -Fq 'chmod 0600 "$temporary_certificate"' backend/docker-entrypoint.sh || fail 'container entrypoint must restrict database CA permissions'
grep -Fq 'unset POSTGRES_CA_CERT' backend/docker-entrypoint.sh || fail 'container entrypoint must remove the CA from the JVM environment'
[ -x backend/docker-entrypoint.sh ] || fail 'protected backend entrypoint must be executable'
[ -x scripts/operations/render_digitalocean_stage_spec.py ] || fail 'DigitalOcean App Spec renderer must be executable'
[ -x scripts/operations/test-backend-container-entrypoint.sh ] || fail 'container entrypoint test must be executable'
grep -Fq 'name: walking-rpg-alpha-eu' infra/digitalocean/app.yaml.template || fail 'stage App Spec must keep the accepted environment name'
grep -Fq 'region: fra' infra/digitalocean/app.yaml.template || fail 'stage App Spec must keep the accepted Frankfurt region'
grep -Fq 'instance_size_slug: apps-s-1vcpu-1gb' infra/digitalocean/app.yaml.template || fail 'stage backend must keep the accepted 1 GiB size'
grep -Fq 'registry_type: GHCR' infra/digitalocean/app.yaml.template || fail 'stage backend must use the reviewed container registry'
grep -Fq 'repository: walking-rpg-backend' infra/digitalocean/app.yaml.template || fail 'stage backend must use the fixed image repository'
grep -Fq 'digest: "@@BACKEND_IMAGE_DIGEST@@"' infra/digitalocean/app.yaml.template || fail 'stage backend must require an immutable image digest'
grep -Fq 'value: "@@BACKEND_SOURCE_GIT_SHA@@"' infra/digitalocean/app.yaml.template || fail 'stage backend must require the approved source commit'
grep -Fq 'value: "@@BACKEND_SOURCE_GIT_TREE@@"' infra/digitalocean/app.yaml.template || fail 'stage backend must require the approved source tree'
if grep -Eq 'github:|branch:|deploy_on_push:|^[[:space:]]+tag:' infra/digitalocean/app.yaml.template; then
  fail 'stage App Spec must not follow a moving source ref or image tag'
fi
grep -Fq 'enhanced_threat_control_enabled: true' infra/digitalocean/app.yaml.template || fail 'stage ingress must keep reviewed Layer 7 protection'
grep -Fq 'http_path: /readyz' infra/digitalocean/app.yaml.template || fail 'stage platform readiness must include PostgreSQL'
grep -Fq 'http_path: /livez' infra/digitalocean/app.yaml.template || fail 'stage platform liveness must remain independent of PostgreSQL'
grep -Fq 'value: ${alpha-db.PASSWORD}' infra/digitalocean/app.yaml.template || fail 'stage database password must use a bindable variable'
grep -Fq 'value: ${alpha-db.CA_CERT}' infra/digitalocean/app.yaml.template || fail 'stage database CA must use a bindable variable'
grep -Fq 'type: SECRET' infra/digitalocean/app.yaml.template || fail 'stage sensitive bindables must be encrypted at runtime'
grep -Fq 'version: "17"' infra/digitalocean/app.yaml.template || fail 'stage database must use PostgreSQL 17'
grep -Fq 'production: true' infra/digitalocean/app.yaml.template || fail 'stage must attach a managed database, not a dev database'
if grep -Eq 'doadmin|defaultdb|sslmode=require' infra/digitalocean/app.yaml.template; then
  fail 'stage App Spec must not use provider admin defaults or weakened TLS'
fi
grep -Fq 'name: Publish backend release candidate' .github/workflows/publish-backend-release-candidate.yml || fail 'repository must define the protected backend image publisher'
grep -Fq 'environment: stage-release' .github/workflows/publish-backend-release-candidate.yml || fail 'backend image publication must use the protected stage release environment'
grep -Fq 'actions: read' .github/workflows/publish-backend-release-candidate.yml || fail 'backend publisher must have scoped workflow read permission'
grep -Fq 'packages: write' .github/workflows/publish-backend-release-candidate.yml || fail 'backend publisher must have scoped package write permission'
grep -Fq 'git merge-base --is-ancestor "$SOURCE_GIT_SHA" origin/master' .github/workflows/publish-backend-release-candidate.yml || fail 'backend publisher must reject commits outside master history'
grep -Fq 'run.name === workflowName' .github/workflows/publish-backend-release-candidate.yml || fail 'backend publisher must require integrated push workflows'
grep -Fq 'git status --porcelain=v1 --untracked-files=all' .github/workflows/publish-backend-release-candidate.yml || fail 'backend publisher must reject a modified build context'
grep -Fq 'platforms: linux/amd64' .github/workflows/publish-backend-release-candidate.yml || fail 'backend publisher must target the App Platform architecture'
grep -Fq 'IMAGE_DIGEST" =~ ^sha256:' .github/workflows/publish-backend-release-candidate.yml || fail 'backend publisher must require an immutable OCI digest'
bash scripts/operations/test-backend-container-entrypoint.sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest \
  scripts/operations/test_render_digitalocean_stage_spec.py
STAGE_POSTGRES_CLUSTER_NAME=walking-rpg-alpha-pg-fra \
STAGE_BACKEND_IMAGE_DIGEST=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
STAGE_BACKEND_SOURCE_GIT_SHA=1111111111111111111111111111111111111111 \
STAGE_BACKEND_SOURCE_GIT_TREE=2222222222222222222222222222222222222222 \
STAGE_POSTGRES_DATABASE=walking_rpg \
STAGE_POSTGRES_USER=walking_rpg_app \
STAGE_OIDC_ISSUER_URI=https://walking-rpg-alpha.eu.auth0.com/ \
STAGE_OIDC_JWK_SET_URI=https://walking-rpg-alpha.eu.auth0.com/.well-known/jwks.json \
STAGE_OIDC_AUDIENCE=https://api.stepbeyond.game \
  python3 scripts/operations/render_digitalocean_stage_spec.py \
  | grep -Fq 'cluster_name: "walking-rpg-alpha-pg-fra"' \
  || fail 'DigitalOcean App Spec renderer must produce the reviewed stage binding'

grep -Fq 'quantity_delta <> 0' backend/src/main/resources/db/migration/V13__server_authoritative_crafting.sql || fail 'V13 inventory ledger must allow audited consumption but reject zero deltas'
grep -Fq 'quantity_after >= 0' backend/src/main/resources/db/migration/V13__server_authoritative_crafting.sql || fail 'V13 inventory ledger must reject negative balances'
grep -Fq 'CraftingIntegrationTest' .github/workflows/ci.yml || fail 'crafting integration test must run in CI'
grep -Fq 'ServerAuthoritativeCraftingMigrationTest' .github/workflows/ci.yml || fail 'crafting migration test must run in CI'
grep -Fq 'FOREIGN KEY (user_id, item_instance_id)' backend/src/main/resources/db/migration/V14__equipment_and_resonance_route.sql || fail 'V14 equipment state must enforce same-owner item references'
grep -Fq 'CREATE UNIQUE INDEX uq_equipment_item_single_slot' backend/src/main/resources/db/migration/V14__equipment_and_resonance_route.sql || fail 'V14 must prevent one item from occupying multiple slots'
grep -Fq 'EquipmentServiceTest' .github/workflows/ci.yml || fail 'equipment service tests must run in CI'
grep -Fq 'EquipmentControllerTest' .github/workflows/ci.yml || fail 'equipment API tests must run in CI'
grep -Fq 'EquipmentIntegrationTest' .github/workflows/ci.yml || fail 'equipment PostgreSQL tests must run in CI'
grep -Fq 'EquipmentAndResonanceRouteMigrationTest' .github/workflows/ci.yml || fail 'equipment migration test must run in CI'
grep -Fq 'activated_at is immutable after first activation' backend/src/main/resources/db/migration/V15__immutable_content_activation_time.sql || fail 'V15 must reject activation timestamp rewrites'
grep -Fq 'V15 requires explicit chapter-1-v2 first activation timestamp' backend/src/main/resources/db/migration/V15__immutable_content_activation_time.sql || fail 'V15 must fail closed when legacy v2 activation history is missing'
grep -Fq 'shouldRequireExplicitV14HistoryAndKeepFirstActivationImmutable' backend/src/test/java/com/walkingrpg/backend/migration/ContentReleaseActivationHistoryMigrationTest.java || fail 'V15 migration test must cover explicit legacy activation history'
grep -Fq 'ContentReleaseActivationHistoryMigrationTest' .github/workflows/ci.yml || fail 'content activation history migration test must run in CI'
grep -Fq 'CompassJourneyAnalyticsIntegrationTest' .github/workflows/ci.yml || fail 'compass journey analytics tests must run in CI'
grep -Fq 'ix_platform_event_user_received_at' backend/src/main/resources/db/migration/V16__platform_event_receipt_time_index.sql || fail 'V16 must add the receipt-time retention index'
grep -Fq 'ON platform_event (user_id, received_at)' backend/src/main/resources/db/migration/V16__platform_event_receipt_time_index.sql || fail 'V16 receipt-time index must support the retention user/range predicate'
grep -Fq 'assertReceiptTimeRetentionRangeUsesDedicatedIndex' backend/src/test/java/com/walkingrpg/backend/platform/infrastructure/PlatformPersistenceIntegrationTest.java || fail 'retention integration coverage must verify the V16 index plan'
grep -Fq 'WITH eligible_cohort AS (' backend/src/main/java/com/walkingrpg/backend/platform/application/PlatformAdminService.java || fail 'retention analytics must exclude cohorts whose target UTC day is incomplete'
grep -Fq 'result.put("generatedAt", generatedAt);' backend/src/main/java/com/walkingrpg/backend/platform/application/PlatformAdminService.java || fail 'retention analytics must expose its fixed observation boundary'
grep -Fq 'statement_timestamp() AS generated_at' backend/src/main/java/com/walkingrpg/backend/platform/application/PlatformAdminService.java || fail 'retention generatedAt must come from the first PostgreSQL snapshot statement'
grep -Fq 'statement_timestamp() AS generated_at' backend/src/main/java/com/walkingrpg/backend/platform/analytics/FirstJourneyAnalyticsService.java || fail 'first journey generatedAt must come from the first PostgreSQL snapshot statement'
grep -Fq 'statement_timestamp() AS generated_at' backend/src/main/java/com/walkingrpg/backend/platform/analytics/CompassJourneyAnalyticsService.java || fail 'compass journey generatedAt must come from the first PostgreSQL snapshot statement'
grep -Fq '"eligibleUsers", cohort.eligibleUsers()' backend/src/main/java/com/walkingrpg/backend/platform/application/PlatformAdminService.java || fail 'retention analytics must expose each fully observed denominator'
grep -Fq 'shouldExcludeIncompleteCohortsFromRetentionRates' backend/src/test/java/com/walkingrpg/backend/platform/infrastructure/PlatformPersistenceIntegrationTest.java || fail 'PostgreSQL retention coverage must exclude incomplete cohorts'
grep -Fq 'shouldAnchorRetentionGeneratedAtToDatabaseSnapshot' backend/src/test/java/com/walkingrpg/backend/platform/analytics/CompassJourneyAnalyticsIntegrationTest.java || fail 'PostgreSQL analytics coverage must reject application-clock retention boundaries'
grep -Fq 'firstStatementFinishedAt' backend/src/test/java/com/walkingrpg/backend/platform/analytics/FirstJourneyAnalyticsIntegrationTest.java || fail 'first journey concurrency coverage must pin generatedAt before later blocked reads'
grep -Fq 'firstStatementFinishedAt' backend/src/test/java/com/walkingrpg/backend/platform/analytics/CompassJourneyAnalyticsIntegrationTest.java || fail 'compass journey concurrency coverage must pin generatedAt before later blocked reads'
grep -Fq 'shouldReturnFullyObservedRetentionDenominators' backend/src/test/java/com/walkingrpg/backend/platform/api/PlatformAdminControllerTest.java || fail 'retention API coverage must expose fully observed denominators and generatedAt'
grep -Fq 'SELECT statement_timestamp()' backend/src/main/java/com/walkingrpg/backend/shared/time/PostgresDatabaseSnapshotClock.java || fail 'production read snapshots must observe PostgreSQL time in their first statement'
grep -Fq 'snapshotClock.observe()' backend/src/main/java/com/walkingrpg/backend/home/application/HomeService.java || fail 'Home serverTime must come from the PostgreSQL snapshot boundary'
PLATFORM_SNAPSHOT_CLOCK_READS=$(grep -Fc 'snapshotClock.observe()' backend/src/main/java/com/walkingrpg/backend/platform/application/PlatformService.java || true)
[ "$PLATFORM_SNAPSHOT_CLOCK_READS" -eq 2 ] || fail 'platform snapshot and bootstrap must share the PostgreSQL snapshot clock'
grep -Fq 'shouldAnchorHomeServerTimeToFirstDatabaseSnapshotStatement' backend/src/test/java/com/walkingrpg/backend/home/infrastructure/HomeReadIntegrationTest.java || fail 'Home PostgreSQL coverage must pin serverTime before later blocked reads'
grep -Fq 'duringConcurrentSync.serverTime()' backend/src/test/java/com/walkingrpg/backend/platform/infrastructure/PlatformPersistenceIntegrationTest.java || fail 'platform PostgreSQL coverage must pin serverTime before later blocked reads'
grep -Fq 'shouldAnchorContentBootstrapServerTimeToFirstDatabaseSnapshotStatement' backend/src/test/java/com/walkingrpg/backend/platform/infrastructure/PlatformPersistenceIntegrationTest.java || fail 'content bootstrap PostgreSQL coverage must pin serverTime before later blocked reads'
grep -Fq 'shouldUseDatabaseObservationTimeForSnapshotAndBootstrap' backend/src/test/java/com/walkingrpg/backend/platform/application/PlatformServiceTest.java || fail 'platform snapshot and bootstrap must use the injected database observation time'
grep -Fq 'Instant exportedAt = observeSnapshot(snapshotJdbcTemplate)' backend/src/main/java/com/walkingrpg/backend/platform/application/AccountExportSnapshotTransaction.java || fail 'account export must observe PostgreSQL time in its first snapshot statement'
grep -Fq '"SELECT statement_timestamp()"' backend/src/main/java/com/walkingrpg/backend/platform/application/AccountExportSnapshotTransaction.java || fail 'account export observation must use PostgreSQL statement time'
grep -Fq 'reader.read(snapshotJdbcTemplate, exportedAt)' backend/src/main/java/com/walkingrpg/backend/platform/application/AccountExportSnapshotTransaction.java || fail 'account export must carry its database observation time into the response reader'
grep -Fq 'export.put("exportedAt", exportedAt)' backend/src/main/java/com/walkingrpg/backend/platform/application/PlatformAdminService.java || fail 'account export response must expose its database snapshot boundary'
grep -Fq 'shouldUseDatabaseObservationTimeForAccountExport' backend/src/test/java/com/walkingrpg/backend/platform/application/PlatformAdminServiceTest.java || fail 'account export unit coverage must ignore the application clock'
grep -Fq 'shouldAnchorAccountExportToOneDatabaseSnapshot' backend/src/test/java/com/walkingrpg/backend/platform/application/AccountDeletionIntegrationTest.java || fail 'account export PostgreSQL coverage must pin data and exportedAt to one snapshot'
grep -Fq 'CREATE TABLE platform_cosmetic_slot_state' backend/src/main/resources/db/migration/V17__server_authoritative_cosmetic_slots.sql || fail 'V17 must persist cosmetic equipment independently by slot'
grep -Fq "CHECK (slot IN ('PILOT', 'PET', 'PROFILE'))" backend/src/main/resources/db/migration/V17__server_authoritative_cosmetic_slots.sql || fail 'V17 must keep cosmetic slots server-owned'
grep -Fq 'UNIQUE (user_id, cosmetic_id)' backend/src/main/resources/db/migration/V17__server_authoritative_cosmetic_slots.sql || fail 'V17 must not equip one cosmetic in multiple slots'
grep -Fq 'ON DELETE CASCADE' backend/src/main/resources/db/migration/V17__server_authoritative_cosmetic_slots.sql || fail 'V17 cosmetic state must follow account deletion'
grep -Fq 'equippedCosmetics' backend/src/main/java/com/walkingrpg/backend/platform/application/PlatformService.java || fail 'platform snapshot must expose additive cosmetic slots'
grep -Fq 'CosmeticSlotStateMigrationTest' .github/workflows/ci.yml || fail 'cosmetic slot migration test must run in CI'
grep -Fq 'canonicalize(payload == null ? Map.of() : payload)' backend/src/main/java/com/walkingrpg/backend/platform/application/PlatformCommandFingerprint.java || fail 'platform fingerprints must canonicalize nested payload objects'
grep -Fq 'payload = payload == null ? null : Map.copyOf(payload);' backend/src/main/java/com/walkingrpg/backend/platform/api/PlatformCommandRequest.java || fail 'platform commands must preserve missing payload for request validation'
grep -Fq 'shouldRejectMissingOrNullPayloadBeforeCommandReceipt' backend/src/test/java/com/walkingrpg/backend/platform/api/PlatformControllerTest.java || fail 'platform command API coverage must reject missing payload before service execution'
grep -Fq 'private static final Map<String, List<String>> COMMAND_PAYLOAD_FIELDS' backend/src/main/java/com/walkingrpg/backend/platform/application/PlatformService.java || fail 'platform commands must declare one exact payload schema per canonical command type'
grep -Fq 'if (!expectedFields.containsAll(payload.keySet()))' backend/src/main/java/com/walkingrpg/backend/platform/application/PlatformService.java || fail 'new platform commands must reject ignored payload fields before runtime mutation'
grep -Fq 'shouldRejectUnexpectedPayloadFieldsBeforeRuntimeOrState' backend/src/test/java/com/walkingrpg/backend/platform/application/PlatformServiceTest.java || fail 'platform command coverage must reject extra payload fields before runtime and state access'
grep -Fq 'shouldReplayHistoricalReceiptBeforeExactPayloadShapeValidation' backend/src/test/java/com/walkingrpg/backend/platform/application/PlatformServiceTest.java || fail 'platform command payload hardening must preserve exact historical receipt replay'
grep -Fq '@NotEmpty Map<String, Object> content' backend/src/main/java/com/walkingrpg/backend/platform/api/ContentReleaseRequest.java || fail 'content releases must require a non-empty content object'
grep -Fq 'content = content == null ? null : Map.copyOf(content);' backend/src/main/java/com/walkingrpg/backend/platform/api/ContentReleaseRequest.java || fail 'content releases must preserve missing content for request validation'
grep -Fq 'shouldRejectMissingNullOrEmptyContentReleaseBeforeService' backend/src/test/java/com/walkingrpg/backend/platform/api/PlatformAdminControllerTest.java || fail 'content release API coverage must reject missing content before service execution'
grep -Fq 'response.put("version", normalizedVersion);' backend/src/main/java/com/walkingrpg/backend/platform/application/PlatformAdminService.java || fail 'remote config publication response must use the stored canonical version'
grep -Fq '"contentVersion", normalizedVersion' backend/src/main/java/com/walkingrpg/backend/platform/application/PlatformAdminService.java || fail 'content publication response must use the stored canonical version'
grep -Fq 'publicationResponsesShouldUseCanonicalStoredVersions' backend/src/test/java/com/walkingrpg/backend/platform/application/PlatformAdminServiceProviderTest.java || fail 'publication response coverage must match canonical stored versions'
grep -Fq 'Map<String, Object> canonicalConfig = canonicalRemoteConfig(config);' backend/src/main/java/com/walkingrpg/backend/platform/application/PlatformAdminService.java || fail 'remote config publication must canonicalize one value object before locking and persistence'
grep -Fq 'writeJson(canonicalConfig)' backend/src/main/java/com/walkingrpg/backend/platform/application/PlatformAdminService.java || fail 'remote config persistence must use canonical values'
grep -Fq 'remoteConfigPublicationShouldUseCanonicalStoredValues' backend/src/test/java/com/walkingrpg/backend/platform/application/PlatformAdminServiceProviderTest.java || fail 'remote config unit coverage must preserve canonical publication values'
grep -Fq 'shouldPersistAndReadCanonicalRemoteConfigValues' backend/src/test/java/com/walkingrpg/backend/platform/infrastructure/PlatformPersistenceIntegrationTest.java || fail 'PostgreSQL coverage must match remote config publication, storage and public read values'
grep -Fq 'private static final ObjectWriter CANONICAL_WRITER' backend/src/main/java/com/walkingrpg/backend/platform/application/PlatformCommandFingerprint.java || fail 'platform fingerprints must use a dedicated immutable writer'
grep -Fq '.disable(SerializationFeature.INDENT_OUTPUT)' backend/src/main/java/com/walkingrpg/backend/platform/application/PlatformCommandFingerprint.java || fail 'platform fingerprint writer must ignore API indentation settings'
grep -Fq 'private static final ObjectWriter LEGACY_INDENTED_WRITER' backend/src/main/java/com/walkingrpg/backend/platform/application/PlatformCommandFingerprint.java || fail 'platform replay must recognize pre-stabilization indented hashes'
grep -Fq 'legacyApiMapper.writer()' backend/src/main/java/com/walkingrpg/backend/platform/application/PlatformCommandFingerprint.java || fail 'platform replay must retain the preceding API-mapper encoding as a bounded candidate'
grep -Fq 'legacySha256Candidates' backend/src/main/java/com/walkingrpg/backend/platform/application/PlatformCommandFingerprint.java || fail 'platform replay must retain bounded legacy fingerprint compatibility'
grep -Fq 'shouldCanonicalizeObjectKeysRecursively' backend/src/test/java/com/walkingrpg/backend/platform/application/PlatformCommandFingerprintTest.java || fail 'platform fingerprint unit regression is required'
grep -Fq 'shouldPreserveExistingDefaultCanonicalEncoding' backend/src/test/java/com/walkingrpg/backend/platform/application/PlatformCommandFingerprintTest.java || fail 'platform fingerprint byte compatibility regression is required'
grep -Fq 'shouldRecognizePreStabilizationIndentedApiMapperEncoding' backend/src/test/java/com/walkingrpg/backend/platform/application/PlatformCommandFingerprintTest.java || fail 'platform fingerprint unit coverage must retain indented API-mapper compatibility'
grep -Fq 'shouldReplayAfterApiMapperFormattingChanges' backend/src/test/java/com/walkingrpg/backend/platform/application/PlatformServiceTest.java || fail 'platform replay must survive API mapper formatting changes'
grep -Fq 'shouldReplayPreStabilizationIndentedFingerprintAfterCompactRestart' backend/src/test/java/com/walkingrpg/backend/platform/application/PlatformServiceTest.java || fail 'platform replay must retain pre-stabilization indented fingerprints'
grep -Fq 'shouldReplayPreStabilizationIndentedFingerprintAfterCompactRestart' backend/src/test/java/com/walkingrpg/backend/platform/infrastructure/PlatformPersistenceIntegrationTest.java || fail 'PostgreSQL replay must retain pre-stabilization indented fingerprints'
grep -Fq 'shouldReplayCanonicalPlatformPayloadAfterRestartAndKeyReordering' backend/src/test/java/com/walkingrpg/backend/platform/infrastructure/PlatformPersistenceIntegrationTest.java || fail 'platform canonical fingerprint persistence regression is required'
grep -Fq 'shouldIncludeRuntimeCatalogValuesInProjectionAndDigest' backend/src/test/java/com/walkingrpg/backend/platform/application/PlatformContentCatalogTest.java || fail 'platform catalog digest must cover effective runtime values'
grep -Fq 'shouldProjectOneEffectiveConfigIntoSnapshotAndBootstrapCatalogs' backend/src/test/java/com/walkingrpg/backend/platform/application/PlatformServiceTest.java || fail 'platform snapshot and bootstrap must share one effective runtime catalog projection'
grep -Fq 'shouldProjectPersistedRemoteConfigIntoEveryPlatformCatalog' backend/src/test/java/com/walkingrpg/backend/platform/infrastructure/PlatformPersistenceIntegrationTest.java || fail 'PostgreSQL platform catalogs must match persisted effective remote config'
grep -Fq 'shouldUseOneEffectiveRemoteConfigForWholeCommand' backend/src/test/java/com/walkingrpg/backend/platform/application/PlatformServiceTest.java || fail 'platform commands must freeze one effective remote config in service coverage'
grep -Fq 'shouldKeepInFlightCommandOnOneRemoteConfigPublication' backend/src/test/java/com/walkingrpg/backend/platform/infrastructure/PlatformPersistenceIntegrationTest.java || fail 'PostgreSQL platform commands must not mix concurrent remote-config publications'
grep -Fq 'shouldUseOneActiveContentVersionForWholeCommand' backend/src/test/java/com/walkingrpg/backend/platform/application/PlatformServiceTest.java || fail 'platform commands must freeze one active content version in service coverage'
grep -Fq 'shouldKeepInFlightCommandOnOneContentPublication' backend/src/test/java/com/walkingrpg/backend/platform/infrastructure/PlatformPersistenceIntegrationTest.java || fail 'PostgreSQL platform commands must not mix concurrent content publications'
grep -Fq 'shouldTimestampCommandAfterFrozenContentPublication' backend/src/test/java/com/walkingrpg/backend/platform/application/PlatformServiceTest.java || fail 'platform command timestamps must follow frozen content publication in service coverage'
grep -Fq 'shouldTimestampCommandAfterContentPublicationWhileWaitingForUserLock' backend/src/test/java/com/walkingrpg/backend/platform/infrastructure/PlatformPersistenceIntegrationTest.java || fail 'PostgreSQL platform command timestamps must not predate an observed content publication'
grep -Fq 'shouldNotExpandReplayProviderCapabilityAfterEnable' backend/src/test/java/com/walkingrpg/backend/platform/application/PlatformServiceTest.java || fail 'platform command replay capability projection must remain monotonic fail-closed in service coverage'
grep -Fq 'shouldNotExpandPersistedReplayProviderCapabilityAfterEnable' backend/src/test/java/com/walkingrpg/backend/platform/infrastructure/PlatformPersistenceIntegrationTest.java || fail 'PostgreSQL platform replay must not expand a persisted provider capability'

printf '%s\n' 'Checking production operational controls...'
grep -Fq 'micrometer-registry-prometheus' backend/pom.xml || fail 'Prometheus registry is required'
grep -Fq 'ProductionOperationsGuard.validateProtectedEnvironment(environment);' backend/src/main/java/com/walkingrpg/backend/operations/ProductionEnvironmentPostProcessor.java || fail 'operations guard must run before application context creation'
grep -Fq 'management.server.port обязан отличаться от server.port' backend/src/main/java/com/walkingrpg/backend/operations/ProductionOperationsGuard.java || fail 'protected management port isolation is required'
grep -Fq 'management.server.ssl.enabled' backend/src/main/java/com/walkingrpg/backend/operations/ProductionOperationsGuard.java || fail 'management scrape scheme must remain loopback HTTP'
grep -Fq 'server.servlet.context-parameters' backend/src/main/java/com/walkingrpg/backend/operations/ProductionOperationsGuard.java || fail 'late servlet-context property overrides must be forbidden'
grep -Fq 'spring.autoconfigure.exclude' backend/src/main/java/com/walkingrpg/backend/operations/ProductionOperationsGuard.java || fail 'protected auto-configuration must not be removed'
grep -Fq 'spring.boot.enableautoconfiguration' backend/src/main/java/com/walkingrpg/backend/operations/ProductionOperationsGuard.java || fail 'protected auto-configuration must remain globally enabled'
grep -Fq 'spring.main.lazy-initialization' backend/src/main/java/com/walkingrpg/backend/operations/ProductionOperationsGuard.java || fail 'protected security/config guards must initialize eagerly'
grep -Fq 'spring.main.web-application-type' backend/src/main/java/com/walkingrpg/backend/operations/ProductionOperationsGuard.java || fail 'protected runtime must remain a servlet application'
grep -Fq 'spring.main.register-shutdown-hook' backend/src/main/java/com/walkingrpg/backend/operations/ProductionOperationsGuard.java || fail 'graceful shutdown must remain connected to JVM termination'
grep -Fq 'server.servlet.context-path' backend/src/main/java/com/walkingrpg/backend/operations/ProductionOperationsGuard.java || fail 'main-server probe paths must stay at the canonical root'
grep -Fq 'spring.mvc.servlet.path' backend/src/main/java/com/walkingrpg/backend/operations/ProductionOperationsGuard.java || fail 'MVC routing must stay at the canonical root'
grep -Fq 'path-pattern-parser' backend/src/main/java/com/walkingrpg/backend/operations/ProductionOperationsGuard.java || fail 'ingress protection and MVC must use identical path semantics'
grep -Fq 'spring.security.filter.dispatcher-types' backend/src/main/java/com/walkingrpg/backend/operations/ProductionOperationsGuard.java || fail 'REQUEST dispatches must always traverse the security filter chain'
grep -Fq 'walking-rpg.operations.public-ingress.telemetry.' backend/src/main/java/com/walkingrpg/backend/operations/ProductionOperationsGuard.java || fail 'protected ingress ceilings are required'
grep -Fq 'add-additional-paths: true' backend/src/main/resources/application.yml || fail 'main-port liveness/readiness aliases are required'
grep -Fq 'time-to-live: 0ms' backend/src/main/resources/application.yml || fail 'health responses must not mask readiness changes through caching'
grep -Fq 'order: down,out-of-service,unknown,up' backend/src/main/resources/application.yml || fail 'health aggregation order must be explicit and fail closed'
grep -Fq 'unknown: 503' backend/src/main/resources/application.yml || fail 'UNKNOWN readiness must remove the instance from traffic'
grep -Fq 'forward-headers-strategy: none' backend/src/main/resources/application.yml || fail 'untrusted forwarded client identity must remain disabled'
grep -Fq 'requireBoolean(environment, "spring.jmx.enabled", false);' backend/src/main/java/com/walkingrpg/backend/operations/ProductionOperationsGuard.java || fail 'protected JMX endpoint export must remain disabled'
grep -Fq 'spring.application.admin.enabled' backend/src/main/java/com/walkingrpg/backend/operations/ProductionOperationsGuard.java || fail 'SpringApplicationAdminMXBean must remain disabled'
grep -Fq 'server.tomcat.mbeanregistry.enabled' backend/src/main/java/com/walkingrpg/backend/operations/ProductionOperationsGuard.java || fail 'Tomcat MBean registry must remain disabled'
grep -Fq 'spring.datasource.hikari.register-mbeans' backend/src/main/java/com/walkingrpg/backend/operations/ProductionOperationsGuard.java || fail 'Hikari management MBeans must remain disabled'
grep -Fq 'jmx:' backend/src/main/resources/application.yml || fail 'canonical configuration must declare the JMX policy'
grep -Fq 'spring.application.name' backend/src/main/java/com/walkingrpg/backend/operations/ProductionOperationsGuard.java || fail 'application metric identity must remain guarded'
grep -Fq 'management.metrics.tags' backend/src/main/java/com/walkingrpg/backend/operations/ProductionOperationsGuard.java || fail 'unreviewed metric common tags must be rejected'
grep -Fq 'management.metrics.enable' backend/src/main/java/com/walkingrpg/backend/operations/ProductionOperationsGuard.java || fail 'meter deny filters must not disable required operational metrics'
grep -Fq 'management.metrics.observations.ignored-meters' backend/src/main/java/com/walkingrpg/backend/operations/ProductionOperationsGuard.java || fail 'observation-backed meters must not be silently ignored'
grep -Fq 'management.metrics.web.server.max-uri-tags' backend/src/main/java/com/walkingrpg/backend/operations/ProductionOperationsGuard.java || fail 'HTTP metric route cardinality must stay bounded'
grep -Fq 'management.observations.key-values' backend/src/main/java/com/walkingrpg/backend/operations/ProductionOperationsGuard.java || fail 'unreviewed observation common tags must be rejected'
grep -Fq 'management.observations.enable' backend/src/main/java/com/walkingrpg/backend/operations/ProductionOperationsGuard.java || fail 'observation deny filters must not disable required HTTP metrics'
grep -Fq 'management.observations.http.server.requests.name' backend/src/main/java/com/walkingrpg/backend/operations/ProductionOperationsGuard.java || fail 'the required HTTP server metric name must remain stable'
grep -Fq 'management.prometheus.metrics.export.pushgateway' backend/src/main/java/com/walkingrpg/backend/operations/ProductionOperationsGuard.java || fail 'Prometheus must remain pull-only in protected profiles'
grep -Fq 'include: health,prometheus' backend/src/main/resources/application.yml || fail 'only health and Prometheus may be exposed through Actuator'
grep -Fq '"/livez"' backend/src/main/java/com/walkingrpg/backend/security/SecurityConfiguration.java || fail 'liveness alias must be public'
grep -Fq '"/readyz"' backend/src/main/java/com/walkingrpg/backend/security/SecurityConfiguration.java || fail 'readiness alias must be public'
grep -Fq '"/actuator/prometheus"' backend/src/main/java/com/walkingrpg/backend/security/SecurityConfiguration.java || fail 'Prometheus must have an explicit authorization rule'
grep -Fq ').hasRole("ADMIN");' backend/src/main/java/com/walkingrpg/backend/security/SecurityConfiguration.java || fail 'Prometheus must require admin authority'
for profile in stage prod; do
  config="backend/src/main/resources/application-$profile.yml"
  grep -Fq 'port: ${MANAGEMENT_PORT:8081}' "$config" || fail "$profile management port must be separate"
  grep -Fq 'address: ${MANAGEMENT_ADDRESS:127.0.0.1}' "$config" || fail "$profile management address must default to loopback"
done
grep -Fq 'registration.addUrlPatterns("/*");' backend/src/main/java/com/walkingrpg/backend/operations/ingress/PublicIngressConfiguration.java || fail 'ingress protection must inspect encoded and matrix path variants'
grep -Fq 'ServletRequestPathUtils.parseAndCache(request)' backend/src/main/java/com/walkingrpg/backend/operations/ingress/PublicIngressProtectionFilter.java || fail 'ingress protection must use the same parsed path semantics as Spring MVC'
grep -Fq 'ServletRequestPathUtils.parseAndCache(request)' backend/src/main/java/com/walkingrpg/backend/security/ActiveAccountFilter.java || fail 'operational endpoints must remain independent from account storage for MVC-equivalent paths'
grep -Fq 'readNBytes(maxBodyBytes + 1)' backend/src/main/java/com/walkingrpg/backend/operations/ingress/PublicIngressProtectionFilter.java || fail 'chunked ingress bodies must be bounded'
grep -Fq '"PAYLOAD_TOO_LARGE"' backend/src/main/java/com/walkingrpg/backend/operations/ingress/PublicIngressProtectionFilter.java || fail 'oversized ingress must return the stable API code'
grep -Fq '"RATE_LIMITED"' backend/src/main/java/com/walkingrpg/backend/operations/ingress/PublicIngressProtectionFilter.java || fail 'rate-limited ingress must return the stable API code'
grep -Fq 'overflowClient' backend/src/main/java/com/walkingrpg/backend/operations/ingress/PublicIngressRateLimiter.java || fail 'client limiter state must remain bounded'
grep -Fq '@Size(max = 160) String errorType' backend/src/main/java/com/walkingrpg/backend/platform/api/CrashReportRequest.java || fail 'crash error type must fit the database schema'
grep -Fq '@Size(max = 32768) String stackTrace' backend/src/main/java/com/walkingrpg/backend/platform/api/CrashReportRequest.java || fail 'crash stack trace must be bounded'
grep -Fq '@Size(max = 64) Map<String, Object> attributes' backend/src/main/java/com/walkingrpg/backend/platform/api/TelemetryEventRequest.java || fail 'telemetry attributes must be bounded'
grep -Fq 'SERVER_RESERVED_EVENT_NAMES' backend/src/main/java/com/walkingrpg/backend/platform/application/PlatformAdminService.java || fail 'public telemetry must preserve server-owned event namespaces'
grep -Fq '@Component("dbHealthContributor")' backend/src/main/java/com/walkingrpg/backend/operations/BoundedDataSourceHealthIndicator.java || fail 'bounded database readiness must keep the canonical db contributor id'
grep -Fq 'connection.isValid(VALIDATION_TIMEOUT_SECONDS)' backend/src/main/java/com/walkingrpg/backend/operations/BoundedDataSourceHealthIndicator.java || fail 'database readiness validation must use a non-zero bounded timeout'
MANUAL_TIMEOUTS=$(grep -RFo 'JdbcStatementTimeouts.apply(jdbcTemplate, statement);' backend/src/main/java | wc -l | tr -d ' ')
[ "$MANUAL_TIMEOUTS" -eq 10 ] || fail 'all ten manual advisory-lock statements must inherit the JDBC timeout'
grep -Fq 'platform-publication-serialization' backend/src/main/java/com/walkingrpg/backend/platform/infrastructure/PlatformPublicationTransactionLock.java || fail 'platform publications must keep their dedicated transaction-lock boundary'
grep -Fq 'shouldSerializeConcurrentRemoteConfigPublications' backend/src/test/java/com/walkingrpg/backend/platform/infrastructure/PlatformPersistenceIntegrationTest.java || fail 'PostgreSQL coverage must preserve remote-config publication serialization'
grep -Fq 'shouldSerializeConcurrentContentPublications' backend/src/test/java/com/walkingrpg/backend/platform/infrastructure/PlatformPersistenceIntegrationTest.java || fail 'PostgreSQL coverage must preserve content publication serialization'
grep -Fq 'String commandType = canonicalCommandType(requestedCommandType);' backend/src/main/java/com/walkingrpg/backend/platform/application/PlatformService.java || fail 'cosmetic purchase aliases must share one canonical command scope'
grep -Fq 'saveProcessedWithCompatibilityAliases' backend/src/main/java/com/walkingrpg/backend/platform/application/PlatformService.java || fail 'cosmetic purchases must persist canonical and legacy replay scopes atomically'
grep -Fq 'shouldPersistOnePurchaseAcrossLegacyAndCanonicalCommandAliases' backend/src/test/java/com/walkingrpg/backend/platform/infrastructure/PlatformPersistenceIntegrationTest.java || fail 'PostgreSQL coverage must preserve cross-alias purchase idempotency'
grep -Fq 'shouldRollbackFractionalPlatformCommandBeforePersistingState' backend/src/test/java/com/walkingrpg/backend/platform/infrastructure/PlatformPersistenceIntegrationTest.java || fail 'PostgreSQL coverage must reject fractional platform numbers without partial state'
grep -Fq 'fractionalRemoteConfigNumbersShouldBeRejectedBeforeAnyWrite' backend/src/test/java/com/walkingrpg/backend/platform/application/PlatformAdminServiceProviderTest.java || fail 'remote config must reject fractional integer fields before publication'
grep -Fq 'shouldCanonicalizeProtocolTokensIndependentlyOfJvmLocale' backend/src/test/java/com/walkingrpg/backend/platform/infrastructure/PlatformPersistenceIntegrationTest.java || fail 'platform protocol tokens must remain locale-stable'
if grep -RInF '.toUpperCase()' backend/src/main/java/com/walkingrpg/backend/platform/application; then
  fail 'platform protocol tokens must not use JVM default-locale uppercase'
fi
grep -Fq 'squad-membership-serialization' backend/src/main/java/com/walkingrpg/backend/platform/infrastructure/SquadTransactionLock.java || fail 'squad membership mutations must keep their dedicated transaction-lock boundary'
grep -Fq 'shouldSerializeOwnerDeletionWithLastMemberLeave' backend/src/test/java/com/walkingrpg/backend/platform/infrastructure/PlatformPersistenceIntegrationTest.java || fail 'PostgreSQL coverage must preserve squad deletion/leave serialization'
grep -Fq 'SELECT pg_advisory_lock(hashtextextended(?, 97))' backend/src/main/java/com/walkingrpg/backend/account/application/AccountDeletionRegistry.java || fail 'account export must acquire the deletion boundary before opening its snapshot transaction'
grep -Fq 'Connection.TRANSACTION_REPEATABLE_READ' backend/src/main/java/com/walkingrpg/backend/platform/application/AccountExportSnapshotTransaction.java || fail 'account export must retain one repeatable-read snapshot'
grep -Fq 'SingleConnectionDataSource(connection, true)' backend/src/main/java/com/walkingrpg/backend/platform/application/AccountExportSnapshotTransaction.java || fail 'account export snapshot reads must stay on the already locked connection'
grep -Fq 'connection.abort(Runnable::run)' backend/src/main/java/com/walkingrpg/backend/platform/application/AccountExportSnapshotTransaction.java || fail 'failed account export lock cleanup must evict the unsafe connection'
grep -Fq 'accountExportSnapshotTransaction.read(' backend/src/main/java/com/walkingrpg/backend/platform/application/PlatformAdminService.java || fail 'account export must delegate to the single-connection snapshot boundary'
if grep -Fq 'PROPAGATION_REQUIRES_NEW' backend/src/main/java/com/walkingrpg/backend/platform/application/PlatformAdminService.java backend/src/main/java/com/walkingrpg/backend/platform/application/AccountExportSnapshotTransaction.java; then
  fail 'account export must not reserve a nested transaction connection'
fi
grep -Fq 'shouldExportWithOneConnectionAndReleaseSessionLock' backend/src/test/java/com/walkingrpg/backend/platform/application/AccountDeletionIntegrationTest.java || fail 'PostgreSQL coverage must keep account export safe with a one-connection pool'
grep -Fq 'shouldSerializeAccountExportWithDeletionForSameSubject' backend/src/test/java/com/walkingrpg/backend/platform/application/AccountDeletionIntegrationTest.java || fail 'PostgreSQL coverage must serialize account export with deletion'
grep -Fq 'shouldRejectExportAfterWaitingForConcurrentDeletion' backend/src/test/java/com/walkingrpg/backend/platform/application/AccountDeletionIntegrationTest.java || fail 'PostgreSQL coverage must reject export after a concurrent deletion commit'
grep -Fq 'shouldTimestampSquadCommandAfterSquadLock' backend/src/test/java/com/walkingrpg/backend/platform/application/PlatformServiceTest.java || fail 'platform squad service coverage must order timestamps after squad serialization'
grep -Fq 'shouldTimestampSquadJoinAfterWaitingForSquadLock' backend/src/test/java/com/walkingrpg/backend/platform/application/AccountDeletionIntegrationTest.java || fail 'PostgreSQL squad timestamps must follow the production squad lock'
grep -Fq 'validateCommandPayloadBeforeState(commandType, request.payload());' backend/src/main/java/com/walkingrpg/backend/platform/application/PlatformService.java || fail 'JOIN_SQUAD payload validation must run before platform state creation'
grep -Fq 'shouldRejectMalformedSquadIdsBeforePersistentState' backend/src/test/java/com/walkingrpg/backend/platform/infrastructure/PlatformPersistenceIntegrationTest.java || fail 'PostgreSQL coverage must reject malformed squad UUIDs before persistent state'
grep -Fq 'riskRecorder.record(command, currentState, result, serverTime);' backend/src/main/java/com/walkingrpg/backend/activity/application/ActivitySyncService.java || fail 'activity attestation risk assessment must run for every request before replay'
grep -Fq 'shouldAuditChangedAttestationOnReplayWithoutChangingBusinessState' backend/src/test/java/com/walkingrpg/backend/activity/infrastructure/ActivitySyncPersistenceIntegrationTest.java || fail 'PostgreSQL coverage must preserve request-scoped attestation assessment on exact replay'
grep -Fq 'shouldTimestampSynchronizationAfterUserLock' backend/src/test/java/com/walkingrpg/backend/activity/application/ActivitySyncServiceTest.java || fail 'activity sync service coverage must order timestamps after user serialization'
grep -Fq 'shouldTimestampSynchronizationAfterWaitingForUserLock' backend/src/test/java/com/walkingrpg/backend/activity/infrastructure/ActivitySyncPersistenceIntegrationTest.java || fail 'PostgreSQL activity sync timestamps must follow the production user lock'
grep -Fq 'return "v2:" + requestFingerprint;' backend/src/main/java/com/walkingrpg/backend/activity/application/ActivitySyncService.java || fail 'activity ledger sources must isolate operation generations after receipt retention'
grep -Fq 'shouldKeepWalletConsistentWhenRetainedKeyIsReusedAfterReceiptCleanup' backend/src/test/java/com/walkingrpg/backend/activity/application/ActivitySyncServiceTest.java || fail 'activity service coverage must preserve wallet consistency after receipt retention'
grep -Fq 'shouldKeepLedgerGenerationDistinctAfterReceiptRetention' backend/src/test/java/com/walkingrpg/backend/activity/infrastructure/ActivitySyncPersistenceIntegrationTest.java || fail 'PostgreSQL activity ledger generations must remain distinct after receipt retention'
grep -Fq '@NotNull @PositiveOrZero Long authoritativeTotal' backend/src/main/java/com/walkingrpg/backend/activity/api/ActivitySyncRequest.java || fail 'activity total must distinguish explicit zero from missing/null JSON'
grep -Fq '@NotNull @PositiveOrZero Long steps' backend/src/main/java/com/walkingrpg/backend/activity/api/ActivityBucketRequest.java || fail 'activity bucket steps must distinguish explicit zero from missing/null JSON'
grep -Fq '@NotNull @Positive Long energyToSpend' backend/src/main/java/com/walkingrpg/backend/expedition/api/ExpeditionAdvanceRequest.java || fail 'expedition energy must preserve missing/null validation before exact conversion'
EXACT_JSON_LONG_FIELDS=$(grep -Fh '@JsonDeserialize(using = ExactJsonLongDeserializer.class)' \
  backend/src/main/java/com/walkingrpg/backend/activity/api/ActivitySyncRequest.java \
  backend/src/main/java/com/walkingrpg/backend/activity/api/ActivityBucketRequest.java \
  backend/src/main/java/com/walkingrpg/backend/expedition/api/ExpeditionAdvanceRequest.java | wc -l | tr -d ' ')
[ "$EXACT_JSON_LONG_FIELDS" -eq 3 ] || fail 'all three typed API integer fields must use the exact JSON long boundary'
grep -Fq 'parser.getDecimalValue().longValueExact()' backend/src/main/java/com/walkingrpg/backend/shared/validation/ExactJsonLongDeserializer.java || fail 'exact JSON long conversion must reject fractions and overflow without truncation'
grep -Fq 'shouldRejectMissingOrNullAuthoritativeTotalBeforeCreatingReceipt' backend/src/test/java/com/walkingrpg/backend/activity/api/ActivitySyncControllerTest.java || fail 'activity API coverage must reject missing/null authoritative totals'
grep -Fq 'shouldRejectMissingOrNullBucketStepsBeforeCreatingReceipt' backend/src/test/java/com/walkingrpg/backend/activity/api/ActivitySyncControllerTest.java || fail 'activity API coverage must reject missing/null bucket steps'
grep -Fq 'shouldKeepExplicitZeroActivityNumbersValid' backend/src/test/java/com/walkingrpg/backend/activity/api/ActivitySyncControllerTest.java || fail 'activity API coverage must preserve explicit zero values'
grep -Fq 'shouldRequireExactIntegerActivityJsonNumbersBeforeCreatingReceipt' backend/src/test/java/com/walkingrpg/backend/activity/api/ActivitySyncControllerTest.java || fail 'activity API coverage must reject coerced, fractional and overflowing integers before receipts'
grep -Fq 'shouldRequireExactIntegerEnergyBeforeCreatingReceipt' backend/src/test/java/com/walkingrpg/backend/expedition/api/ExpeditionAdvanceControllerTest.java || fail 'expedition API coverage must reject coerced, fractional and overflowing energy before debit'
grep -Fq 'shouldTimestampAdvanceAfterExpeditionLock' backend/src/test/java/com/walkingrpg/backend/expedition/application/ExpeditionAdvanceServiceTest.java || fail 'expedition advance service coverage must order timestamps after expedition serialization'
grep -Fq 'shouldTimestampAdvanceAfterWaitingForExpeditionLock' backend/src/test/java/com/walkingrpg/backend/expedition/infrastructure/ExpeditionAdvanceIntegrationTest.java || fail 'PostgreSQL expedition advance timestamps must follow the production expedition lock'
grep -Fq 'shouldTimestampResolutionAfterExpeditionLock' backend/src/test/java/com/walkingrpg/backend/expedition/application/EventResolutionServiceTest.java || fail 'event resolution service coverage must order timestamps after expedition serialization'
grep -Fq 'shouldTimestampResolutionAfterWaitingForExpeditionLock' backend/src/test/java/com/walkingrpg/backend/expedition/infrastructure/EventResolutionIntegrationTest.java || fail 'PostgreSQL event resolution timestamps must follow the production expedition lock'
grep -Fq 'shouldTimestampAcknowledgementAfterAccountLock' backend/src/test/java/com/walkingrpg/backend/expedition/application/EventResultAcknowledgementServiceTest.java || fail 'event acknowledgement service coverage must order timestamps after account serialization'
grep -Fq 'shouldTimestampAcknowledgementAfterWaitingForAccountLock' backend/src/test/java/com/walkingrpg/backend/expedition/infrastructure/EventResolutionIntegrationTest.java || fail 'PostgreSQL event acknowledgement timestamps must follow the production account lock'
grep -Fq 'shouldTimestampUserTelemetryAfterAccountLock' backend/src/test/java/com/walkingrpg/backend/platform/application/PlatformAdminServiceTest.java || fail 'platform ingestion service coverage must order timestamps after account serialization'
grep -Fq 'shouldTimestampTelemetryAfterWaitingForAccountLock' backend/src/test/java/com/walkingrpg/backend/platform/application/AccountDeletionIntegrationTest.java || fail 'PostgreSQL telemetry timestamps must follow the production account lock'
grep -Fq 'bucketTotal = Math.addExact(bucketTotal, bucket.steps());' backend/src/main/java/com/walkingrpg/backend/risk/application/ActivityRiskEvaluator.java || fail 'activity bucket risk totals must reject signed long wraparound'
grep -Fq 'Math.multiplyExact(previousTotal, 8L)' backend/src/main/java/com/walkingrpg/backend/risk/application/ActivityRiskEvaluator.java || fail 'activity sudden-growth thresholds must reject signed long wraparound'
grep -Fq 'shouldNotLetBucketSumOverflowHideMismatch' backend/src/test/java/com/walkingrpg/backend/risk/application/ActivityRiskEvaluatorTest.java || fail 'risk coverage must preserve overflow-safe bucket mismatch detection'
grep -Fq 'shouldNotInventMultiplierGrowthWhenThresholdExceedsLongRange' backend/src/test/java/com/walkingrpg/backend/risk/application/ActivityRiskEvaluatorTest.java || fail 'risk coverage must preserve overflow-safe sudden-growth thresholds'
grep -Fq 'CanonicalUuid.parse(normalized)' backend/src/main/java/com/walkingrpg/backend/equipment/application/EquipmentCommandFactory.java || fail 'equipment item identity must reject shortened UUID aliases before service'
grep -Fq 'shouldRejectShortenedItemInstanceIdBeforeService' backend/src/test/java/com/walkingrpg/backend/equipment/api/EquipmentControllerTest.java || fail 'equipment API coverage must preserve fail-before-service UUID validation'
grep -Fq 'CanonicalUuid.parse(value)' backend/src/main/java/com/walkingrpg/backend/expedition/api/EventResultAcknowledgementController.java || fail 'event acknowledgement must reject shortened receipt UUID aliases before service'
grep -Fq 'shouldRejectNonCanonicalReceiptIdsWithStableValidationError' backend/src/test/java/com/walkingrpg/backend/expedition/api/EventResultAcknowledgementControllerTest.java || fail 'event ACK API coverage must preserve canonical UUID validation envelope'
grep -Fq 'return CanonicalUuid.parse(text).toString();' backend/src/main/java/com/walkingrpg/backend/platform/application/PlatformService.java || fail 'platform UUID payloads must share canonical request parsing'
for test_name in \
  ProductionOperationsGuardTest \
  PublicIngressPropertiesTest \
  PublicIngressRateLimiterTest \
  PublicIngressProtectionFilterTest \
  JdbcStatementTimeoutsTest \
  BoundedDataSourceHealthIndicatorTest \
  ActiveAccountFilterTest \
  OperationalEndpointsIntegrationTest; do
  grep -Fq "$test_name" .github/workflows/ci.yml || fail "$test_name must run in CI"
done

printf '%s\n' 'Checking synthetic backup/restore drill...'
grep -Fq 'postgres:17.10-alpine3.24' backend/src/test/java/com/walkingrpg/backend/operations/BackupRestoreDrillIntegrationTest.java || fail 'backup drill PostgreSQL tag must be pinned'
grep -Fq 'sha256:742f40ea20b9ff2ff31db5458d127452988a2164df9e17441e191f3b72252193' backend/src/test/java/com/walkingrpg/backend/operations/BackupRestoreDrillIntegrationTest.java || fail 'backup drill PostgreSQL digest must be pinned'
grep -Fq '"productionValidated", false' backend/src/test/java/com/walkingrpg/backend/operations/BackupRestoreDrillIntegrationTest.java || fail 'synthetic evidence must never claim production validation'
grep -Fq 'evidence.put("sourceGitSha", sourceGitSha);' backend/src/test/java/com/walkingrpg/backend/operations/BackupRestoreDrillIntegrationTest.java || fail 'synthetic evidence must record the exact tested commit'
grep -Fq 'evidence.put("sourceTreeClean", true);' backend/src/test/java/com/walkingrpg/backend/operations/BackupRestoreDrillIntegrationTest.java || fail 'synthetic evidence must assert a clean source tree'
grep -Fq '"--single-transaction"' backend/src/test/java/com/walkingrpg/backend/operations/BackupRestoreDrillIntegrationTest.java || fail 'restore must be atomic'
grep -Fq '"--exit-on-error"' backend/src/test/java/com/walkingrpg/backend/operations/BackupRestoreDrillIntegrationTest.java || fail 'restore must fail on the first error'
if grep -Fq '"--clean"' backend/src/test/java/com/walkingrpg/backend/operations/BackupRestoreDrillIntegrationTest.java \
    || grep -Fq '"--create"' backend/src/test/java/com/walkingrpg/backend/operations/BackupRestoreDrillIntegrationTest.java; then
  fail 'destructive backup drill restore flags are forbidden'
fi
grep -Fq 'Release quality · synthetic backup/restore drill' .github/workflows/release-quality.yml || fail 'synthetic restore drill must have a dedicated release check'
grep -Fq 'Release quality · synthetic backup/restore drill' scripts/ci/wait_for_required_checks.py || fail 'release finalizer must require the synthetic restore drill'
grep -Fq 'scripts/ci/wait_for_required_checks.py' .github/workflows/release-pr-finalizer.yml || fail 'release finalizer must use the tested strict check evaluator'
PYTHONDONTWRITEBYTECODE=1 python3 scripts/ci/test_wait_for_required_checks.py
grep -Fq 'object_pairs_hook=reject_duplicate_keys' scripts/operations/verify-backup-restore-evidence.py || fail 'evidence verifier must reject duplicate JSON keys'
grep -Fq 'require_exact_keys(evidence, TOP_LEVEL_KEYS, "$")' scripts/operations/verify-backup-restore-evidence.py || fail 'evidence verifier must reject unknown top-level fields'
grep -Fq 'require_exact_keys(postgres, POSTGRES_KEYS, "postgres")' scripts/operations/verify-backup-restore-evidence.py || fail 'evidence verifier must reject unknown nested fields'
grep -Fq '{"full", "receipt"}' scripts/operations/verify-backup-restore-evidence.py || fail 'evidence verifier must distinguish full and retained receipt modes'
grep -Fq 'EXPECTED_SOURCE_GIT_SHA=$2' scripts/operations/run-synthetic-backup-restore-drill.sh || fail 'backup drill must require the expected tested commit'
grep -Fq 'OUTPUT_DIRECTORY must be outside the repository' scripts/operations/run-synthetic-backup-restore-drill.sh || fail 'backup drill evidence must not be written into source directories'
grep -Fq 'require_exact_clean_source()' scripts/operations/run-synthetic-backup-restore-drill.sh || fail 'backup drill must define an exact clean-source check'
SOURCE_CHECK_COUNT=$(grep -Fc 'require_exact_clean_source' scripts/operations/run-synthetic-backup-restore-drill.sh)
[ "$SOURCE_CHECK_COUNT" -eq 4 ] || fail 'backup drill must check exact clean source before, after and after verification'
grep -Fq -- '--no-ext-diff' scripts/operations/run-synthetic-backup-restore-drill.sh || fail 'backup drill clean-source checks must ignore external diff helpers'
grep -Fq -- '--ignore-submodules=none' scripts/operations/run-synthetic-backup-restore-drill.sh || fail 'backup drill clean-source checks must include submodules'
grep -Fq 'ls-files --others --exclude-standard' scripts/operations/run-synthetic-backup-restore-drill.sh || fail 'backup drill must reject untracked source files'
grep -Fq 'timeout --kill-after=30s 15m' scripts/operations/run-synthetic-backup-restore-drill.sh || fail 'backup drill must have a hard process-group kill budget'
if grep -Fq 'timeout --foreground' scripts/operations/run-synthetic-backup-restore-drill.sh; then
  fail 'foreground timeout would leave forked test processes outside the hard budget'
fi
grep -Fq '      clean \' scripts/operations/run-synthetic-backup-restore-drill.sh || fail 'backup drill must discard stale Maven build output'
RELEASE_CHECKOUT_COUNT=$(grep -Fc 'uses: actions/checkout@v4' .github/workflows/release-quality.yml)
EXACT_RELEASE_CHECKOUT_COUNT=$(grep -Fc 'ref: ${{ github.event.pull_request.head.sha || github.sha }}' .github/workflows/release-quality.yml)
[ "$RELEASE_CHECKOUT_COUNT" -eq 5 ] || fail 'Release quality must keep exactly five source checkout steps'
[ "$EXACT_RELEASE_CHECKOUT_COUNT" -eq "$RELEASE_CHECKOUT_COUNT" ] || fail 'every Release quality checkout must bind to the exact workflow source SHA'
grep -Fq 'EXPECTED_SOURCE_GIT_SHA: ${{ github.event.pull_request.head.sha || github.sha }}' .github/workflows/release-quality.yml || fail 'backup drill evidence must bind to the exact tested SHA'
grep -Fq "export GIT_TREE=\"\$(git rev-parse 'HEAD^{tree}')\"" .github/workflows/release-quality.yml || fail 'release metadata must record the exact workflow source tree'
grep -Fq "'treeSha': tree" scripts/generate-build-metadata.sh || fail 'release metadata must include the exact Git tree'
grep -Fq 'steps.upload-evidence.outputs.artifact-digest' .github/workflows/release-quality.yml || fail 'retained evidence provenance must record the artifact digest'
if grep -Fq 'walking-rpg-synthetic.dump' .github/workflows/release-quality.yml; then
  fail 'backup archive or row payload must not be uploaded as a CI artifact'
fi
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest \
  scripts/operations/test_verify_backup_restore_evidence.py

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
if versions != expected or not versions or versions[-1] < 17:
    raise SystemExit(f'Flyway versions must be contiguous through at least V17: {versions}')
print('Flyway versions:', versions)
PY

printf '%s\n' 'Checking mobile release configuration...'
bash scripts/ci/verify-android-release-config.sh --static
grep -Fq "platform :ios, '14.0'" mobile/ios/Podfile || fail 'Podfile deployment target must be iOS 14.0'

printf '%s\n' 'Checking backend CI test selection...'
PYTHONDONTWRITEBYTECODE=1 python3 scripts/ci/verify_backend_test_selection.py

printf '%s\n' 'Checking mobile authentication boundary...'
grep -Fq 'flutter_appauth: 12.0.2' mobile/pubspec.yaml || fail 'flutter_appauth must be pinned'
grep -Fq 'flutter_secure_storage: 10.3.1' mobile/pubspec.yaml || fail 'secure token storage must be pinned'
grep -Fq 'device_info_plus: 12.4.0' mobile/pubspec.yaml || fail 'validation OS metadata provider must be pinned'
grep -Fq 'package_info_plus: 9.0.1' mobile/pubspec.yaml || fail 'runtime package metadata provider must be pinned'
grep -Fq "defaultValue: 'oidc'" mobile/lib/core/config/app_environment.dart || fail 'mobile auth must fail closed as oidc'
grep -Fq 'oidcAudience = String.fromEnvironment' mobile/lib/core/config/app_environment.dart || fail 'mobile OIDC audience must be a required build input'
grep -Fq "'audience': configuration.audience" mobile/lib/core/auth/oidc_client.dart || fail 'authorization must request the exact API audience'
grep -Fq "'ui_locales': locale" mobile/lib/core/auth/oidc_client.dart || fail 'Universal Login must receive the selected locale'
grep -Fq "'ext-installation-id': _requireInstallationId" mobile/lib/core/auth/oidc_client.dart || fail 'authorization and refresh must carry a bounded installation ID'
grep -Fq "step_beyond_installation_id_v1" mobile/lib/core/auth/installation_id_store.dart || fail 'installation identity storage must remain versioned'
grep -Fq 'auth0/actions/step-beyond-token-contract.test.js' .github/workflows/ci.yml || fail 'Auth0 token contract tests must run in CI'
grep -Fq 'auth0/telegram/telegram-oidc-connection.test.js' .github/workflows/ci.yml || fail 'Telegram OIDC connection tests must run in CI'
grep -Fq 'https://oauth.telegram.org/.well-known/openid-configuration' auth0/telegram/connection.template.json || fail 'Telegram OIDC discovery must remain provider-owned'
grep -Fq '"scopes": "openid profile"' auth0/telegram/connection.template.json || fail 'Telegram login must request only openid and profile'
grep -Fq '"pkce": "s256"' auth0/telegram/connection.template.json || fail 'Telegram upstream OIDC must require PKCE S256'
grep -Fq '"is_domain_connection": false' auth0/telegram/connection.template.json || fail 'Telegram connection must not be domain-level'
grep -Fq '"show_as_button": true' auth0/telegram/connection.template.json || fail 'Telegram must be visible in Universal Login'
if grep -Eq '"scopes"[[:space:]]*:[^\n]*(phone|telegram:bot_access)' auth0/telegram/connection.template.json; then
  fail 'Telegram login must not request phone or bot direct-message access'
fi
node --test \
  auth0/actions/step-beyond-token-contract.test.js \
  auth0/telegram/telegram-oidc-connection.test.js
grep -Fq 'OIDC_AUDIENCE=$RELEASE_CANDIDATE_OIDC_AUDIENCE' .github/workflows/release-quality.yml || fail 'release candidates must embed the configured OIDC audience'
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

printf '%s\n' 'Checking internal device-validation boundary...'
grep -Fq "'ENABLE_VALIDATION_CENTER'," mobile/lib/core/config/app_environment.dart || fail 'validation center must require an explicit build flag'
grep -A1 -F "'ENABLE_VALIDATION_CENTER'," mobile/lib/core/config/app_environment.dart | grep -Fq 'defaultValue: false' || fail 'validation center must be disabled by default'
grep -Fq 'return requested && !releaseMode;' mobile/lib/features/validation/validation_center_policy.dart || fail 'release builds must never enable validation center'
grep -Fq 'Validation Center запрещён в production build' mobile/lib/features/validation/validation_center_policy.dart || fail 'release validation flag must fail closed at startup'
grep -Fq 'ValidationCenterPolicy.enabled' mobile/lib/app/auth_gate.dart || fail 'validation route must remain behind the non-release policy'
grep -Fq 'PackageInfo.fromPlatform()' mobile/lib/app/auth_gate.dart || fail 'validation app/build metadata must come from the installed package'
grep -Fq 'DeviceInfoPlugin()' mobile/lib/app/auth_gate.dart || fail 'validation OS metadata must come from the device platform API'
grep -Fq 'activeSessionRevisionProvider' mobile/lib/app/auth_gate.dart || fail 'validation actions must re-check the live auth session'
grep -Fq 'Stopwatch()..start()' mobile/lib/features/validation/application/validation_evidence_controller.dart || fail 'validation durations must use a monotonic clock'
grep -Fq 'EvidenceErrorCategory.journalLimitReached' mobile/lib/features/validation/application/validation_evidence_controller.dart || fail 'validation journal overflow must remain visible in evidence'
grep -Fq 'walking-rpg-device-validation-evidence-v1' mobile/lib/features/validation/domain/device_validation_evidence.dart || fail 'validation evidence schema must be versioned'
grep -Fq 'walking-rpg-evidence-redaction-v1' mobile/lib/features/validation/domain/device_validation_evidence.dart || fail 'validation evidence redaction policy must be versioned'
grep -Fq 'static const int maxJournalEntries = 64;' mobile/lib/features/validation/domain/device_validation_evidence.dart || fail 'validation journal must remain bounded'
grep -Fq 'static const int maxEncodedBytes = 64 * 1024;' mobile/lib/features/validation/domain/device_validation_evidence.dart || fail 'validation evidence must remain bounded to 64 KiB'
grep -Fq '_validateSnapshotSemantics(' mobile/lib/features/validation/domain/device_validation_evidence.dart || fail 'validation evidence must enforce cross-field semantics'
grep -Fq 'DeviceValidationEvidenceCodec.verify(json)' mobile/lib/features/validation/application/validation_evidence_exporter.dart || fail 'validation export must verify schema, redaction and checksum before sharing'
grep -Fq 'await file.delete();' mobile/lib/features/validation/application/validation_evidence_exporter.dart || fail 'temporary validation evidence must be deleted after sharing'
if grep -RInE 'ENABLE_VALIDATION_CENTER[=:][[:space:]]*true' .github 2>/dev/null | grep -q .; then
  fail 'CI and release workflows must not enable validation center'
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
REPRO_TMPDIR=${TMPDIR:-$ROOT_DIR}
TMP_DIR=$(mktemp -d "$REPRO_TMPDIR/walking-rpg-metadata.XXXXXXXXXX")
trap 'rm -rf "$TMP_DIR"' EXIT
for output in one two; do
  GIT_SHA=0000000000000000000000000000000000000000 \
  GIT_TREE=1111111111111111111111111111111111111111 \
  SOURCE_DATE_EPOCH=1785139200 \
  FLUTTER_VERSION=3.44.7 \
  JAVA_VERSION=21 \
    sh scripts/generate-build-metadata.sh "$TMP_DIR/$output.json" >/dev/null
done
cmp "$TMP_DIR/one.json" "$TMP_DIR/two.json" || fail 'build metadata is not reproducible'
PYTHONDONTWRITEBYTECODE=1 python3 - "$TMP_DIR/one.json" <<'PY'
import json
import pathlib
import sys

metadata = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
if metadata.get("schemaVersion") != 2:
    raise SystemExit("build metadata schemaVersion must be 2")
android = metadata.get("android")
if not isinstance(android, dict):
    raise SystemExit("build metadata must contain an Android object")
expected = {
    "compileSdk": 36,
    "minSdk": 26,
    "releaseSigning": "external-protected-environment",
    "targetSdk": 36,
}
for key, value in expected.items():
    if android.get(key) != value:
        raise SystemExit(
            f"build metadata Android {key} must be {value!r}, got {android.get(key)!r}"
        )
print("Build metadata Android release contract:", expected)
source = metadata.get("source")
if not isinstance(source, dict):
    raise SystemExit("build metadata must contain a source object")
if source.get("commitSha") != "0" * 40:
    raise SystemExit("build metadata commitSha must match the exact source commit")
if source.get("treeSha") != "1" * 40:
    raise SystemExit("build metadata treeSha must match the exact source tree")
print("Build metadata source provenance:", source["commitSha"], source["treeSha"])
PY

if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git diff --check
fi

printf '%s\n' 'Release readiness checks passed.'
