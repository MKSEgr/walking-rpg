# ADR 0005: PostgreSQL persistence и сериализация activity sync

- **Статус:** принято
- **Дата:** 2026-07-25
- **Связанный issue:** #4

## Контекст

Первый activity-sync spike проверил HTTP-контракт, расчёт положительной дельты, накопительные пороги энергии и идемпотентный повтор. Состояние находилось в `ConcurrentHashMap`, поэтому исчезало после перезапуска и не могло безопасно использоваться несколькими backend-инстансами.

При этом один и тот же пользователь/устройство может отправить два sync почти одновременно: foreground и background worker, повтор после сетевого таймаута либо два экземпляра backend. Если оба запроса прочитают один старый total, они могут дважды начислить одну и ту же дельту.

## Решение

1. Использовать PostgreSQL как источник истины для activity sync.
2. Управлять схемой через Flyway.
3. Хранить:
   - технические `app_user` и `app_device`;
   - `activity_sync_state` по user/device/localDate;
   - `processed_activity_sync` по user/device/idempotencyKey.
4. Выполнять весь sync в одной Spring transaction.
5. В начале транзакции получать PostgreSQL advisory transaction lock по стабильному ключу user/device.
6. Проверять idempotency только после получения lock.
7. Хранить ранее выданный response целиком и возвращать его без повторного расчёта.
8. Для сравнения payload хранить SHA-256 fingerprint канонической команды, а не сырые bucket-ы, cursor или attestation.
9. Не использовать Redis-lock и отдельный ingestion-сервис до появления измеренной необходимости.

## Последствия

### Положительные

- accepted state переживает перезапуск;
- одинаковый idempotency key работает после рестарта;
- несколько backend-инстансов сериализуют sync одного устройства;
- state и idempotent response коммитятся атомарно;
- rollback не оставляет частично обработанный ключ;
- в БД не сохраняются сырые attestation-токены и подробные bucket-ы;
- схема проверяется на чистом PostgreSQL через Testcontainers.

### Отрицательные

- локальный запуск backend теперь требует PostgreSQL;
- sync одной пары user/device выполняется последовательно;
- advisory lock является PostgreSQL-specific решением;
- таблице processed sync понадобится retention;
- технические user/device пока не заменяют полноценную identity-модель.

## Альтернативы

### Оставить `synchronized` и in-memory repository

Не переживает restart и не работает между инстансами.

### Использовать optimistic locking без сериализации

Потребовал бы retry-цикла и отдельного решения для конкурентной idempotency. Для первого среза это сложнее и хуже объясняется.

### Redis distributed lock

Добавляет отдельную инфраструктуру и новый failure mode при уже имеющейся PostgreSQL transaction. На текущем масштабе не оправдан.

### Хранить весь request JSON

Упростило бы восстановление команды, но увеличило бы объём чувствительных health-данных. Для проверки повтора достаточно fingerprint.

## Условия пересмотра

Решение пересматривается, если:

- lock contention заметно влияет на latency;
- потребуется параллельная обработка независимых источников одного устройства;
- activity ingest будет вынесен в отдельный сервис;
- появится очередь событий и exactly-once модель;
- PostgreSQL перестанет быть основной operational database.
