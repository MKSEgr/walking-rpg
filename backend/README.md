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
→ first event READY
```

Activity sync сериализуется PostgreSQL advisory transaction lock по пользователю. Продвижение экспедиции использует отдельный lock по пользователю и экспедиции, а economy-модуль блокирует wallet row через `FOR UPDATE`.

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

Интеграционные тесты поднимают PostgreSQL через Testcontainers и проверяют:

- постоянную activity idempotency;
- конкурентную синхронизацию с разных устройств;
- ENERGY credit/debit и ledger;
- точный replay command response;
- постоянный expedition progress;
- конкурентное продвижение экспедиции;
- rollback activity/economy/expedition состояния при поздней ошибке;
- production home read-model.

## Endpoint-ы

```text
GET  /actuator/health
GET  /api/v1/system/info
GET  /api/v1/home/demo
GET  /api/v1/home?localDate=YYYY-MM-DD
POST /api/v1/activity/sync
POST /api/v1/expeditions/{expeditionId}/advance
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
    "localDate": "2026-07-25",
    "timeZone": "Europe/Berlin",
    "authoritativeTotal": 6842,
    "buckets": [],
    "syncCursor": "cursor-1",
    "idempotencyKey": "demo-device-1-2026-07-25-1",
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

При достижении 30 ENERGY response получает:

```json
{
  "expeditionId": "starter-expedition-v1",
  "energySpent": 30,
  "energyBalanceAfter": 38,
  "progressAfter": 30,
  "requiredEnergy": 30,
  "status": "EVENT_READY",
  "unlockedEvent": {
    "eventId": "signal-source-v1",
    "title": "Источник сигнала",
    "status": "READY"
  }
}
```

## Что сохраняется

```text
app_user                       — временная identity
app_device                     — устройство пользователя
activity_sync_state            — дневной accepted total
processed_activity_sync        — idempotent activity/economy response
economy_wallet                 — текущий баланс ENERGY и версия
economy_ledger                 — append-only credit/debit журнал
expedition_progress            — постоянный progress стартовой экспедиции
processed_expedition_advance   — idempotent expedition/economy response
```

## Инварианты

- клиент не задаёт итоговую награду;
- баланс меняется только через ledger;
- wallet не может стать отрицательным;
- один economy source создаёт не более одной ledger-записи;
- один expedition idempotency key не создаёт два списания;
- расход ENERGY, expedition progress и processed response фиксируются одной транзакцией;
- после `EVENT_READY` дальнейшее продвижение запрещено до разрешения события;
- `GET /home` не создаёт данные.

## Текущие ограничения

- заголовки пользователя и устройства временные;
- attestation не проверяется;
- реализована одна экспедиция и один узел;
- событие открывается, но пока не имеет вариантов решения;
- pilot/pet progression не сохраняется;
- mobile ещё не отправляет реальные шаги из Health API;
- offline cache отсутствует.
