# Store declarations draft

Этот пакет предназначен для подготовки App Store Connect и Google Play Console. Перед публикацией формулировки сверяются с фактическим build и актуальными правилами магазинов.

## Назначение

Walking RPG превращает агрегированное количество шагов за локальный день в игровую энергию. Приложение не является медицинским продуктом, не диагностирует состояние здоровья и не предоставляет медицинских рекомендаций.

## Health data

- iOS: HealthKit read access только к step count.
- Android: Health Connect `READ_STEPS` и Activity Recognition, когда требуется ОС.
- Сырые health samples не отправляются backend; передаётся агрегированный total, timezone и технические идентификаторы.
- Health data не продаётся и не используется для рекламы.

## App Privacy / Data Safety

Могут обрабатываться:

- pseudonymous account id из OIDC subject и хэшированный device/session id;
- aggregated daily steps, timezone и local date;
- игровой прогресс, инвентарь и команды;
- crash/diagnostic events;
- experiment exposure;
- tester cohort membership.

Цели: authentication, account management, core functionality, fraud prevention, diagnostics и product analytics. Account export/delete предусмотрены backend-контрактом.

## Payments и push

Текущий build содержит sandbox payment provider и development push provider. До подключения store billing/APNs/FCM эти возможности не декларируются как production-интеграции.

## Обязательные публичные ссылки

Перед submission нужны постоянные URL privacy policy, support/contact и account deletion instructions.
