# Walking RPG Backend

Java/Spring Boot backend walking-RPG.

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

## Реализованный вертикальный поток

```text
authoritative step total
→ activity high-watermark
→ ENERGY credit
→ production home snapshot
→ ENERGY debit
→ expedition progress
→ event READY
→ server-owned choice
→ persistent pilot XP + pet bond
→ expedition COMPLETED
```

Activity sync сериализуется advisory transaction lock по пользователю. Advance и event resolution используют lock по пользователю и экспедиции. Economy блокирует wallet row через `FOR UPDATE`.

## Локальный запуск

```bash
docker compose up -d postgres
cd backend
./mvnw spring-boot:run
```

Windows:

```powershell
docker compose up -d postgres
cd backend
.\mvnw.cmd spring-boot:run
```

Стандартные параметры:

```text
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=walking_rpg
POSTGRES_USER=walking_rpg
POSTGRES_PASSWORD=walking_rpg_local
```

Flyway автоматически применяет миграции из `src/main/resources/db/migration`.

## Тесты

```bash
./mvnw verify
```

PostgreSQL Testcontainers tests проверяют:

- persistent activity idempotency и multi-device high-watermark;
- ENERGY credit/debit и append-only ledger;
- exact replay command response;
- expedition progress и конкурентные advance;
- event choice и persistent pilot/pet progression;
- повторное/конфликтное resolution;
- rollback activity/economy/expedition/progression при поздней ошибке;
- production home read-model до и после события.

## Endpoint-ы

```text
GET  /actuator/health
GET  /api/v1/system/info
GET  /api/v1/home/demo
GET  /api/v1/home?localDate=YYYY-MM-DD
POST /api/v1/activity/sync
POST /api/v1/expeditions/{expeditionId}/advance
POST /api/v1/events/{eventId}/resolve
```

До появления authentication используются временные заголовки:

```text
X-User-Id
X-Device-Id  # только activity sync
```

### Синхронизация шагов

```bash
curl -X POST http://localhost:8080/api/v1/activity/sync \
  -H 'Content-Type: application/json' \
  -H 'X-User-Id: demo-user-1' \
  -H 'X-Device-Id: demo-device-1' \
  -d '{
    "localDate": "2026-07-26",
    "timeZone": "Europe/Berlin",
    "authoritativeTotal": 6842,
    "buckets": [],
    "syncCursor": "cursor-1",
    "idempotencyKey": "demo-device-1-2026-07-26-1",
    "attestation": null
  }'
```

### Продвижение стартовой экспедиции

```bash
curl -X POST \
  http://localhost:8080/api/v1/expeditions/starter-expedition-v1/advance \
  -H 'Content-Type: application/json' \
  -H 'X-User-Id: demo-user-1' \
  -d '{
    "energyToSpend": 30,
    "idempotencyKey": "starter-expedition-v1-advance-1"
  }'
```

После достижения 30 ENERGY открывается `signal-source-v1` в статусе `READY`.

### Разрешение первого события

```bash
curl -X POST \
  http://localhost:8080/api/v1/events/signal-source-v1/resolve \
  -H 'Content-Type: application/json' \
  -H 'X-User-Id: demo-user-1' \
  -d '{
    "choiceId": "analyze-signal",
    "idempotencyKey": "signal-source-v1-resolution-1"
  }'
```

Доступные choice:

```text
analyze-signal  → +40 pilot XP, +5 pet bond
trust-spark     → +20 pilot XP, +15 pet bond
```

После успеха expedition получает `COMPLETED`, а `GET /home` возвращает resolved outcome и постоянный progression.

## Что сохраняется

```text
app_user                       — временная identity
app_device                     — устройство пользователя
activity_sync_state            — дневной accepted total
processed_activity_sync        — idempotent activity/economy response
economy_wallet                 — текущий баланс ENERGY и версия
economy_ledger                 — append-only credit/debit журнал
expedition_progress            — progress/status стартовой экспедиции
processed_expedition_advance   — idempotent expedition/economy response
pilot_progress                 — уровень и опыт пилота
pet_progress                   — уровень и bond питомца
processed_event_resolution     — idempotent event/progression response
```

## Инварианты

- клиент не задаёт итоговую награду;
- баланс меняется только через ledger;
- wallet не может стать отрицательным;
- один economy source создаёт не более одной ledger-записи;
- один command key не создаёт повторное изменение состояния;
- key с другим payload возвращает `IDEMPOTENCY_CONFLICT`;
- event разрешается только из `EVENT_READY`;
- progression и expedition completion фиксируются одной транзакцией;
- `GET /home` не создаёт данные.

## Текущие ограничения

- заголовки пользователя и устройства временные;
- attestation не проверяется;
- одна экспедиция, один узел и одно событие;
- content definition хранится в коде;
- нет inventory/reward journal для предметов;
- mobile ещё не читает Apple Health/Health Connect;
- offline cache отсутствует.
