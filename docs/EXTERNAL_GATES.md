# External gates

## Статусы

- `CODE_COMPLETE` — код, контракты, миграции и CI готовы.
- `EXTERNAL_VALIDATION_REQUIRED` — нужен физический девайс, credential, магазин или реальные пользователи.
- `VALIDATED` — существует датированное evidence с устройством, версиями и результатом.

## HealthKit / Health Connect

`EXTERNAL_VALIDATION_REQUIRED`: нужны iPhone, Apple Watch, Android, несколько providers, ручные записи, удаление/коррекция, отзыв разрешения, timezone/midnight и battery evidence.

## Background delivery

Foreground durable outbox и resume fallback — `CODE_COMPLETE`. Гарантированная доставка ОС не заявляется до измерений на устройствах.

## Identity / Auth0

Auth0 EU contract, API audience, native PKCE parameters, stable installation ID,
namespaced device/fresh-auth claims and fail-closed protected configuration —
`CODE_COMPLETE` according to
[ADR 0035](adr/0035-auth0-alpha-authentication-contract.md).
The secret-free Telegram OIDC connection contract, minimum `openid profile`
scope, S256 upstream PKCE, RU/EN entry copy and evidence/rollback procedure are
also `CODE_COMPLETE` according to
[ADR 0037](adr/0037-telegram-login-through-auth0.md).

Creation of the stage tenant/application/API, email OTP delivery, Apple/Google
connections, Telegram bot/callback/credential/connection, protected values,
deployed Action and real login/refresh/revoke/logout/account-switch evidence on
physical iOS and Android —
`EXTERNAL_VALIDATION_REQUIRED`. Repository tests and unsigned CI artifacts do
not prove that any provider connection is active.

## Push

Provider boundary, явная local/test-регистрация и fail-closed disabled
provider для `stage`/`prod` — `CODE_COMPLETE`; APNs/FCM provider, credentials,
token rotation и delivery evidence — `EXTERNAL_VALIDATION_REQUIRED`.

## Payments

Provider boundary, явная local/test-регистрация sandbox и запрет
sandbox-покупок в `stage`/`prod` backend profiles и release mobile build —
`CODE_COMPLETE`; App Store/Google Play billing, server verification, restore,
refunds и revocations — `EXTERNAL_VALIDATION_REQUIRED`.

## Production environment и database

Protected `stage`/`prod` profiles, fail-closed startup guards и статические
release checks — `CODE_COMPLETE`. A4b также даёт bounded per-process
diagnostics/telemetry ingress, отдельный loopback management listener,
защищённые metrics, конечные operational timeouts и synthetic PostgreSQL
backup/restore round-trip — `CODE_COMPLETE`.

DigitalOcean alpha-stage decision, non-root Java 21 container, reviewed App
Spec template with immutable GHCR digest, embedded source SHA/tree startup
guard, runtime CA delivery for pgJDBC, distinct `/livez`/`/readyz` platform
probes and owner runbook are repository-verifiable according to [ADR
0036](adr/0036-digitalocean-alpha-stage.md). Merge и green CI переводят этот
deployment wiring в `CODE_COMPLETE`, но не публикуют approved image и не
создают платный stage.

Protected `stage-release` approval, public GHCR package, published image digest
and verified receipt, production OIDC/database secrets, реальный TLS endpoint,
least-privilege DB role, deployment, management network isolation,
WAF/distributed limiter,
monitoring/alerting, backup scheduling/encryption/retention, PITR/RPO/RTO
policy и датированный restore реального backup —
`EXTERNAL_VALIDATION_REQUIRED`. Реальный restore принимается только по
fail-closed [protected restore evidence contract](PRODUCTION_OPERATIONS_RUNBOOK.md#actual-backuprestore-gate)
с точным stage и protected attestation. Наличие Flyway V14, успешный CI startup или
`scope=SYNTHETIC_CI` не является доказательством production
deployment/restore.
Drain старого backend pool и последующая активация staged `chapter-1-v2` по
production runbook также требуют внешнего deployment evidence; CI подтверждает
только fail-closed исходное состояние и кодовые read/write gates.

## Signing и публикация

CI создаёт Android API 36 unsigned AAB и iOS no-codesign app. Android
external-signing wiring проверяется только synthetic одноразовым ключом без
сохраняемого signed artifact. Production signing, final application IDs,
submission и store review — `EXTERNAL_VALIDATION_REQUIRED`.

Порядок защищённой сборки и допустимое evidence:
[PROTECTED_MOBILE_SIGNING.md](PROTECTED_MOBILE_SIGNING.md).

## Closed beta

Tester cohort/admin support, first-journey analytics и compass
recipe→craft→equip→route funnel — `CODE_COMPLETE`. Compass impressions явно
client-reported, gameplay stages server-authoritative, а coverage/order gaps
возвращаются как data-quality counters.

50–500 реальных участников, достаточная instrumentation rate, подтверждённые
D1/D7/D30, понятность craft/equip и ценность resonance route —
`EXTERNAL_VALIDATION_REQUIRED`. Наличие endpoint-а или synthetic fixture не
является validation evidence.
