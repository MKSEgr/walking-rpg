# Walking RPG Backend

Java/Spring Boot backend walking-RPG.

## Стек

- Java 21
- Spring Boot 4.1.x
- Spring MVC
- Spring Security / OAuth2 Resource Server
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
→ personalized daily goal projection
→ ENERGY credit
→ production home snapshot
→ ENERGY debit
→ first event READY and resolution
→ transition to second node
→ second event READY and resolution
→ persistent pilot XP + pet bond + material inventory
→ expedition COMPLETED
```

Activity sync сериализуется advisory transaction lock по пользователю. Advance и event resolution используют lock по пользователю и экспедиции. Economy блокирует wallet row через `FOR UPDATE`.

## Локальный запуск

```bash
docker compose up -d postgres
cd backend
SPRING_PROFILES_ACTIVE=local ./mvnw spring-boot:run
```

Windows:

```powershell
docker compose up -d postgres
cd backend
$env:SPRING_PROFILES_ACTIVE = "local"
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
- event choices, переход между узлами и persistent pilot/pet progression;
- повторное/конфликтное resolution и inventory source protection;
- rollback activity/economy/expedition/progression/inventory при поздней ошибке;
- production home read-model до, между и после двух событий;
- Flyway upgrade `starter-v1 → starter-v2` без повторной material reward;
- default/adaptive daily goal, окно предыдущих дней и исключение текущего дня.

## Персональная дневная цель

`GET /api/v1/home` больше не возвращает один глобальный порог. Backend вычисляет цель из предыдущей accepted activity history:

```text
previous 7 local days
→ positive accepted_total values
→ median × 1.05
→ round to 250
→ clamp 2000..12000
```

Если собрано меньше трёх валидных дней, используется `6000`. Текущий день не участвует в собственной цели. Расчёт read-only: отдельные goal rows не создаются. Response содержит `dailyGoal` и `dailyGoalPolicy`, чтобы mobile мог объяснить пользователю источник цели.

Параметры переопределяются переменными окружения:

```text
DAILY_GOAL_POLICY_VERSION
DAILY_GOAL_LOOKBACK_DAYS
DAILY_GOAL_MINIMUM_SAMPLE_DAYS
DAILY_GOAL_DEFAULT
DAILY_GOAL_MINIMUM
DAILY_GOAL_MAXIMUM
DAILY_GOAL_GROWTH_PERCENT
DAILY_GOAL_ROUNDING_STEP
```

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

## Authentication

Backend по умолчанию запускается fail-closed в режиме `jwt`. Production identity берётся только из проверенного OIDC access token:

```http
Authorization: Bearer <access-token>
```

- `sub` → канонический `userId`;
- `preferred_username` (настраивается) → audit actor;
- role/scope claims → `ROLE_USER` и `ROLE_ADMIN`;
- подписанный device/session claim → хэшированный `deviceId` для activity sync;
- `/api/v1/admin/**` требует `ROLE_ADMIN`;
- остальные защищённые `/api/v1/**` требуют `ROLE_USER`.

Локальный профиль `local` явно включает `dev-header`. Только в этом режиме разрешены:

```text
X-User-Id
X-Device-Id
X-Mock-User
X-Mock-Authorities
```

`application-prod.yml` принудительно включает JWT и отключает demo endpoint. Для production нужны `OIDC_ISSUER_URI`, `OIDC_JWK_SET_URI` и `OIDC_AUDIENCE`. Полная модель зафиксирована в `docs/adr/0017-production-authentication-boundary.md`.

Следующие curl-примеры предназначены для локального профиля `local`.

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

### Два узла стартовой экспедиции

Один и тот же endpoint используется для обоих узлов:

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

Порядок `starter-v2`:

```text
outer-beacon   — 30 ENERGY → signal-source-v1
lumen-gate     — 45 ENERGY → echo-vault-v1
```

После разрешения первого события progress атомарно переключается на второй узел с нулевой энергией. После второго события экспедиция получает `COMPLETED`.

### Разрешение событий и material reward

Первое событие продолжает экспедицию:

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

Второе событие завершает экспедицию и выдаёт материал:

```bash
curl -X POST \
  http://localhost:8080/api/v1/events/echo-vault-v1/resolve \
  -H 'Content-Type: application/json' \
  -H 'X-User-Id: demo-user-1' \
  -d '{
    "choiceId": "stabilize-core",
    "idempotencyKey": "echo-vault-v1-resolution-1"
  }'
```

Фрагмент response второго события:

```json
{
  "contentVersion": "starter-v2",
  "expeditionStatus": "COMPLETED",
  "eventId": "echo-vault-v1",
  "choiceId": "stabilize-core",
  "material": {
    "itemId": "lumen-shard",
    "name": "Люминовый осколок",
    "description": "Стабильный фрагмент светового ядра, пригодный для будущих улучшений.",
    "quantityGained": 2,
    "quantityAfter": 2,
    "version": 1
  }
}
```

`stabilize-core` выдаёт 2 `lumen-shard`; `follow-echo` — 1 `echo-thread`. Immutable response хранит material snapshot, а текущий stack возвращается через `GET /home`.

## Что сохраняется

```text
app_user                       — canonical OIDC subject и runtime user state
app_device                     — устройство пользователя
activity_sync_state            — дневной accepted total
processed_activity_sync        — idempotent activity/economy response
economy_wallet                 — текущий баланс ENERGY и версия
economy_ledger                 — append-only credit/debit журнал
expedition_progress            — progress/status стартовой экспедиции
processed_expedition_advance   — idempotent expedition/economy response
pilot_progress                 — уровень и опыт пилота
pet_progress                   — уровень и bond питомца
processed_event_resolution     — idempotent event/progression/material response
inventory_stack                 — текущий material stack
inventory_ledger                — append-only material reward journal
```

## Инварианты

- клиент не задаёт итоговую награду;
- баланс меняется только через ledger;
- wallet не может стать отрицательным;
- один economy source создаёт не более одной ledger-записи;
- один command key не создаёт повторное изменение состояния;
- key с другим payload возвращает `IDEMPOTENCY_CONFLICT`;
- event разрешается только из `EVENT_READY`;
- progression, inventory reward и expedition transition/completion фиксируются одной транзакцией;
- `GET /home` не создаёт данные или goal snapshots;
- текущий локальный день не участвует в собственной daily goal.

## Текущие ограничения

- mobile OIDC login/refresh/logout и secure token storage ещё не подключены;
- attestation не проверяется;
- одна экспедиция с двумя узлами и двумя событиями;
- content definition хранится в коде;
- inventory поддерживает только положительные stackable material rewards; расход и unique items отсутствуют;
- HealthKit/Health Connect требуют проверки на физических устройствах;
- отдельный inventory endpoint и offline read cache отсутствуют.
