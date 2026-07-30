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
→ atomic transition + durable result receipt
→ pending result in home
→ bodyless receipt acknowledgement
→ следующие content-driven узлы
→ persistent pilot XP + active-pet bond + material inventory
→ chapter completion
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

Sandbox payment и development push включаются только сочетанием профиля
`local|test` и явного provider mode:

```text
PAYMENT_PROVIDER=sandbox
PUSH_PROVIDER=development
```

Без этого backend регистрирует fail-closed providers. Профили `prod` и `stage`
запрещают development providers независимо от внешнего override.

## Production/stage configuration

Пример обязательных переменных находится в `.env.production.example`.
Защищённые профили проверяются до создания `DataSource` и запуска Flyway:

- одновременно активен ровно один из `prod|stage`, без `local|test`;
- `spring.datasource.url` использует один канонический DNS host и единственный
  raw query `sslmode=verify-full`;
- JDBC URL не содержит credentials, alias/encoded/duplicate parameters или
  multi-host transport;
- Hikari/Flyway не переопределяют URL, credentials, driver, JDBC properties
  или внешний Hikari configuration file;
- production database user не является локальным/default superuser;
- payment и push provider modes равны `disabled`.
- management listener отделён от application port и привязан к loopback;
- health/metrics exposure, HTTP/JDBC/transaction/shutdown timeouts и anonymous
  diagnostics/telemetry ceilings не могут быть ослаблены external override.

Небезопасная конфигурация останавливает процесс на environment-preparation
этапе, до сетевого подключения к БД или применения миграций.

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
- active pet selection, независимый pet progression и выбранный питомец в home;
- транзакционную синхронизацию quest/evolution/event rewards одного питомца;
- повторное/конфликтное resolution и inventory source protection;
- rollback activity/economy/expedition/progression/inventory при поздней ошибке;
- production home read-model до, между и после двух событий;
- Flyway upgrade `starter-v1 → starter-v2` без повторной material reward;
- default/adaptive daily goal, окно предыдущих дней и исключение текущего дня;
- V9 exact-once milestones первого пути, migration backfill и cascade deletion;
- cohort-filtered first-journey conversion и authoritative p50/p90 timing;
- capability-gated durable event receipt, `pendingEventResult`, owner-scoped
  idempotent acknowledgement и gameplay gate до ACK;
- Flyway V10: legacy/backfilled writers auto-acknowledged, а capable results
  остаются pending;
- Flyway V11: explicit ACK атомарно создаёт immutable authoritative milestone,
  а legacy auto-ACK остаётся backfilled и не искажает timing.
- Flyway V12 отключает development capabilities во всех сохранённых remote
  configs; provider/profile guards и exact idempotency replay проверяются
  отдельными unit/integration tests.
- operational integration проверяет main-port `/livez`/`readyz`, PostgreSQL в
  readiness, скрытые health details и admin-only Prometheus;
- synthetic PostgreSQL 17.10 backup/restore drill сверяет archive checksum,
  Flyway version и schema/data/sequence manifests на fresh target. Он не
  заменяет датированный restore реального production backup.

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
GET  /livez
GET  /readyz
GET  127.0.0.1:8081/actuator/health/{liveness,readiness}
GET  127.0.0.1:8081/actuator/prometheus (ROLE_ADMIN)
GET  /api/v1/system/info
GET  /api/v1/home/demo
GET  /api/v1/home?localDate=YYYY-MM-DD
POST /api/v1/activity/sync
POST /api/v1/expeditions/{expeditionId}/advance
POST /api/v1/events/{eventId}/resolve
POST /api/v1/event-results/{receiptId}/acknowledge
GET  /api/v1/platform
POST /api/v1/platform/commands
GET  /api/v1/admin/platform/analytics/first-journey?cohortCode=alpha-1
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
Чтобы примеры durable result возвращали `handoffRequired = true`, single-node
локальный backend запускается с
`DURABLE_EVENT_RESULT_HANDOFF_ENABLED=true`. Значение по умолчанию `false`
предназначено для безопасного cluster rollout.

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

### Первая глава стартовой экспедиции

Один и тот же endpoint используется для всех 18 узлов:

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

Начало `chapter-1-v1`:

```text
outer-beacon   — 30 ENERGY → signal-source-v1
lumen-gate     — 45 ENERGY → echo-vault-v1
ash-orbit      — 55 ENERGY → ash-orbit-v1
...
dawn-relay     — 130 ENERGY → dawn-relay-v1
```

После каждого промежуточного события progress атомарно переключается на
следующий узел с нулевой энергией. Только событие `dawn-relay-v1` переводит
экспедицию в `COMPLETED`.

### Разрешение событий и material reward

Первое событие продолжает экспедицию:

```bash
curl -X POST \
  http://localhost:8080/api/v1/events/signal-source-v1/resolve \
  -H 'Content-Type: application/json' \
  -H 'X-Walking-RPG-Capabilities: durable-event-result-v1' \
  -H 'X-User-Id: demo-user-1' \
  -d '{
    "choiceId": "analyze-signal",
    "idempotencyKey": "signal-source-v1-resolution-1"
  }'
```

Второе событие продолжает экспедицию и выдаёт материал:

```bash
curl -X POST \
  http://localhost:8080/api/v1/events/echo-vault-v1/resolve \
  -H 'Content-Type: application/json' \
  -H 'X-Walking-RPG-Capabilities: durable-event-result-v1' \
  -H 'X-User-Id: demo-user-1' \
  -d '{
    "choiceId": "stabilize-core",
    "idempotencyKey": "echo-vault-v1-resolution-1"
  }'
```

Фрагмент response второго события:

```json
{
  "receiptId": "22222222-2222-2222-2222-222222222222",
  "contentVersion": "chapter-1-v1",
  "expeditionStatus": "IN_PROGRESS",
  "eventId": "echo-vault-v1",
  "choiceId": "stabilize-core",
  "handoffRequired": true,
  "material": {
    "itemId": "lumen-shard",
    "name": "Люминовый осколок",
    "description": "Стабильный фрагмент светового ядра, пригодный для будущих улучшений.",
    "quantityGained": 2,
    "quantityAfter": 2,
    "version": 1
  },
  "nextNode": {
    "nodeId": "ash-orbit",
    "name": "Пепельная орбита"
  }
}
```

`stabilize-core` выдаёт 2 `lumen-shard`; `follow-echo` — 1 `echo-thread`.
Immutable response хранит material snapshot и следующий узел, а текущий stack
возвращается через `GET /home`.

### Durable результат события

Event resolution с capability
`X-Walking-RPG-Capabilities: durable-event-result-v1` и cluster gate
`DURABLE_EVENT_RESULT_HANDOFF_ENABLED=true` сохраняет `receiptId`,
`handoffRequired = true`, reward snapshot и nullable `nextNode` в той же
транзакции, что и progression, inventory и переход экспедиции. Пока receipt не
подтверждён, `GET /api/v1/home` возвращает top-level `pendingEventResult`.
Потеря HTTP response или restart mobile поэтому не скрывают уже начисленную
награду.

Acknowledgement не принимает body:

```bash
curl -X POST \
  http://localhost:8080/api/v1/event-results/22222222-2222-2222-2222-222222222222/acknowledge \
  -H 'Accept: application/json' \
  -H 'X-User-Id: demo-user-1'
```

```json
{
  "receiptId": "22222222-2222-2222-2222-222222222222",
  "eventId": "echo-vault-v1",
  "status": "ACKNOWLEDGED",
  "acknowledgedAt": "2026-07-26T07:01:00Z",
  "serverTime": "2026-07-26T07:01:00Z"
}
```

`receiptId` — единственный server-side idempotency scope. Replay возвращает
стабильные `acknowledgedAt` и `serverTime`. Чужой или неизвестный receipt
возвращает `404 EVENT_RESULT_NOT_FOUND`. Пока есть pending receipt этой
экспедиции, backend отклоняет новый expedition advance и новый event resolution
кодом
`409 EVENT_RESULT_ACKNOWLEDGEMENT_REQUIRED`; ACK не меняет progression,
inventory или expedition второй раз.

Запрос без capability или при выключенном activation gate остаётся совместимым
со старым mobile: `handoffRequired = false`, receipt физически
auto-acknowledged и не попадает в home pending projection или gameplay gate.
Exact replay сохраняет mode первого запроса, даже если повтор пришёл с другим
набором capabilities. V10 trigger применяет тот же auto-ACK к `INSERT` старого
backend. Новый mobile принимает legacy response без `receiptId`,
`handoffRequired` и `nextNode` и не отправляет ACK.

Безопасный deploy: применить V10, развернуть новый backend с
`DURABLE_EVENT_RESULT_HANDOFF_ENABLED=false`, обновить mobile, полностью
вывести старые backend instances и только затем включить gate на новом пуле.
После активации старый backend нельзя возвращать в pool. Для rollback сначала
выключить gate на всех новых instances и дождаться нуля:

```sql
SELECT count(*)
FROM processed_event_resolution
WHERE handoff_required
  AND acknowledged_at IS NULL;
```

Только после этого разрешён rollback на старый binary. Pending result, уже
созданный capable-клиентом, требует capable-клиента для подтверждения.

V11 связывает первый успешный `NULL → acknowledged_at` с
`FIRST_EVENT_RESULT_ACKNOWLEDGED`. Explicit durable ACK участвует в
first-journey p50/p90; legacy auto-ACK и migration evidence видны только как
`BACKFILLED` conversion. Установленное время ACK неизменяемо, а exact replay не
выполняет повторный physical update.

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
processed_event_resolution     — immutable event result, receipt/next node и ACK state
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
- pending capable event receipt блокирует следующий advance/resolution той же
  экспедиции до явного ACK; legacy delivery auto-acknowledged;
- acknowledgement scoped только authenticated user + `receiptId`, не имеет
  request body и возвращает стабильное время первого ACK;
- progression, inventory reward и expedition transition/completion фиксируются одной транзакцией;
- `GET /home` не создаёт данные или goal snapshots;
- текущий локальный день не участвует в собственной daily goal.

## Текущие ограничения

- production IdP ещё требует client/redirect/issuer configuration;
- attestation/risk работает в shadow mode без blocking enforcement;
- одна последовательная глава без нелинейных веток;
- content definitions поставляются с backend, а release/config управляются
  versioned platform state;
- inventory поддерживает только положительные stackable material rewards; расход и unique items отсутствуют;
- HealthKit/Health Connect требуют проверки на физических устройствах;
- отдельный inventory endpoint отсутствует; mobile читает stack через home.
