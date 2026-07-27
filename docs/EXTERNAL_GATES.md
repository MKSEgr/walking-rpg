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

Provider boundary и development implementation — `CODE_COMPLETE`; APNs/FCM credentials, token rotation и delivery evidence — `EXTERNAL_VALIDATION_REQUIRED`.

## Payments

Provider boundary и sandbox — `CODE_COMPLETE`; App Store/Google Play billing, server verification, restore, refunds и revocations — `EXTERNAL_VALIDATION_REQUIRED`.

## Signing и публикация

CI создаёт Android unsigned AAB и iOS no-codesign app. Production signing, submission и store review — `EXTERNAL_VALIDATION_REQUIRED`.

## Closed beta

Tester cohort/admin support — `CODE_COMPLETE`; 50–500 реальных участников и подтверждённые D1/D7/D30 — `EXTERNAL_VALIDATION_REQUIRED`.
