# Walking RPG Backend

Java/Spring Boot backend первоначального проекта.

## Стек

- Java 21
- Spring Boot 4.1.x
- Spring MVC
- Bean Validation
- Spring JDBC
- PostgreSQL 17
- Flyway
- Testcontainers
- Actuator
- Maven Wrapper

Activity sync хранит принятый total, версию состояния и idempotent response в PostgreSQL. Для запросов одного пользователя используется PostgreSQL advisory transaction lock: sync с разных устройств сериализуются не только внутри одного Java-процесса, но и между backend-инстансами.

Положительная `energyGranted` проводится через economy module: wallet row блокируется, баланс обновляется, ledger entry добавляется, а итоговый economy snapshot сохраняется вместе с activity response в одной транзакции.

Production home read-model объединяет дневной activity state и актуальный ENERGY wallet без изменения БД. Пилот, питомец и экспедиция пока приходят из версионированного `starter-v1`; изменяемые игровые экземпляры появятся вместе с продвижением экспедиции.

## Локальный запуск

Из корня репозитория запустить PostgreSQL:

```bash
docker compose up -d postgres
```

Затем:

```bash
cd backend
./mvnw spring-boot:run
```

Windows:

```powershell
docker compose up -d postgres
cd backend
.\mvnw.cmd spring-boot:run
```

Стандартные параметры подключения:

```text
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=walking_rpg
POSTGRES_USER=walking_rpg
POSTGRES_PASSWORD=walking_rpg_local
```

Стандартные Spring-переменные `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME` и `SPRING_DATASOURCE_PASSWORD` также могут переопределить подключение.

Flyway автоматически применяет миграции из `src/main/resources/db/migration`.

## Тесты

```bash
./mvnw verify
```

Интеграционные тесты используют Testcontainers и требуют доступный Docker daemon. Они поднимают чистый PostgreSQL, применяют Flyway и проверяют:

- постоянную idempotency;
- сериализацию конкурентных запросов;
- wallet и ledger;
- отсутствие ledger entry без пересечения энергетического порога;
- rollback activity/economy состояния при ошибке в конце транзакции;
- production home projection для текущего и другого локального дня;
- zero-state неизвестного пользователя без побочных записей.

## Endpoint-ы

```text
GET  /actuator/health
GET  /api/v1/system/info
GET  /api/v1/home/demo
GET  /api/v1/home?localDate=YYYY-MM-DD
POST /api/v1/activity/sync
```

### Синхронизация активности

```bash
curl -X POST http://localhost:8080/api/v1/activity/sync \
  -H 'Content-Type: application/json' \
  -H 'X-User-Id: demo-user-1' \
  -H 'X-Device-Id: demo-device-1' \
  -d '{
    "localDate": "2026-07-25",
    "timeZone": "Europe/Berlin",
    "authoritativeTotal": 6842,
    "buckets": [],
    "syncCursor": "cursor-1",
    "idempotencyKey": "demo-device-1-2026-07-25-1",
    "attestation": null
  }'
```

Фрагмент response:

```json
{
  "acceptedTotal": 6842,
  "acceptedDelta": 6842,
  "energyGranted": 68,
  "energyBalanceAfter": 68,
  "economyVersion": 1,
  "riskStatus": "ACCEPTED",
  "stateVersion": 1,
  "serverTime": "2026-07-25T12:00:00Z"
}
```

### Production home

```bash
curl 'http://localhost:8080/api/v1/home?localDate=2026-07-25' \
  -H 'X-User-Id: demo-user-1'
```

```json
{
  "localDate": "2026-07-25",
  "timeZone": "Europe/Berlin",
  "dailySteps": 6842,
  "dailyGoal": 6000,
  "availableEnergy": 68,
  "activityStateVersion": 1,
  "economyVersion": 1,
  "lastActivitySyncAt": "2026-07-25T12:00:00Z",
  "serverTime": "2026-07-25T12:01:00Z",
  "contentVersion": "starter-v1",
  "pilot": {
    "name": "Навигатор",
    "level": 1,
    "currentExperience": 20,
    "nextLevelExperience": 100,
    "specialization": "Не выбрана"
  },
  "pet": {
    "name": "Искра",
    "species": "Люмин",
    "level": 1,
    "bond": 10,
    "trait": "Чуткий разведчик"
  },
  "expedition": {
    "name": "Сигнал из туманного сектора",
    "currentNode": "Внешний маяк",
    "progress": 0,
    "requiredEnergy": 30
  }
}
```

Семантика:

- `localDate` передаёт клиент, потому что backend не должен угадывать календарный день пользователя;
- `timeZone` берётся из сохранённого activity state для этого дня и может быть `null`;
- шаги относятся к запрошенному локальному дню;
- ENERGY balance является текущим глобальным балансом пользователя и не обнуляется при смене даты;
- неизвестный user/date возвращает нули вместо 404;
- `GET` не создаёт `app_user`, wallet или игровой прогресс;
- `contentVersion=starter-v1` явно показывает, что pilot/pet/expedition пока являются server-owned starter template.

## Что сохраняется

```text
app_user                  — временная техническая identity пользователя
app_device                — устройство пользователя
activity_sync_state       — общий high-watermark пользователя по локальному дню
processed_activity_sync   — fingerprint и неизменяемый activity/economy response
economy_wallet            — текущий баланс ENERGY и его версия
economy_ledger            — append-only журнал ненулевых изменений баланса
```

Сырые bucket-ы, attestation и sync cursor в БД пока не сохраняются. Для проверки повторного ключа хранится SHA-256 fingerprint нормализованной бизнес-команды. Attestation в fingerprint не входит: после появления проверки он будет валидироваться отдельно для каждого запроса.

`energyBalanceAfter` — snapshot после исходной операции. Повтор старого idempotency key возвращает тот же snapshot, даже если более новые операции уже изменили актуальный баланс. `GET /home` возвращает уже самое новое агрегированное состояние.

## Текущие ограничения

- заголовки пользователя и устройства временные;
- attestation пока не проверяется;
- поддерживается только начисление ENERGY, без списания;
- pilot/pet/expedition в home response пока не являются изменяемыми записями;
- для `processed_activity_sync` ещё не реализована retention-политика;
- mobile читает home, но пока не отправляет activity sync;
- нет offline cache;
- модель `app_user`/`app_device` техническая и будет заменена или расширена при появлении аутентификации.

Следующая продуктовая задача:

```text
production home → persistent expedition → debit ENERGY → один игровой узел
```
