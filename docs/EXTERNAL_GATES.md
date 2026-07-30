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
release checks — `CODE_COMPLETE`.

Production OIDC/database secrets, реальный TLS endpoint, least-privilege DB
role, deployment, monitoring/alerting, backup policy и датированный restore
drill — `EXTERNAL_VALIDATION_REQUIRED`. Наличие Flyway V12 или успешный CI
startup не является доказательством production deployment/restore.

## Signing и публикация

CI создаёт Android unsigned AAB и iOS no-codesign app. Production signing, submission и store review — `EXTERNAL_VALIDATION_REQUIRED`.

## Closed beta

Tester cohort/admin support — `CODE_COMPLETE`; 50–500 реальных участников и подтверждённые D1/D7/D30 — `EXTERNAL_VALIDATION_REQUIRED`.
