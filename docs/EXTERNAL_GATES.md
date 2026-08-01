# External gates

## Статусы

- `CODE_COMPLETE` — код, контракты, миграции и CI готовы.
- `EXTERNAL_VALIDATION_REQUIRED` — нужен физический девайс, credential, магазин или реальные пользователи.
- `VALIDATED` — существует датированное evidence с устройством, версиями и результатом.

## HealthKit / Health Connect

`EXTERNAL_VALIDATION_REQUIRED`: нужны iPhone, Apple Watch, Android, несколько providers, ручные записи, удаление/коррекция, отзыв разрешения, timezone/midnight и battery evidence.

## Background delivery

Foreground durable outbox и resume fallback — `CODE_COMPLETE`. Гарантированная доставка ОС не заявляется до измерений на устройствах.

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

Production OIDC/database secrets, реальный TLS endpoint, least-privilege DB
role, deployment, management network isolation, WAF/distributed limiter,
monitoring/alerting, backup scheduling/encryption/retention, PITR/RPO/RTO
policy и датированный restore реального backup —
`EXTERNAL_VALIDATION_REQUIRED`. Наличие Flyway V13, успешный CI startup или
`scope=SYNTHETIC_CI` не является доказательством production
deployment/restore.

## Signing и публикация

CI создаёт Android API 36 unsigned AAB и iOS no-codesign app. Android
external-signing wiring проверяется только synthetic одноразовым ключом без
сохраняемого signed artifact. Production signing, final application IDs,
submission и store review — `EXTERNAL_VALIDATION_REQUIRED`.

Порядок защищённой сборки и допустимое evidence:
[PROTECTED_MOBILE_SIGNING.md](PROTECTED_MOBILE_SIGNING.md).

## Closed beta

Tester cohort/admin support — `CODE_COMPLETE`; 50–500 реальных участников и подтверждённые D1/D7/D30 — `EXTERNAL_VALIDATION_REQUIRED`.
