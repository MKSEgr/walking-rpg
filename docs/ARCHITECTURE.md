# Архитектура Walking RPG

## 1. Контекст и принципы

Проект развивается небольшой командой и поставляется проверяемыми вертикальными срезами.

- монорепозиторий;
- Flutter mobile;
- Java 21 / Spring Boot;
- PostgreSQL + Flyway;
- модульный монолит;
- REST/JSON;
- server-authoritative economy/content/progression;
- durable foreground command outbox;
- внешние providers за интерфейсами;
- Redis, broker и микросервисы только по измеренной необходимости.

## 2. Backend-модули

```text
security       — OIDC/JWT resource server, authorities и request identity
identity       — runtime users и pseudonymous device/session keys
activity       — cumulative activity, high-watermark и retention
goal           — персональная дневная цель
economy        — wallet и append-only ledger
expedition     — узлы, события и прохождение
progression    — pilot XP и pet bond
inventory      — material stack и credit/debit ledger
crafting       — versioned recipes, material consumption и unique items
equipment      — persistent loadout, ownership и exact equip/unequip replay
home           — агрегированный read model
platform       — onboarding, pets, skills, quests, season, squads, cosmetics, experiments
content        — versioned server-owned releases
risk           — anti-fraud signals, score и audit trail
shared         — общие API/error/transaction primitives
```

Пакеты группируются по функциональности, а не в глобальные слои controller/service/repository.

## 3. Mobile-модули

```text
core/config          — compile-time environment
core/commands        — durable commands, lanes, replay и safe recovery projection
core/cache           — read-only validated server snapshots
activity             — HealthKit/Health Connect и sync
home                 — authoritative home snapshot
expedition           — ENERGY spend
event                — event resolution, durable result и acknowledgement
crafting             — server recipe command/result
equipment            — durable equip/unequip command/result
onboarding            — guided first journey и recovery milestones
platform             — typed snapshot, commands и «Путевой журнал»
recovery             — owner-scoped UI сохранённых действий
app                   — навигационный shell
```

Android- и iOS-host проекты versioned в репозитории.

## 4. Сквозной activity flow

```text
HealthKit / Health Connect
→ aggregated steps за local day
→ persist ACTIVITY_SYNC payload + idempotency key
→ POST /api/v1/activity/sync
→ advisory lock user
→ positive delta
→ ENERGY credit + ledger
→ activity state + immutable response
→ authoritative GET /home
```

Mobile не отправляет сырые health samples и не вычисляет награду.
Shadow-mode risk evaluator проверяет aggregate bucket metadata checked
арифметикой. Переполнение суммы является `BUCKET_TOTAL_MISMATCH`, а порог
резкого `8×` роста вычисляется только когда multiplication представима в
`long`; wraparound не может понизить или искусственно поднять risk score.
Exact replay activity-команды действует в пределах retention durable receipt.
Новая ENERGY ledger entry адресуется `v2:<requestFingerprint>`, поэтому reuse
того же transport key после очистки receipt создаёт отдельную operation
generation вместо возврата старого wallet snapshot. Дневной high-watermark
остаётся долгоживущей защитой от повторного начисления принятых шагов; сырой
health payload в append-only ledger не переносится.

## 5. Durable mobile commands

```text
ACTIVITY
└── ACTIVITY_SYNC

GAMEPLAY
├── EXPEDITION_ADVANCE
├── EVENT_RESOLUTION
├── EVENT_RESULT_ACKNOWLEDGEMENT
├── CRAFTING
├── EQUIPMENT
└── state-changing PLATFORM_COMMAND

TELEMETRY
└── PLATFORM_COMMAND(RECORD_EXPERIMENT_EXPOSURE)
```

Все команды сохраняются до первой сетевой попытки. Retry использует тот же
payload и idempotency key. Подтверждённый terminal 4xx переводит конкретную
команду в `FAILED`, а transport/408/429/5xx остаются `PENDING`. Внутри lane
сохраняется FIFO. Replay сначала завершает `ACTIVITY`, затем `GAMEPLAY`, чтобы
ENERGY credit не гонялся с debit. Retryable ACTIVITY является барьером:
GAMEPLAY не вызывается и остаётся `PENDING`; `TELEMETRY` выполняется
параллельно с этой цепочкой как close-tracked операция, но не удерживает
завершение startup replay и первый экран. Явный Recovery retry ожидает все
lane. Exposure lane выводится из
сохранённого payload, поэтому старый v1 record изолируется без миграции store.

Platform snapshot содержит onboarding, три питомца, skills, quests, achievements, season, weekly route, squad, cosmetics, experiments и remote config. `equippedCosmetics` является additive server-owned mapping `PILOT`/`PET`/`PROFILE → cosmeticId`; legacy `activeCosmeticId` остаётся указателем на последний выбор для старого клиента. После успешной команды UI заменяет состояние snapshot-ом backend и перечитывает home; optimistic rewards не применяются.

Authenticated shell выполняет startup replay ровно в одном месте, а runtime
memoize-ит его Future до завершения authenticated session. После первой
попытки resume/reload перечитывают только authoritative state и не создают
новую сетевую попытку; завершённый report/error claim-ится первым всё ещё
активным UI-владельцем один раз. Remount во время replay принимает outcome, а
remount после его обработки не переинтерпретирует историю. Новый runtime после
process restart или 401 reauthentication получает новый startup replay.
`ActivitySyncShell`
по умолчанию не владеет replay и требует injected session runtime для явного
opt-in. Закрытый или заменённый runtime прекращает stale presentation
continuation без новых owner-scoped Home/Platform reads.
Recovery center показывает owner-scoped тип, состояние, попытки, coarse
category и время, но не payload, key, fingerprint, receipt, Health cursor,
raw error или filesystem path. `PENDING` разрешено только повторить исходной
командой и
нельзя удалить; `FAILED` не retry-ится, но его локальную диагностическую запись
можно убрать после подтверждения. Успешное восстановление инвалидирует
экранный generation и перечитывает authoritative state без повторного startup
replay или перемонтирования завершённого main shell. Выход сессии из
`authenticated` закрывает owner-scoped overlay routes. Corrupt store остаётся
fail-closed и не сбрасывается UI.

Результат события имеет отдельный durable handoff:

```text
POST /events/{eventId}/resolve
+ X-Walking-RPG-Capabilities: durable-event-result-v1
+ DURABLE_EVENT_RESULT_HANDOFF_ENABLED=true
→ atomic rewards + expedition transition + immutable receipt/nextNode
→ response handoffRequired=true или GET /home.pendingEventResult
→ restart-visible result card
→ persist EVENT_RESULT_ACKNOWLEDGEMENT(receiptId)
→ bodyless POST /event-results/{receiptId}/acknowledge
→ stable ACK response + authoritative home reload
```

`receiptId` — единственный server-side idempotency scope ACK. Пока receipt
pending, backend возвращает `409 EVENT_RESULT_ACKNOWLEDGEMENT_REQUIRED` для
нового advance/resolution, поэтому результат нельзя перепрыгнуть прямым
API-вызовом. Cached home может показывать карточку, но не разрешает
acknowledgement.

Capability отсутствует у старого mobile или cluster activation gate выключен:
backend сохраняет `handoff_required = false`, а V10 trigger сразу выставляет
`acknowledged_at = server_time`. Такой result не попадает в pending projection
или gameplay gate. Новый mobile допускает legacy response старого backend без
receipt/handoff fields и решает, нужен ли ACK, по response
`handoffRequired`. Exact replay сохраняет mode первого запроса. Pending,
созданный capable-клиентом, требует capable-клиента и не обходится старым
устройством.

Activation gate остаётся false во время V10/new-backend/new-mobile rollout.
После drain всех старых backend instances его можно включить на новом пуле.
Rollback на старый binary допустим только после выключения gate и достижения
нуля capable pending rows. Поэтому потерянный response никогда не replay-ится
через старый DTO после появления первого durable receipt.

`FirstJourneyGate` собирает первые действия в один непрерывный маршрут:

```text
welcome
→ health permission + authoritative sync
→ ENERGY reward
→ SELECT_PET
→ expedition advance
→ event resolution
→ durable result acknowledgement
→ main shell
```

Milestones не являются самостоятельными пользовательскими действиями. Mobile
записывает их после реальных команд, допускает «Продолжить позже» и после
restart восстанавливает подтверждаемые этапы из home/platform facts. Haptic
feedback не входит в критический путь и не может задержать authoritative
reload.

Первый путь имеет отдельную durable observability projection
`first_journey_milestone`. PostgreSQL triggers фиксируют первый успешный
activity sync, ENERGY из activity ledger, выбор питомца, узел, событие и
завершение onboarding в тех же транзакциях, что и source-of-truth операции.
V11 дополнительно фиксирует первый `NULL → acknowledged_at` как
`FIRST_EVENT_RESULT_ACKNOWLEDGED` в транзакции ACK. Unique
`(user_id, milestone)` делает replay безопасным. Explicit durable ACK имеет
`AUTHORITATIVE` source; legacy auto-ACK и migration evidence помечены
`BACKFILLED` и исключаются из time-to-value percentiles.

Compass beta observability не создаёт второй gameplay source of truth.
Network Home отправляет idempotent `RECORD_COMPASS_IMPRESSION`, только когда
соответствующая card пересекает viewport, Home route текущая и app `resumed`;
backend канонизирует recipe/event/choice IDs, использует server receive time и
пишет `platform_event`. Cached/covered/background Home ничего не отправляет.
Эта команда выполняется в отдельной mobile `TELEMETRY` lane, не инвалидирует
read cache и не задерживает ACTIVITY/GAMEPLAY. Backend выполняет её до
`roadmap_user_state` reconciliation:
новые progress facts не сохраняются и `stateVersion` не меняется. Route
impression дополнительно требует уже активную `chapter-1-v2`; exact replay
читается до release gate.
Публичный `/telemetry/events` отклоняет оба compass event name до любой записи,
поэтому client-controlled `occurredAt` не может попасть в canonical funnel.

`CompassJourneyAnalyticsService` объединяет client-reported первые показы с
authoritative фактами из `unique_inventory_item`,
`processed_equipment_command`, `processed_expedition_advance` и
`processed_event_resolution`. Cohort-filtered admin response агрегирован без
user IDs и строится одной `REPEATABLE_READ` транзакцией. Conversion сохраняет
достигнутые out-of-order пары, но latency считает только неотрицательные
интервалы; target без baseline и out-of-order видны как data-quality counters.
Route baseline существует только для активной `chapter-1-v2`, начинается не
раньше immutable `content_release.activated_at` и исключает Mirror Delta, resolved до
активации; legacy receipts не входят в denominator нового выбора.
Новая таблица не нужна: при объёме закрытой beta существующие immutable rows и
индексы являются достаточной read boundary.

`roadmap_user_state.activePetId` — источник выбора питомца. Общий
`ActivePetProvider` связывает platform state с home/progression: event reward
берёт тот же per-user advisory lock, что и `SELECT_PET`, затем блокирует и
изменяет строку выбранного `pet_id`; pilot XP остаётся общим. Quest bond и
evolution level синхронизируются с той же `pet_progress` строкой в транзакции
platform-команды. Для старого раздвоенного состояния read/reward использует
максимальные подтверждённые level/bond. Отсутствующее platform state безопасно
использует `spark-v1`.

## 6. Контент

Активная версия `chapter-1-v2` содержит 18 основных узлов от `outer-beacon` до
`dawn-relay` и опциональный `resonance-pocket`. Обычные choices события
`mirror-delta-v1` ведут в `storm-archive`, а `follow-resonance` требует
экипированный `resonance-compass` и ведёт через optional node. Stable IDs
сохраняются между версиями; mutable user state отделён от definitions.
`content_release` и remote config позволяют публиковать активную версию без
переписывания исторических command responses.
Live platform snapshot и bootstrap сначала читают один effective remote config,
а затем проецируют из него `seasonId` и `weeklyRouteEnergy` в catalog. Поэтому
catalog, user-state threshold и remote config не расходятся при clean install
или admin publication; runtime values участвуют в `catalogDigest`. Уже
сохранённый command response остаётся immutable и replay-ится с исходной
проекцией.
Новая platform-команда после user lock также фиксирует один effective config и
одну active content version, затем передаёт их через provider/feature gates,
mutation, route-impression validation, derived achievements и response
projection. Она не использует `REPEATABLE_READ`, потому что ожидающая user lock
транзакция обязана увидеть commit предыдущей команды; вместо этого runtime
публикации замораживаются явно. Конкурентная публикация применяется целиком со
следующего request, а не смешивает две версии внутри одного durable command
response. Command `serverTime` снимается после frozen runtime reads, поэтому
route impression, принятый на новой active content version, не попадает в
funnel с timestamp раньше наблюдаемой activation. Для `CREATE_SQUAD`,
`JOIN_SQUAD` и `LEAVE_SQUAD` после этих reads дополнительно захватывается общий
squad lock, и только затем снимается единое время membership, platform state,
audit event и durable response.
Remote config и content release используют разные transaction-scoped advisory
locks перед схемой `deactivate current → activate next`. Конкурентные admin
requests одного типа сериализуются между backend instances, а независимые типы
публикаций не блокируют друг друга. Partial unique indexes остаются последней
DB-защитой single-active инварианта, а не механизмом обработки штатной гонки.
V14 лишь stage-ит v2 и оставляет v1 активной. Пока оператор не активировал v2
после полного drain старого backend pool, новый backend возвращает v1/18 nodes,
не проецирует `follow-resonance` и отклоняет прямой переход. Exact replay
исторического результата выполняется до release gate.
V15 добавляет nullable `activated_at`: активная версия обязана иметь timestamp,
первая активация staged row заполняет его, а DB trigger запрещает последующее
изменение. `created_at` остаётся временем последней публикации и не участвует в
накопительном route funnel.

Platform command payload и remote config остаются JSON, но server-owned
числовые поля проходят exact integer conversion. Дробные и выходящие за
диапазон значения отклоняются до mutation; уже сохранённый некорректный
`weeklyRouteEnergy` не усекается, а безопасно заменяется значением по умолчанию.

Starter crafting content имеет независимую версию `crafting-v1`. Recipe
`resonance-compass-v1` принимает только stable material item IDs и создаёт
non-stackable `resonance-compass`. Client получает recipe projection через
home, но не задаёт стоимость, количество или результат command-а.

Equipment content имеет независимую версию `equipment-v1`: slot
`NAVIGATION` принимает unique `resonance-compass`. Home availability является
UX projection; locked choices вынесены в additive `lockedChoices`, чтобы
legacy mobile видел только основной маршрут. Event service повторно проверяет
requirement под authoritative expedition lock.

## 7. Схема данных

Основные таблицы:

```text
app_user, app_device
  └─ has_successful_activity_sync — monotonic fact реального activity sync
activity_sync_state, processed_activity_sync
economy_wallet, economy_ledger
expedition_progress, processed_expedition_advance
pilot_progress, pet_progress
processed_event_resolution
  └─ receipt_id, handoff_required, next_node_*, acknowledged_at
inventory_stack, inventory_ledger
unique_inventory_item
processed_crafting_command, processed_crafting_ingredient
equipment_slot_state, processed_equipment_command
roadmap_user_state, processed_roadmap_command
remote_config_snapshot, content_release
roadmap_squad, roadmap_squad_member
platform_event, platform_crash_report
  └─ canonical client-reported compass impressions
push_registration, payment_intent, tester_cohort_member
activity_risk_assessment
first_journey_milestone
```

`processed_*` хранит fingerprint и immutable response. Platform fingerprint
рекурсивно сортирует ключи JSON objects, сохраняя порядок arrays и точные
scalar values/types; bounded fallback принимает оба исторических порядка
объявленных двухполевых payload и replay-only compact/indented hashes
предыдущего shared API mapper. Новые rows сохраняют только выделенный compact
canonical hash. Повтор после restart или на другом instance не меняет состояние
второй раз и возвращает канонический сохранённый результат.
V10 расширяет event resolution receipt/delivery-mode/next-node/ACK state;
исторические результаты получают receipt, но backfill-ятся acknowledged, чтобы
не показывать старые награды повторно. Defaults и `BEFORE INSERT` trigger
также auto-acknowledge старый backend writer при rolling upgrade.
V11 добавляет ACK milestone и запрещает менять уже установленный
`acknowledged_at`; state-only legacy completion без receipt не превращается в
ложный ACK. Новый durable row обязан начинаться с
`handoff_required = true, acknowledged_at = NULL`; pre-acknowledged INSERT
отклоняется, а delivery mode после INSERT неизменяем.
V12 выключает `sandboxPaymentsEnabled` и `backgroundHealthSyncEnabled` во всех
существующих remote-config snapshots. Это migration-safe default, а не
authorization boundary: доступность покупки дополнительно ограничена backend
provider mode.
V13 ослабляет старый reward-only inventory ledger до ненулевого credit/debit
при обязательном неотрицательном `quantity_after`, создаёт persistent unique
item и immutable crafting response/ingredient snapshots.
V14 добавляет composite ownership FK и single-slot uniqueness equipment state,
immutable equip/unequip responses и stage-ит inactive `chapter-1-v2`, сохраняя
starter `chapter-1-v1` активной до отдельного cluster-wide activation step.
V17 добавляет независимый persistent cosmetic slot state, backfill известного
legacy `activeCosmeticId`, account cascade и additive platform projection. Старый
backend продолжает менять только compatibility pointer и не удаляет V17 rows;
новый read model накладывает этот pointer на его server-catalog slot.

## 8. Конкурентность и транзакции

- transaction-scoped advisory lock по user или user+expedition;
- row lock wallet/progression/inventory при изменении;
- idempotency lookup до мутации;
- legacy `BUY_COSMETIC` и canonical `PURCHASE_COSMETIC` используют один
  логический idempotency scope. Новая покупка атомарно сохраняет один response
  под двумя physical scopes с command-specific fingerprints, поэтому старый и
  новый экземпляры во время rolling deployment выполняют exact replay; legacy
  processed rows также читаются для обратной совместимости;
- cosmetic equip выводит slot только из server catalog, материализует legacy
  selection и upsert-ит один `(user, slot)` под тем же user lock; независимые
  slots не заменяют друг друга, а exact replay не выполняет второй upsert;
- source uniqueness в ledger;
- account-deletion lock и active-subject check выполняются внутри mutating
  transaction до operation-specific locks/replay. Это включает activity,
  platform, crafting, equipment, expedition advance/resolution и result ACK;
  request-level security check не считается конкурентной границей;
- authenticated telemetry/crash ingestion, push registration, test push и
  tester cohort upsert снимают server-owned receive/mutation timestamps после
  этого account boundary. `app_user`, `app_device` и целевая запись не могут
  быть датированы раньше уже завершённой serialized account mutation;
  anonymous telemetry/diagnostics не имеют user lock и используют прямое
  receive time;
- server-owned `itemInstanceId` и event `receiptId` проходят общую canonical
  UUID-проверку на HTTP boundary до service/DB; Java-совместимые сокращённые
  UUID-алиасы не становятся alternate identity и возвращают единый `400`;
- squad create/join/leave после subject и user boundary получают общий
  transaction-scoped lock по canonical `squadId`; входящий `JOIN_SQUAD.squadId`
  проверяется как полный UUID и нормализуется до создания platform state и
  получения lock. Новая команда снимает `serverTime` после этого lock и
  использует его для membership, state, event и processed response; exact
  replay сохраняет исходное время без повторного squad lock. Account deletion
  получает те же squad locks в стабильном порядке до выбора нового владельца и
  удаления membership, поэтому конкурентные выходы не оставляют отряд без
  участников;
- после account boundary user-scoped advisory lock сериализует crafting;
- после exact replay новая craft-команда получает тот же user+expedition lock,
  что advance/resolution, и проверяет отсутствие pending event result до
  material mutation; material rows блокируются в стабильном `itemId`-порядке;
- все ingredient checks выполняются до debit, а material debit, ledger,
  unique item и processed response имеют один commit;
- equipment exact replay выполняется после account/equipment lock, но до
  expedition boundary; новая мутация получает shared expedition lock,
  проверяет pending receipt, блокирует принадлежащий unique item и одним
  commit сохраняет desired slot state с processed response;
- новый expedition advance фиксирует `serverTime` после shared
  user+expedition lock; debit/ledger, progress state и processed response
  используют одно post-lock время, а exact replay сохраняет исходное;
- новый event resolution фиксирует `serverTime` после shared user+expedition
  lock; progression, material ledger, expedition transition и processed result
  используют одно post-lock время, а exact replay сохраняет исходное;
- event resolution не получает equipment advisory lock: после expedition lock
  он читает committed loadout, поэтому lock order не образует цикл;
- один transaction commit для связанных изменений;
- capable pending result проверяется под тем же user+expedition serialization
  boundary до advance/resolution/new crafting mutation;
- ACK после account-deletion subject lock фиксирует одно post-lock время и
  заполняет им `acknowledged_at` условным `UPDATE`, только пока поле `NULL`;
  тот же commit создаёт ACK milestone, replay читает сохранённое время без
  повторной мутации, а БД запрещает последующую правку timestamp;
- read endpoints не создают zero-state;
- platform snapshot и content bootstrap читают связанные state/facts/content/
  remote-config секции из одного repeatable-read snapshot;
- compass analytics читает eligible users, client impressions и gameplay
  receipts из одного repeatable-read snapshot.

## 9. Ключевые инварианты

1. Клиент не задаёт accepted delta, rewards или баланс.
2. Один idempotency key не создаёт повторное списание/начисление.
3. Тот же key с другим payload возвращает conflict.
3a. Для activity пункты 2–3 используют durable receipt внутри retention
    window. После cleanup reuse key является новой operation generation;
    versioned fingerprint-based ledger source не сталкивается со старой
    записью, а дневной high-watermark не допускает повторной ENERGY.
4. Wallet не становится отрицательным и меняется через ledger.
5. Activity high-watermark пользователя общий для устройств и не уменьшается.
5a. Время новой activity sync фиксируется после общего user lock; local-date
    validation, device presence, risk assessment, ENERGY ledger и durable
    response не могут предшествовать уже завершённой serialized command.
    Activity high-watermark `updated_at`/Home `lastActivitySyncAt` и durable
    operation `created_at`, используемый retention, получают то же post-lock
    время. Exact replay сохраняет исходный business response, а новый
    request-scoped risk assessment использует текущее post-lock время попытки.
5b. Время нового expedition advance фиксируется после общего user+expedition
    lock; ENERGY debit/ledger, progress и durable response не могут
    предшествовать уже завершённой serialized mutation той же экспедиции.
    Exact replay сохраняет исходное post-lock время без повторной мутации.
5c. Время нового event resolution фиксируется после общего user+expedition
    lock; progression, material ledger, expedition transition и durable result
    не могут предшествовать уже завершённой serialized mutation той же
    экспедиции. Exact replay сохраняет исходное post-lock время без награды.
5d. Время нового event-result ACK фиксируется после account-deletion subject
    lock; durable receipt и onboarding milestone не могут предшествовать уже
    завершённой serialized account mutation. Exact replay сохраняет исходное
    post-lock время без повторного ACK.
5e. Время authenticated platform ingestion фиксируется после account-deletion
    subject lock. Server-owned telemetry/crash `received_at`, push/tester
    mutation timestamps и связанные user/device timestamps отражают
    фактический serialized порядок, в том числе через UTC day boundary;
    client-controlled `occurredAt` остаётся только диагностическим.
6. Inventory stack меняется через inventory ledger.
7. Historical response не заменяется более новым snapshot.
8. Process restart не меняет pending payload/key.
9. Platform command first response равен replayed response; перестановка ключей
   JSON object и настройки общего API `ObjectMapper` не меняют persistent
   business fingerprint, а array order остаётся значимым. Bounded upgrade
   candidates сохраняют replay rows предыдущего binary с compact/indented API
   mapper hash, но никогда не становятся fingerprint новой команды. Единственная
   runtime-проекция provider capability монотонно fail-closed: исходный `false`
   сохраняется, а исходный `true` может стать `false`, если текущие config или
   provider больше не разрешают capability.
10. Alias имени cosmetic purchase не меняет idempotency scope; тот же key с
    другим `cosmeticId` конфликтует до provider call.
10a. Cosmetic ID не выбирает slot на клиенте; один пользователь имеет не более
     одного server-known cosmetic в каждом `PILOT`/`PET`/`PROFILE` slot.
11. Risk engine работает в shadow mode до внешней калибровки. Attestation
    остаётся request-scoped и оценивается на каждой попытке до idempotency
    replay; сохранённый business response, activity state и ENERGY при этом не
    меняются.
12. User/device/actor не принимаются контроллерами из произвольных headers или body в production.
13. Валидный JWT без прикладной `ROLE_USER`/`ROLE_ADMIN` не даёт доступ к API.
14. Event reward с `handoffRequired = true` считается переданным UI только
    после owner-scoped ACK соответствующего `receiptId`; legacy mode
    auto-acknowledged.
15. Пока capable event result pending, новый advance или resolution той же
    экспедиции запрещён.
16. ACK не имеет request body; replay возвращает стабильные
    `acknowledgedAt/serverTime`.
17. Capability не входит в idempotency fingerprint; exact replay возвращает
    delivery mode первого commit.
18. `ONBOARDING_COMPLETED` сохраняет V9-семантику; доказательством доставки
    первого результата является отдельный
    `FIRST_EVENT_RESULT_ACKNOWLEDGED`.
19. `PENDING` mobile-команда не удаляется пользовательским действием и
    повторяется только с исходным payload/key.
20. Telemetry failure не удерживает ACTIVITY или GAMEPLAY lane.
21. Recovery presentation не раскрывает command payload, idempotency key,
    receipt, raw error или локальный путь.
22. `stage`/`prod` нельзя совмещать с `local`/`test`.
23. Protected runtime не регистрирует sandbox payment или development push.
24. Remote config не может включить отсутствующую backend/mobile capability.
25. Новая недоступная покупка отклоняется до state mutation.
26. Replay сохранённой покупки возвращает прежний command outcome/user state
    без нового provider call или mutation; capability fields заново
    проецируются из текущего deployment и после disable могут стать `false`.
26a. Новая platform-команда использует по одному frozen effective remote config
     и active content version для gates, mutation calculations, impression
     validation, achievements и response projection; concurrent publication
     становится видна только следующему request.
26b. `serverTime` новой platform-команды фиксируется после frozen runtime reads;
     принятый route impression не может предшествовать content activation,
     которую использовали его validation, event и durable response.
26c. Squad-команда фиксирует `serverTime` после canonical squad lock;
     membership, state, audit event и processed response не могут предшествовать
     уже завершённой мутации другого участника. Exact replay не получает lock
     повторно и возвращает исходное post-lock время.
27. Oversized или rate-limited anonymous telemetry/crash request не вызывает
    application service и не создаёт database state.
28. Salted hashes direct client keys public ingress limiter-а bounded и
    ephemeral; raw address не персистируется и не используется как metric
    label.
29. Liveness не зависит от PostgreSQL; readiness включает его, а health
    details никогда не раскрываются.
30. Synthetic backup/restore evidence всегда имеет
    `productionValidated=false` и не закрывает реальный restore gate.
31. Crafting command не принимает client-calculated cost/result и не допускает
    частичного списания ingredients.
32. Material ledger delta ненулевой, а stack/ledger `quantityAfter` никогда не
    отрицателен.
33. Один unique item создаётся не более одного раза на user+item/recipe; exact
    replay возвращает исходный instance и snapshots.
34. Equipment slot может ссылаться только на unique item того же user; один
    instance не занимает два slot.
35. Home choice availability не заменяет server-side prerequisite check.
36. Exact equipment replay доступен при pending event receipt, но новая
    equip/unequip mutation до ACK запрещена.
37. Обычный выбор `mirror-delta-v1` не попадает в optional route; только
    `follow-resonance` с экипированным компасом ведёт в `resonance-pocket`.
38. Cached, superseded, off-viewport, covered или background Home не создаёт
    compass impression; network impression имеет canonical server IDs, exact
    replay и не меняет gameplay state.
39. Craft/equip/reach/choice/completion funnel stage не выводится из client
    payload и подтверждается только persistent gameplay row.
40. Отрицательный target-baseline interval не участвует в p50/p90 и остаётся
    виден отдельным out-of-order data-quality fact.
41. Enum-like API/storage tokens канонизируются через locale-neutral Unicode
    casing; JVM default locale не меняет command routing, telemetry semantics
    или сохранённые platform/provider/cohort значения.
42. Signed OIDC `sub` принимается только как исходная JSON-строка: decoder
    decorator проверяет compact JWS payload до Nimbus/Spring registered-claim
    conversion. `sub`, actor и stable-device claims не нормализуются через
    `trim`; граничный
    whitespace, control characters и не помещающиеся в persistent identity
    columns значения отклоняются до controller. Optional actor/device claim
    может отсутствовать, но его присутствующее malformed значение или malformed
    nested-path не подменяется fallback-identity.
    Защищённый actuator surface валидирует claims до role authorization, но не
    зависит от lookup состояния игрового аккаунта.
43. Внешние `itemInstanceId` и `receiptId` имеют единственное полное UUID-
    представление; shortened aliases отклоняются до service, lock и lookup.
44. `catalogDigest` покрывает каноническое содержимое platform catalog без
    самого digest: map key order незначим, list order значим, а изменение
    любого server-owned catalog value меняет стабильный SHA-256. Digest writer
    изолирован от API `ObjectMapper`, сортирует object properties и не включает
    response formatting.

## 10. Identity и authorization boundary

```text
OIDC access token
→ signature + issuer + audience + expiration validation
→ sub = canonical userId
→ configurable role/scope claims
→ ROLE_USER / ROLE_ADMIN
→ RequestIdentity from SecurityContext
→ controller/application command
```

Базовый режим backend — `jwt`; demo endpoint выключен. `dev-header` существует только в явных `local`/`test` профилях и изолирует технические headers внутри одного filter-а. В production `/api/v1/admin/**` требует `ROLE_ADMIN`, остальные защищённые `/api/v1/**` — `ROLE_USER`. Signed identity claims проходят exact, fail-closed validation: `JwtDecoder` decorator проверяет исходный JSON-тип `sub` в compact JWS payload до Nimbus/Spring registered-claim conversion, backend не обрезает identity values и не позволяет числовому и строковому `sub` либо двум различным `sub`/device values попасть в одну persistent partition из-за claim coercion или строковой нормализации. Настроенный optional actor/device claim использует fallback только когда path действительно отсутствует; присутствующее пустое, нестроковое или structurally malformed значение отклоняет токен. `ActiveAccountFilter` применяет ту же claim validation к authenticated actuator-запросам до authorization; при этом operations surface не выполняет account-state lookup и не связывает доступ к метрикам с доступностью PostgreSQL.

Activity device identity получается из подписанного session/device claim и хранится как SHA-256 pseudonym. Произвольный `X-Device-Id` в JWT mode игнорируется. На public application surface остаются system info, content bootstrap, bounded anonymous telemetry/crash ingestion и no-detail aliases `/livez`/`/readyz`. Actuator counterparts остаются на management boundary; metrics требуют `ROLE_ADMIN`.

Mobile Authorization Code + PKCE, secure token storage, refresh и logout
реализованы как отдельная boundary; production IdP configuration и
device-validation остаются внешними gates. Подробности:
`docs/adr/0018-mobile-oidc-session.md`.

## 11. Protected runtime и provider boundary

```text
local|test + explicit opt-in
├── SandboxPaymentProvider
└── DevelopmentPushDeliveryProvider

stage|prod
├── explicit verified-TLS PostgreSQL datasource
├── JWT + demo disabled
├── DisabledPaymentProvider
└── DisabledPushDeliveryProvider
```

`ProductionRuntimeGuard` отклоняет смешанные profile sets, local/default
datasource credentials и небезопасный или неоднозначный PostgreSQL `sslmode`.
Тонкий `ProductionEnvironmentPostProcessor` вызывает ту же datasource-проверку
до создания context/DataSource/Flyway. Development providers требуют
одновременно явный property opt-in и активный `local`/`test`; одного property
недостаточно.

Backend возвращает effective `sandboxPaymentsEnabled`: remote flag считается
включённым только при доступном payment provider. Mobile строит purchase action
только вне release build и для свежего snapshot с effective value `true`;
cached snapshot остаётся read-only и не показывает эту action.
Exact command replay дополнительно требует, чтобы capability была `true` в
сохранённом response: более поздняя admin-публикация не расширяет ранее выданный
`false`, а отключение config/provider по-прежнему может понизить `true` до
`false`.
`backgroundHealthSyncEnabled` также принудительно возвращается как `false`:
этот срез не выдаёт foreground/resume fallback за production background
delivery.

Этот boundary не реализует production payment/push. Реальные store billing,
server verification, restore/refunds, APNs/FCM, production secrets,
deployment и delivery evidence остаются внешними gates. См. ADR 0025.

## 12. Operations boundary

```text
public application listener
├── authenticated /api/v1/**
├── system info/content bootstrap
├── bounded anonymous telemetry/crash
├── /livez
└── /readyz

loopback management listener (stage/prod)
├── actuator liveness
├── actuator readiness + PostgreSQL
└── Prometheus + ROLE_ADMIN
```

Public ingestion использует отдельные per-process client и global token
buckets, raw-body limits и DTO limits. Forwarded headers не являются доверенной
client identity. Salted client-key hashes имеют bounded count/TTL; raw address
не персистируется и не попадает в metrics.
`413 PAYLOAD_TOO_LARGE`/`429 RATE_LIMITED` возвращают privacy-safe error без
raw payload, ставят `Cache-Control: no-store` и не вызывают application
service. Metric outcome `accepted` означает admission этим filter, а не
обязательно controller response `202`.

Actuator discovery и `info` выключены. `/livez`, `/readyz` и Prometheus имеют
разную семантику; health details/components скрыты, остальные application-port
operational routes запрещены. Protected `stage`/`prod` по умолчанию выносят
Actuator/Prometheus на `127.0.0.1:8081`, а application listener получает только
canonical no-detail probe aliases. Фактическая network policy management
listener-а, WAF/distributed quota, monitoring и alerts остаются внешними gates.

HTTP connection/keep-alive/async request, datasource
acquisition/validation, JDBC query, transaction и graceful shutdown имеют
явные finite budgets, проверяемые protected runtime guard.

Synthetic PostgreSQL 17 drill применяет Flyway V1–latest к disposable fixture,
создаёт custom-format archive, проверяет checksum до fresh-target restore и
сравнивает schema/data/sequence manifests. Его evidence всегда имеет
`scope=SYNTHETIC_CI` и `productionValidated=false`; production backup policy,
PITR/RPO/RTO и dated real restore требуют отдельного evidence.

Подробности: [ADR 0026](adr/0026-production-operational-controls.md) и
[production operations runbook](PRODUCTION_OPERATIONS_RUNBOOK.md).

## 13. Health boundary

```text
StepSource
├── PlatformHealthStepSource
│   ├── HealthGateway
│   ├── ActivityRecognitionGateway
│   └── DeviceTimeZoneProvider
└── DevelopmentStepSource
```

Только `STEPS READ`, local midnight → now, IANA timezone и foreground/manual sync. Resume fallback не выдаётся за гарантированную background delivery. Физическая матрица описана в `DEVICE_VALIDATION_PROTOCOL.md`.

## 14. Offline read model

```text
server GET /home|platform success
→ domain validation
→ versioned local snapshot

transport/408/429/5xx/malformed success
→ повторная domain validation cached JSON
→ read-only UI + explicit cache timestamp
```

Read cache не хранит неподтверждённые изменения и не заменяет command outbox.
Перед mutation-attempt зависимый cache инвалидируется, потому что transport
failure может скрывать уже принятый backend-ом результат. Server-owned
`pendingEventResult` не является optimistic state: он может быть сохранён в
cached home и показан после restart, но его ACK-кнопка остаётся read-only.
Terminal `4xx` не скрываются fallback-ом. Cached ENERGY не разрешает расходные
команды.

Подробности: `docs/adr/0016-offline-read-cache.md` и
`docs/adr/0022-durable-event-result-handoff.md`.

## 15. Release-quality model

```text
Standard CI
→ compile/tests/migrations
→ Flutter format/analyze/tests
→ Android debug APK
→ iOS Simulator build

Release quality
→ policy/static checks
→ deterministic metadata
→ backend JAR
→ Android unsigned release AAB
→ iOS release app --no-codesign

Protected external environment
→ production signing credentials
→ manual owner approval
→ store submission
```

CI не хранит signing material и не выдаёт неподписанный candidate за
публикуемый build. Protected profile/provider/operations tests и synthetic
restore подтверждают только code-level isolation и reproducible tooling;
production database, secrets, management network, deployment, monitoring,
dated restore, device, push, payment, beta и store gates получают статус
`VALIDATED` только после evidence.

## 16. Branch protection

Feature-ветки обновляет `serbin70`; `master` защищён ruleset и CODEOWNERS. Merge выполняет `MKSEgr` после CI/review через `Squash and merge`. Подробности: `BRANCH_PROTECTION.md`.

### Mobile OIDC session boundary

The mobile client is a public OAuth/OIDC client. It uses Authorization Code +
PKCE, stores tokens only in platform secure storage, and derives an opaque local
owner partition from canonical `issuer + subject`. API clients never accept or
send user/device identity headers in OIDC mode; backend identity comes only from
the validated access token. See ADR 0018.

### Account data-control boundary

Экспорт читается только через authenticated API, временно staging-ится для
системного share sheet и удаляется из sandbox приложения после передачи.
Удаление использует отдельный idempotent command: два UI-подтверждения → fresh
OIDC login той же owner identity → транзакционное удаление → durable receipt →
fail-closed local logout/cleanup. Backend receipt не содержит raw subject, а
deletion registry отклоняет последующие запросы со старым Bearer token.
Backend не доверяет только mobile step-up: destructive endpoint требует
подписанный `auth_time` в access token в пределах короткого server-side окна.
Fresh-auth boundary преобразует NumericDate в exact epoch nanoseconds;
floating-point rounding не может превратить дробный claim в другое допустимое
время аутентификации: точные integer/decimal/`Instant` представления
поддерживаются, а уже lossy `Float`/`Double` отклоняются fail-closed.
См. ADR 0019.
