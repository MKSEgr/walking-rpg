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
→ atomic material debit + persistent unique item
→ persistent equipment slot + exact equip/unequip replay
→ equipment-gated optional route
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
- cohort-filtered compass funnel, server-authoritative gameplay stages,
  out-of-order quality counters и repeatable-read snapshot isolation;
- capability-gated durable event receipt, `pendingEventResult`, owner-scoped
  idempotent acknowledgement и gameplay gate до ACK;
- Flyway V10: legacy/backfilled writers auto-acknowledged, а capable results
  остаются pending;
- Flyway V11: explicit ACK атомарно создаёт immutable authoritative milestone,
  а legacy auto-ACK остаётся backfilled и не искажает timing.
- Flyway V12 отключает development capabilities во всех сохранённых remote
  configs; provider/profile guards и exact idempotency replay проверяются
  отдельными unit/integration tests.
- Flyway V13 разрешает audited material debit при неотрицательном остатке,
  создаёт unique inventory/crafting response tables и проверяется upgrade- и
  concurrency-тестами.
- Flyway V14 создаёт owned equipment slot/processed response, single-slot
  uniqueness и staged inactive `chapter-1-v2`; upgrade, release activation,
  event prerequisite и account/event concurrency проверяются отдельными
  PostgreSQL tests.
- Flyway V15 отделяет immutable время первой активации content version от
  mutable времени публикации; DB trigger, upgrade test и analytics regression
  запрещают republish сдвигать route baseline. Если v2 уже публиковалась на
  V14, upgrade fail-closed требует явно восстановить первую активацию из
  rollout/audit evidence и не принимает mutable `created_at` как источник.
- Flyway V16 добавляет receipt-time retention index, а V17 сохраняет cosmetic
  loadout независимо по `PILOT`/`PET`/`PROFILE`, backfill-ит известный legacy
  selection и покрывается restart/upgrade/account/backup tests.
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
POST /api/v1/crafting/recipes/{recipeId}/craft
POST /api/v1/equipment/slots/{slotId}/equip
POST /api/v1/equipment/slots/{slotId}/unequip
GET  /api/v1/platform
POST /api/v1/platform/commands
GET  /api/v1/admin/platform/analytics/first-journey?cohortCode=alpha-1
GET  /api/v1/admin/platform/analytics/compass-journey?cohortCode=compass-beta
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

Backend принимает текущую и прошлую `localDate` в заявленной IANA `timeZone`,
но отклоняет ещё не наступившую локальную дату до создания identity, activity
state или ENERGY ledger entry. Числовые fixed offsets не заменяют IANA/TZDB ID
и отклоняются на request boundary.

### Первая глава стартовой экспедиции

Один и тот же endpoint используется для 18 основных узлов и опционального:

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

Начало `chapter-1-v2`:

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
  "contentVersion": "chapter-1-v2",
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
экспедиции, backend отклоняет новый expedition advance, новый event resolution
и новую crafting mutation кодом
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

### Compass beta analytics

Network Home регистрирует recipe/route state командой
`RECORD_COMPASS_IMPRESSION`. Backend принимает только известный enum,
канонизирует content IDs и сохраняет server receive time; route telemetry
допустима только после cluster-wide активации `chapter-1-v2`. Exact replay не
создаёт второе событие. Команда обходит reconciliation/persistence platform
state, не материализует новые progress facts и не меняет `stateVersion`.
Cached/off-viewport/covered/background Home ничего не отправляет, а mobile
обрабатывает команду в cache-neutral `TELEMETRY` lane отдельно от gameplay.
Fingerprint platform payload рекурсивно сортирует JSON object keys, поэтому
тот же compass/exposure payload replay-ится после restart и между instances
даже при другом порядке полей; arrays и scalar values/types остаются значимыми.
Bounded compatibility path принимает оба исторических порядка объявленных
двухполевых payload без сохранения raw request.

Admin endpoint `/api/v1/admin/platform/analytics/compass-journey` объединяет
эти client-reported показы с фактами существующих
`unique_inventory_item`/`processed_*` rows. `CRAFTED`, `EQUIPPED`, достижение
mirror event, выбор и завершение route никогда не выводятся из telemetry.
Route baseline существует только при активной `chapter-1-v2`: ожидавший на
Mirror Delta пользователь стартует в `content_release.activated_at`, достигший
позже — в receipt time, а resolved до активации legacy event исключается.
Опциональный `cohortCode` ограничивает eligible users; весь ответ строится в
одном `REPEATABLE_READ` snapshot. Conversion включает достигнутые
out-of-order пары, но p50/p90 считает только target не раньше baseline; обе
аномалии и target без baseline возвращаются как data-quality counters.
Code-complete endpoint не заменяет реальный beta evidence.

### Crafting, equipment и resonance route

Recipe `resonance-compass-v1` атомарно списывает `2 × lumen-shard` и
`1 × echo-thread`, создаёт unique item instance и сохраняет exact response.
После этого item можно поместить в единственный starter slot `NAVIGATION`:

```bash
curl -X POST \
  http://localhost:8080/api/v1/equipment/slots/NAVIGATION/equip \
  -H 'Content-Type: application/json' \
  -H 'X-User-Id: demo-user-1' \
  -d '{
    "itemInstanceId": "33333333-3333-3333-3333-333333333333",
    "idempotencyKey": "equip-navigation-1"
  }'
```

Unequip использует тот же request contract с `itemInstanceId: null` и новым
key. Обе операции имеют desired-state semantics: повтор exact command
возвращает исходный response, а новый key для уже достигнутого состояния
возвращает `changed = false`. Item должен принадлежать authenticated user,
соответствовать slot content и не может занимать два slot.

Новая equipment mutation получает account/equipment locks, сохраняет exact
replay доступным, затем входит в общий expedition serialization boundary и
проверяет pending event receipt. В `mirror-delta-v1` backend под тем же
expedition lock читает committed equipment: `follow-resonance` требует
`resonance-compass` в `NAVIGATION` и ведёт в `resonance-pocket`; обычный choice
сохраняет переход в `storm-archive`. Optional node после resolution также
возвращается в `storm-archive`.
До отдельной admin-активации v2 после drain старого backend pool Home не
проецирует gated choice, а event API отклоняет прямую новую resolution; exact
replay остаётся перед release gate.

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
inventory_ledger                — append-only material credit/debit journal
unique_inventory_item           — persistent non-stackable crafted item
processed_crafting_command      — immutable exact crafting response
processed_crafting_ingredient   — immutable consumed-stack snapshots
equipment_slot_state            — persistent owned equipment loadout
processed_equipment_command     — immutable exact equip/unequip response
```

## Инварианты

- клиент не задаёт итоговую награду;
- баланс меняется только через ledger;
- wallet не может стать отрицательным;
- один economy source создаёт не более одной ledger-записи;
- один command key не создаёт повторное изменение состояния;
- key с другим payload возвращает `IDEMPOTENCY_CONFLICT`;
- event разрешается только из `EVENT_READY`;
- pending capable event receipt блокирует следующий advance/resolution и новые
  crafting/equipment mutations до явного ACK; exact replay уже выполненных
  команд остаётся доступен, legacy delivery auto-acknowledged;
- acknowledgement scoped только authenticated user + `receiptId`, не имеет
  request body и возвращает стабильное время первого ACK;
- progression, inventory reward и expedition transition/completion фиксируются одной транзакцией;
- crafting списывает все ingredients, пишет debit audit, создаёт unique item и
  processed response одной транзакцией;
- equipment slot ссылается только на unique item того же user, один item не
  занимает два slot, а state и processed response фиксируются одним commit;
- gated choice повторно проверяет equipment под expedition lock; home
  availability является только read projection;
- material quantity и `quantity_after` не становятся отрицательными;
- `GET /home` не создаёт данные или goal snapshots;
- текущий локальный день не участвует в собственной daily goal.

## Текущие ограничения

- production IdP ещё требует client/redirect/issuer configuration;
- attestation/risk работает в shadow mode без blocking enforcement;
- первая глава имеет одну equipment-gated optional ветку; другие nonlinear
  routes пока отсутствуют;
- content definitions поставляются с backend, а release/config управляются
  versioned platform state;
- starter crafting ограничен одним versioned recipe/unique item; rarity,
  upgrades, dismantling и operator-authored recipes отсутствуют;
- HealthKit/Health Connect требуют проверки на физических устройствах;
- отдельный inventory endpoint отсутствует; mobile читает stack через home.
