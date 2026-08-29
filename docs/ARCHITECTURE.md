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
itemupgrade    — server-owned refinement, rarity и immutable exact replay
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
item_upgrade          — durable item refinement command/result
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

Platform snapshot содержит onboarding, три питомца, skills, quests, achievements, season, weekly route, squad, cosmetics, experiments и remote config. Pet projection передаёт текущую форму, следующий bond threshold и `maximumEvolutionStage`; отсутствие последнего поля у старого backend означает legacy maximum `1`. После rollback контента effective maximum не опускается ниже сохранённой стадии питомца, поэтому snapshot остаётся валиден, но правила старого контента не разрешают новый переход. `equippedCosmetics` является additive server-owned mapping `PILOT`/`PET`/`PROFILE → cosmeticId`; legacy `activeCosmeticId` остаётся указателем на последний выбор для старого клиента. После успешной команды UI заменяет состояние snapshot-ом backend и перечитывает home; optimistic rewards не применяются.

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

Retention, first-journey и compass read models начинают `REPEATABLE_READ`
с одного population query, который одновременно возвращает PostgreSQL
`statement_timestamp()` как `generatedAt`. В PostgreSQL snapshot фиксируется
на первом нетранзакционном statement, поэтому эта server-owned метка относится
к тому же observation boundary, что и все последующие counters. Ожидание lock
в поздней секции ответа и рассинхронизация JVM clock не сдвигают время уже
зафиксированного snapshot.

`roadmap_user_state.activePetId` — источник выбора питомца. Общий
`ActivePetProvider` связывает platform state с home/progression: event reward
берёт тот же per-user advisory lock, что и `SELECT_PET`, затем блокирует и
изменяет строку выбранного `pet_id`; pilot XP остаётся общим. Quest bond и
каждая evolution stage и level синхронизируются с той же `pet_progress`
строкой в транзакции platform-команды. Для старого раздвоенного состояния read/reward использует
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
Сезонная cadence также имеет один catalog-owned источник:
`content.season.xpPerLevel` определяет backend reward eligibility,
`userState.seasonLevel` и связанное level-3 achievement, а mobile использует
accepted value только для next-reward guidance. Отсутствие additive поля у
legacy cache сохраняет старый claim fallback, но запрещает client-inferred
guidance; persisted state и migration не меняются.
Production Home, live platform snapshot и bootstrap начинают read-only
`REPEATABLE_READ` с общего PostgreSQL `statement_timestamp()`. Этот первый SQL
фиксирует transaction snapshot, а его результат становится `serverTime` всего
response. Поэтому ожидание lock в поздней state/content/event секции и
рассинхронизация JVM clock не могут датировать старый snapshot более новым
временем. Command responses сохраняют отдельную post-lock timestamp семантику.
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
Version identifier каждой публикации trim-ится до lock; запись, immediate
response и последующий authoritative read используют одно canonical значение,
а не raw transport string с граничным whitespace.
Remote-config publication также один раз строит canonical config до lock:
exact-integer JSON numbers сохраняются как JSON integers, а `seasonId` без
граничного whitespace. БД, immediate admin response и public effective config
начинаются с одного представления вместо повторной нормализации только на read.
Content release допускается до application service и этого lock только с явно
присутствующим непустым JSON object `content`; missing/null/empty payload не
может зависеть от более поздней service-level защиты.
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

Starter crafting content версионирует каждый additive срез. Recipe
`resonance-compass-v1` из `crafting-v1` создаёт non-stackable
`resonance-compass`; `prism-sextant-v1` из `crafting-v2` принимает
`2 × prism-dust`, `1 × ion-bloom`, `1 × dawn-fragment` и создаёт
non-stackable `prism-sextant`. Второй recipe не проецируется и не принимается
до активации `chapter-1-v5`. Client получает recipe projection через home, но
не задаёт стоимость, количество или результат command-а.

Item upgrade content `item-upgrade-v1` появляется только при active
`chapter-1-v5`. Definition `prism-sextant-calibration-v1` расходует
`2 × echo-thread`, `1 × prism-dust`, `1 × ion-bloom` и переводит тот же
`itemInstanceId` с уровня `1/UNCOMMON` на `2/RARE`. Клиент получает только
authoritative Home projection и не задаёт target, стоимость, level или rarity.
При active `chapter-1-v8` additive `item-upgrade-v2` открывает
`prism-sextant-second-dawn-attunement-v1`: он расходует `2 × echo-thread`,
`2 × ion-bloom`, `2 × dawn-fragment` и переводит тот же instance с
`2/RARE` на `3/EPIC`. Предыдущие content versions видят только доступные им
ступени.

Active `chapter-1-v9` добавляет equipment-gated
`cross-uncharted-verge` к `second-dawn-threshold-v1`. Requirement принимает
только экипированный `prism-sextant` минимум уровня 3; successful resolution
ведёт к optional `uncharted-verge`, где оба server-owned выбора завершают
экспедицию после собственной material reward. V1-V8 не проецируют новый
choice ни как available, ни как locked.

Active `chapter-1-v10` сохраняет 25-node topology и добавляет в
`uncharted-verge-v1` три active-pet-gated исхода для Искры, Мха и Навигатора.
Home проецирует только исход текущего питомца в `choices`, два остальных — в
`lockedChoices` с `type=ACTIVE_PET`. Event service повторно читает active pet
под тем же serialized user/expedition transaction boundary до XP, bond,
material и completion mutations. V1-V9 не знают новые choice IDs.

Active `chapter-1-v11` сохраняет ту же topology и открывает вторую
server-authoritative эволюцию для всех starter pets: Spark `140`, Moss `125`,
`rune-v1` / Navigator `150` bond. V1-V10 ограничивают `EVOLVE_PET` стадией
`1`; v11 проецирует следующий threshold и `maximumEvolutionStage=2`, а
достигнутая стадия `2` получает взрослое имя. State JSON не требует schema
rewrite, а level/bond продолжают синхронизироваться с независимой
`pet_progress` строкой.

Active `chapter-1-v12` добавляет 26-й узел `constellation-sanctuary`. Три
новых choice в `uncharted-verge-v1` требуют одновременно exact active pet и
`evolutionStage >= 2`, выдают разные material rewards и ведут к общему
финальному событию. Home проецирует additive `minimumEvolutionStage`, но event
service повторно читает active pet со стадией под тем же serialized
user/expedition boundary до любой XP, bond, material или route mutation.
V1-V11 не проецируют и не принимают новые IDs.

Active `chapter-1-v13` сохраняет 26-node topology и добавляет в финальное
событие skill-gated choice `decode-sanctuary-signal`. Home получает
authoritative множество навыков через `PlatformSkillAccess` и проецирует
`UNLOCKED_SKILL` как additive generic requirement. Event resolution независимо
повторяет ту же проверку по repository-backed platform state до любых наград
или completion mutation; клиентская availability остаётся только UX-проекцией.
V1-V12 не проецируют и не принимают новый ID.

Active `chapter-1-v14` сохраняет skill gate v13, но успешный
`decode-sanctuary-signal` продолжает экспедицию в 27-й узел
`hidden-signal-observatory`. Его событие содержит два terminal choice с
разными XP/bond/material rewards. Версионная маршрутизация оставляет v13
terminal semantics неизменной, а определения нового узла остаются читаемыми
после content rollback, чтобы уже сохранённое v14 journey можно было
завершить. V1-V13 не могут начать этот маршрут.

Active `chapter-1-v15` добавляет в `hidden-signal-observatory-v1` choice
`reconstruct-forgotten-route`, защищённый authoritative навыком
`trail-memory`, и 28-й узел `memory-constellation`. V14 сохраняет два прежних
terminal outcome; новый choice выдаёт награду и продолжает journey только в
v15. Определение 28-го узла и его два terminal choice остаются читаемыми после
content rollback, чтобы сохранённое v15 journey завершалось под v14 binary
нового поколения. V1-V14 не могут начать маршрут.

Active `chapter-1-v16` добавляет в `memory-constellation-v1` choice
`stabilize-dawn-current`, защищённый authoritative навыком
`energy-discipline`, и 29-й узел `dawn-meridian`. V15 сохраняет два прежних
terminal outcome; новый choice выдаёт награду и продолжает journey только в
v16. Определение 29-го узла и его два terminal choice остаются читаемыми после
content rollback, чтобы сохранённое v16 journey завершалось под v15 binary
нового поколения. V1-V15 не могут начать маршрут.

Active `chapter-1-v17` добавляет в `dawn-meridian-v1` choice
`cross-first-light-causeway`, защищённый authoritative навыком `steady-step`,
и 30-й узел `first-light-causeway`. V16 сохраняет два прежних terminal outcome;
новый choice выдаёт награду и продолжает journey только в v17. Определение
30-го узла и его два terminal choice остаются читаемыми после content rollback,
чтобы сохранённое v17 journey завершалось под v16 binary нового поколения.
V1-V16 не могут начать маршрут.

Home строит `routeTrail` и `decisionLog` из одного repository-ordered набора
immutable event resolutions exact текущего `journeyNumber`. Additive nullable
`routeTrail[].decision` переносит stable choice identity и сохранённые
`choiceTitle + outcomeTitle` прямо к разрешённому узлу; mobile не соединяет два
массива по index, node ID или current content. При завершении последний узел
меняет literal state на `COMPLETED`, сохраняя фактическую annotation, а новый
поход начинает один неаннотированный `CURRENT` node без schema migration.

Current-journey journal route map использует только ordered accepted Home
`routeTrail`. Existing `ExpeditionRouteTrail` сохраняет literal node state и
optional decision pairing; known mutable node name локализуется по stable
`nodeId`, а unknown future ID сохраняет literal Home fallback. Persisted
`choiceTitle/outcomeTitle` остаются literal, потому что route annotation не
содержит достаточной event/outcome identity для безопасного current-content
mapping. Journal не соединяет trail с `decisionLog`, READY event, Platform
weekly route, history или local catalog, не прогнозирует topology и скрывает
legacy empty trail. Видимый accepted count исключён из semantics, а одна
existing route summary сохраняет order, terminal point и decisions.

Additive nullable `expedition.startedAt` читается из того же durable
journey-start source, который используется для completion duration, но exact
текущего `journeyNumber`. Service не выводит start из первого resolution,
content или response clock; legacy absence остаётся неизвестным значением.

Current-journey expedition label использует только required
`expedition.expeditionId/name`. Exact stable ID разрешает known mutable name
через current-content catalog, а unknown future ID сохраняет literal server
fallback. Route trail, current node, READY event и local catalog state не
подменяют accepted expedition identity; projection остаётся read-only.

Current-journey active companion label использует только accepted Home
`pet.petId/name`. Exact known ID разрешает mutable name через current-content
catalog; legacy missing ID и unknown future ID сохраняют literal Home name.
Platform active pet, route trail, READY requirement, decision rewards и local
catalog state не подменяют accepted Home companion identity.

Current-journey companion progression использует только accepted Home
`pet.level/bond`. Platform active pet progression, decision reward delta,
completion/chronicle totals и local catalog state не подменяют эти facts;
journal не агрегирует rewards, не прогнозирует evolution и остаётся read-only.

Current-journey companion form использует только optional accepted Home
`pet.species/evolutionStage`. Known `petId` разрешает mutable species через
current-content localization, legacy/unknown ID сохраняет literal Home
fallback, а stage получает существующее RU/EN имя формы без вычисления
threshold или следующей evolution. При отсутствии любого optional field label
не показывается; Platform active pet и local catalog его не восстанавливают.

Current-journey companion portrait использует только полную accepted Home
группу `pet.petId/name/species/evolutionStage`. Existing `CompanionPortrait`
выбирает stage-aware illustration для known stable identity и code-native
fallback для future ID; name/species/form проходят те же current-content RU/EN
resolvers, что соседние labels. Неполная группа скрывает portrait, а Platform
active pet, cosmetics, rewards, catalog и evolution rules его не дополняют.
Journal исключает внутреннюю portrait semantics и публикует одну dedicated
image semantics node без duplicate announcement.

Current-journey pilot portrait использует exact accepted Home
`pilot.pilotId/name` и показывает existing Navigator illustration только для
known `navigator-v1`. Legacy missing ID и future ID сохраняют literal text
fallback без ложного known artwork. Platform hero progression, cosmetics,
rewards, history и catalog не меняют portrait; journal использует base asset,
исключает внутреннюю semantics и публикует одну dedicated localized image
semantics node. Pilot и companion portraits делят wrapping crew row, но
сохраняют независимые source и fail-closed правила.

Current-journey pilot label использует только accepted Home
`pilot.pilotId/name`. Exact known ID разрешает mutable name через
current-content catalog; legacy missing ID и unknown future ID сохраняют
literal Home name. Platform hero, route trail, READY requirement, decision
rewards, completion history и local catalog state не подменяют accepted Home
pilot identity.

Current-journey pilot progression использует только accepted Home
`pilot.level/currentExperience/nextLevelExperience`. Existing Home invariant и
remaining getter дают current/target/remaining из одного snapshot; Platform
season XP, decision rewards, completion/chronicle totals и local content не
подменяют progression. Legacy direct snapshot без valid progression не
проецирует ложные `0 / 0`; journal остаётся read-only.

Mobile принимает current phase только из required `expedition.status` и
fail-closed ограничивает его server enum `IN_PROGRESS`, `EVENT_READY`,
`COMPLETED`. Journal не пересчитывает phase из energy, route trail, decisions,
unlocked event или completion recap; projection не меняет command boundary.

Current-journey position использует только required
`expedition.currentNodeId/currentNode`. Stable ID разрешает известную mutable
copy через current-content catalog, а неизвестный ID оставляет server fallback;
последний route node, decision, phase и event не заменяют accepted position.

Current-journey node landmark использует ту же accepted Home пару
`currentNodeId/currentNode` и exact `expedition.status`. Existing
`ExpeditionNodeSignal` выбирает known code-native landmark только по exact
stable ID; future ID получает neutral artwork и literal localized-name fallback.
Completed flag передаётся только для accepted `COMPLETED`, а route terminal,
READY event, Platform progression/history и local catalog не подменяют identity
или styling. Landmark вложен в existing current-position `ExcludeSemantics`,
поэтому visible signal и label публикуют одну прежнюю authoritative semantics
node без duplicate announcement.

Current-journey ENERGY progress переносит required
`expedition.progress/requiredEnergy` как literal accepted integers. Mobile
передаёт эти integers и accepted `expeditionId` в existing
`ExpeditionProgressSignal`: exact known ID выбирает reviewed code-native route
contour, а future ID получает neutral field без dispatch по display name.
Signal clamp-ит только painted trace и не меняет copy; Platform weekly route,
route/current-node, READY event, decisions, history и catalog не подменяют
identity или progress. Signal вложен в existing ENERGY `ExcludeSemantics`,
поэтому остаётся одна authoritative semantics node. Phase, decision
availability, completion, remaining rewards, spendability и command eligibility
из отношения чисел не выводятся.

Current-journey ready event использует только `expedition.unlockedEvent` со
status exact `READY`. Stable `eventId` разрешает known mutable title и summary
через current-event catalog, а unknown ID оставляет оба server fallback;
absent, `RESOLVED` и unknown status fail-closed не создают event block. Phase,
current node, ENERGY progress, route trail, choices и decision log не выбирают
event. Positive available-choice count фильтрует только accepted server-owned
`availability`, не выполняет requirements повторно и не создаёт journal
actions. Title, summary и count принадлежат одной accessibility semantics node;
legacy/empty и locked-only choice state не создают count.

Тот же accepted READY event наполняет existing `ExpeditionEventScene`. Exact
reviewed event ID выбирает existing illustration, unknown future ID получает
neutral code-native fallback без dispatch по title или summary. Expedition
phase, current node, route trail, ENERGY, decisions, Platform event/progression,
history и catalog не подменяют scene identity или readiness. Scene вложена в
existing event `ExcludeSemantics`, поэтому title, summary, choice facts и visual
остаются одной authoritative accessibility semantics node.

Тот же immutable источник наполняет additive `decisions[]` в current и recent
journey recap. Каждая запись переносит полный persisted decision/reward fact,
поэтому архивный журнал не обращается к current content и не восстанавливает
историю из totals, node IDs или topology. Mobile требует exact `decisionCount`
и совпадение последней записи с `finalDecision`, но legacy recap без массива
остаётся читаемым. UI раскрывает detail только для recent archive: текущий
завершённый поход уже показывает тот же порядок в `decisionLog`.

Те же exact-journey resolutions формируют additive ordered
`pilotExperienceRewards[]` в current и recent recap. Service группирует только
положительный `pilot_experience_gained` по persisted
`pilot_id + pilot_name` в порядке первого появления и публикует breakdown,
только если его сумма точно равна совместимому `pilotExperienceGained`.
Неполная historical identity опускает весь additive массив, а не создаёт
частичную историю. Mobile сохраняет generic XP fallback для legacy snapshot и
не выводит identity из current pilot content, progression или lifetime totals.

Current и recent recap также показывают момент завершения из уже
валидированного immutable `finalDecision.resolvedAt`. Mobile переводит exact
instant в локальную timezone устройства только на presentation boundary и
форматирует дату/время через выбранную RU/EN locale. Видимый label и semantics
получают одну строку; client clock, cache metadata и время Home-response не
участвуют. Legacy recap без `finalDecision` остаётся читаемым и не получает
выдуманного timestamp.

Additive `durationSeconds` в current и recent recap вычисляется backend-слоем
только из persisted start exact journey и immutable final resolution. Для
journey 1 источником служит initial cycle/progress creation; для journey 2+
— `processed_expedition_journey_start.server_time`. Missing source/final или start
позже final дают omission, а не приближённый результ. Mobile fail-closed
отклоняет malformed/negative duration, а RU/EN visible label и semantics
используют одну отформатированную строку. Schema migration, client clock,
cache/Home-response time и current content в расчёте не участвуют.

Каждая current `decisionLog` entry и запись раскрытой recent archive history
показывает собственный уже валидированный immutable `resolvedAt`. Mobile
переиспользует тот же local-time RU/EN label в видимом UI и полной semantics
строке. Эта запись решения не выводит самостоятельную duration и не
подменяет persisted instant
client clock, cache metadata, временем Home-response или current content;
backend, API shape и storage при этом не меняются.

Home также строит nullable lifetime `journeyChronicle` без отдельной таблицы и
без зависимости от ограниченного recent archive. Repository считает каждый
immutable receipt старта journey N+1 доказательством завершения journey N и
SQL-проекцией суммирует его persisted event resolutions. Та же проекция
сопоставляет каждому included journey authoritative start и последнюю
immutable resolution: journey 1 использует initial cycle creation с fallback
на progress creation, journey 2+ — exact journey-start receipt `server_time`.
Lifetime `totalDurationSeconds` суммируется по полной receipt-proven history,
`shortestDurationSeconds` вместе с `shortestJourneyNumber` выбирает minimum с
tie-break по меньшему journey number. Та же winner-строка передаёт
`shortestJourneyCompletedAt` только из immutable final resolution, а
`longestDurationSeconds` вместе с `longestJourneyNumber` выбирает maximum с
tie-break по меньшему journey number. Та же winner-строка
передаёт `longestJourneyCompletedAt` только из immutable final resolution;
service добавляет или сравнивает duration current authoritative `COMPLETED`
ровно один раз, меняет shortest identity и completion instant только при
строго меньшем current duration, а longest identity и completion instant —
только при строго большем.
После этого merge service выводит `averageDurationSeconds` только как
целочисленное floor-деление total на `completedJourneyCount`. Longest и average
публикуются только вместе с total; shortest также требует total и не превышает
average/longest, longest не превышает total, обе identity положительны и входят
в completed count, а average точно соответствует
total/count. Оба record completion instant публикуются только вместе с
соответствующими duration и identity, а mobile переводит их из UTC в timezone
устройства исключительно для presentation. Если хотя бы одна included
boundary отсутствует или start позже final, все четыре duration-поля, обе
record identity и оба timestamp целиком опускаются: recent archive, client
clock, cache/Home-response time и частичный итог не используются. Та же
SQL-проекция группирует положительную связь по persisted `pet_id + pet_name`,
сохраняя
порядок первого immutable появления. Service добавляет текущий journey ровно
один раз только при authoritative `COMPLETED` и объединяет его ordered
companion breakdown с historical группами; после старта следующего похода тот
же результат уже входит через receipt и больше не добавляется как current.
Сумма breakdown точно равна совместимому `petBondGained`, а legacy snapshot
без массива остаётся читаемым как общий неназванный итог. Поэтому расширение
главы не превращает historical `expedition_status=COMPLETED` в ложный финиш.
Persisted `pilot_id + pilot_name + pilot_experience_gained` на той же
receipt-proven границе формируют ordered lifetime `pilotExperienceRewards[]`.
SQL группирует только положительный XP по persisted identity и сохраняет
порядок первого immutable появления; service добавляет rewards authoritative
current `COMPLETED` ровно один раз. После следующего journey-start тот же XP
уже приходит из historical SQL. Полный breakdown отдаётся только когда сумма
`experienceGained` совпадает с lifetime `pilotExperienceGained`; иначе поле
опускается. Current pilot content, progression total и recent archive не
используются для восстановления истории.
Та же receipt-proven граница агрегирует ordered lifetime `materials[]` по
persisted `material_item_id + material_item_name`: SQL сохраняет порядок
первого immutable появления, а service один раз добавляет материалы current
`COMPLETED` recap. Inventory balance, current material catalog и пять строк
recent archive не участвуют, поэтому republish или расход предметов не
переписывает сохранённые decision и reward totals.

Все immutable resolutions на той же receipt-proven границе формируют ordered
lifetime `decisionOutcomes[]`. SQL группирует полный persisted
event/choice/outcome identity и сохраняет порядок первого появления; service
добавляет все решения authoritative current `COMPLETED` ровно один раз. После
следующего journey-start эти решения уже приходят из historical SQL. Полный
breakdown отдаётся только когда сумма entry `decisionCount` совпадает с
lifetime `decisionCount`; иначе additive поле опускается, сохраняя
legacy-compatible snapshot. Current content, topology и пять recent recaps не
используются для восстановления истории.

На той же receipt-proven границе repository выбирает последнюю immutable
resolution каждого завершённого journey по descending
`expedition_version, receipt_id` и строит ordered lifetime
`finaleOutcomes[]`. Группы используют полный persisted event/choice/outcome
copy и порядок первого появления, поэтому переименование current content и
лимит recent archive не переписывают финалы. Service добавляет final decision
authoritative current `COMPLETED` ровно один раз; после следующего journey-start
тот же финал уже приходит из historical SQL. Полный breakdown отдаётся только
когда сумма `journeyCount` совпадает с `completedJourneyCount`; иначе additive
поле опускается как legacy-compatible защита неполной старой history.

Equipment content `equipment-v2`: slot `NAVIGATION` принимает unique
`resonance-compass` или `prism-sextant`, но одновременно удерживает только
один прибор. Home availability является
UX projection; locked choices вынесены в additive `lockedChoices`, чтобы
legacy mobile видел только основной маршрут. Event service повторно проверяет
requirement под authoritative expedition lock. Начиная с `chapter-1-v6`
requirement может дополнительно задавать минимальный server-owned upgrade level:
`trace-second-dawn` требует экипированный `prism-sextant` уровня 2/RARE.
В `chapter-1-v7` тот же requirement защищает финальный
`open-second-dawn`: выбор в `dawn-relay-v1` переводит к optional
`second-dawn-threshold`. Обычные финальные choices по-прежнему завершают
экспедицию сразу, а оба решения нового узла завершают её после собственных
server-owned наград.

Home также проецирует additive `weeklyActivityRhythm` из
`activity_sync_state` без отдельного persisted streak. `DailyGoalService`
читает target local date и шесть предыдущих дат в том же repeatable-read
snapshot; каждая уникальная строка с `accepted_total > 0` даёт один active day.
Backend сохраняет фактический count до семи, фиксированную мягкую цель v1 4/7
и derived `targetReached`, а также строит полный хронологический `days` trail
от `localDate - 6` до target date. Явные inactive entries не сохраняются
отдельно: это безопасная проекция отсутствия positive accepted total внутри
того же snapshot. Mobile принимает legacy object без trail, но supplied dates
fail-closed проверяет на размер, непрерывность, конечную дату и согласованность
с count; Health history и client clock не используются. Окно естественно
сдвигается по локальным датам, поэтому пропуск не выполняет reset, не мутирует
progression и не затрагивает ENERGY/rewards.

## 7. Схема данных

Основные таблицы:

```text
app_user, app_device
  └─ has_successful_activity_sync — monotonic fact реального activity sync
activity_sync_state, processed_activity_sync
economy_wallet, economy_ledger
expedition_progress, processed_expedition_advance
expedition_journey_cycle, processed_expedition_journey_start
pilot_progress, pet_progress
processed_event_resolution
  └─ receipt_id, journey_number, handoff_required, next_node_*, acknowledged_at
inventory_stack, inventory_ledger
unique_inventory_item
  └─ rarity, upgraded_at
processed_crafting_command, processed_crafting_ingredient
processed_item_upgrade_command, processed_item_upgrade_ingredient
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
Перед выполнением новой platform-команды exact command schema отклоняет ключи,
которые её business logic не читает: ignored client data не может изменить
fingerprint без изменения самой мутации. Receipt lookup остаётся до schema
check, поэтому ранее сохранённые точные payload старого binary продолжают
replay-иться, но новая команда с лишним полем не достигает runtime publications,
provider, state или telemetry persistence.
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
V18 stage-ит inactive `chapter-1-v3`: новый `storm-scriptorium` доступен только
через server-owned choice с экипированным компасом, возвращается в основной
маршрут и не меняет immutable v2 baseline resonance funnel.
V19 stage-ит inactive `chapter-1-v4`: два server-owned выбора в
`void-orchard-v1` ведут в независимые `root-memory` и `light-canopy`, каждая
ветка имеет собственные решения и награды и возвращается к `star-well`.
До cluster-wide activation v3-проекция сохраняет прежние choices и 20 узлов.
V20 stage-ит inactive `chapter-1-v5`: recipe призматического секстанта и
server-owned choice `align-prism-sextant` становятся доступны только после
общей активации. Choice требует секстант в `NAVIGATION`, ведёт через
`spectrum-observatory` с двумя наградами и возвращается к `horizon-spire`.
До активации v4-проекция сохраняет один starter recipe, прежние choices и 22
узла.
V21 добавляет rarity/upgraded timestamp unique item-а и immutable item-upgrade
command/ingredient snapshots. Backfill присваивает существующему секстанту
уровня 1 `UNCOMMON`; trigger сохраняет rolling compatibility старого crafting
writer и допускает для секстанта только состояния `1/UNCOMMON` и `2/RARE` с
обязательным `upgraded_at` у второго уровня.
V22 stage-ит inactive `chapter-1-v6` с теми же 23 узлами. В
`spectrum-observatory-v1` появляется `trace-second-dawn`: choice требует
экипированный секстант минимум уровня 2, даёт три `dawn-fragment` и возвращает
к `horizon-spire`. V5 не получает новый choice; activation выполняется только
после drain pre-V22 backend instances.
V23 stage-ит inactive `chapter-1-v7` с 24 узлами. В `dawn-relay-v1`
появляется `open-second-dawn`: choice требует экипированный секстант минимум
уровня 2 и ведёт к `second-dawn-threshold`. V1-V6 сохраняют прежний финал и
catalog; activation выполняется только после drain pre-V23 backend instances.
V24 расширяет rarity и refinement invariants для состояния
`prism-sextant 3/EPIC` и stage-ит inactive `chapter-1-v8` с прежней 24-node
topology. Существующие `1/UNCOMMON`, `2/RARE` и immutable upgrade snapshots
сохраняются; новый attunement принимается только после cluster-wide activation
v8 и drain pre-V24 backend instances.
V25 stage-ит inactive `chapter-1-v9` с 25 узлами. В
`second-dawn-threshold-v1` появляется `cross-uncharted-verge`, требующий
экипированный секстант минимум уровня 3 и ведущий к `uncharted-verge`.
V1-V8 сохраняют прежнюю topology; activation выполняется только после drain
pre-V25 backend instances.
V26 stage-ит inactive `chapter-1-v10` с прежней 25-node topology и тремя
pet-guided исходами `uncharted-verge-v1`. Миграция не меняет active v9,
выбранного питомца или его progression; activation выполняется только после
drain pre-V26 backend instances.
V27 stage-ит inactive `chapter-1-v11` с той же topology и взрослыми формами
трёх starter pets. Миграция не меняет active v10, `roadmap_user_state` или
`pet_progress`; activation выполняется только после drain pre-V27 backend
instances. После сохранения stage `2` rollback на pre-V27 binary запрещён.
V28 stage-ит inactive `chapter-1-v12` с 26-м узлом и adult-pet-gated
продолжением из `uncharted-verge-v1`. Миграция не меняет active v11,
`roadmap_user_state`, `pet_progress` или текущие `expedition_progress` rows;
activation выполняется только после drain pre-V28 backend instances.
V29 stage-ит inactive `chapter-1-v13` с прежней 26-node topology и
skill-gated исходом `constellation-sanctuary-v1`. Миграция не меняет active
v12, `roadmap_user_state`, `pet_progress` или текущие `expedition_progress`
rows; activation выполняется только после drain pre-V29 backend instances.
V30 stage-ит inactive `chapter-1-v14` с 27-м узлом
`hidden-signal-observatory`. Миграция не меняет active v13,
`roadmap_user_state`, `pet_progress` или текущие `expedition_progress` rows;
activation выполняется только после drain pre-V30 backend instances.
V31 stage-ит inactive `chapter-1-v15` с 28-м узлом
`memory-constellation`. Миграция не меняет active v14,
`roadmap_user_state`, `pet_progress` или текущие `expedition_progress` rows;
activation выполняется только после drain pre-V31 backend instances.
V32 stage-ит inactive `chapter-1-v16` с 29-м узлом `dawn-meridian`.
Миграция не меняет active v15, `roadmap_user_state`, `pet_progress` или
текущие `expedition_progress` rows; activation выполняется только после drain
pre-V32 backend instances.
V33 stage-ит inactive `chapter-1-v17` с 30-м узлом
`first-light-causeway`. Миграция не меняет active v16,
`roadmap_user_state`, `pet_progress` или текущие `expedition_progress` rows;
activation выполняется только после drain pre-V33 backend instances.
V34 backfill-ит все существующие `expedition_progress` как первый
поход, добавляет durable receipt старта нового похода и переносит
уникальность event resolution на `(user, expedition, event, journey)`.
Существующие progress, XP, bond, эволюция, skills, inventory и equipment
не изменяются.

## 8. Конкурентность и транзакции

- transaction-scoped advisory lock по user или user+expedition;
- row lock wallet/progression/inventory при изменении;
- idempotency lookup до мутации;
- journey start под user+expedition lock сначала replay-ит receipt,
  затем проверяет pending result, `expectedJourneyNumber` и `COMPLETED`,
  после чего одной транзакцией обнуляет только route state и
  увеличивает номер похода;
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
  platform, crafting, item upgrade, equipment, expedition advance/resolution
  и result ACK;
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
- item upgrade разделяет user lock с crafting, затем получает общий expedition
  lock. Он блокирует target unique item и material stacks, сохраняет тот же
  `itemInstanceId`, debit ledger и immutable response одним commit; exact replay
  выполняется до pending-result/content gates;
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
  boundary до advance/resolution/new crafting/item-upgrade mutation;
- ACK после account-deletion subject lock фиксирует одно post-lock время и
  заполняет им `acknowledged_at` условным `UPDATE`, только пока поле `NULL`;
  тот же commit создаёт ACK milestone, replay читает сохранённое время без
  повторной мутации, а БД запрещает последующую правку timestamp;
- read endpoints не создают zero-state;
- Home, platform snapshot и content bootstrap читают связанные state/facts/
  content/remote-config секции из одного repeatable-read snapshot; первый
  PostgreSQL statement одновременно фиксирует snapshot и возвращаемый
  `serverTime`;
- compass analytics читает eligible users, client impressions и gameplay
  receipts из одного repeatable-read snapshot;
- retention analytics один раз фиксирует `generatedAt` и для D1/D7/D30
  независимо выбирает только когорты с полностью завершившимся целевым
  UTC-днём. `retainedUsers / eligibleUsers` и onboarding counters читаются из
  того же repeatable-read snapshot, поэтому рост новой когорты не занижает
  зрелые retention rates и конкурентная запись не смешивает границы ответа.
  `generatedAt` и `cohortSize` возвращаются первым PostgreSQL statement и
  поэтому описывают именно момент фиксации этого snapshot.

## 9. Ключевые инварианты

1. Клиент не задаёт accepted delta, rewards или баланс.
2. Один idempotency key не создаёт повторное списание/начисление.
3. Тот же key с другим payload возвращает conflict.
3a. Для activity пункты 2–3 используют durable receipt внутри retention
    window. После cleanup reuse key является новой operation generation;
    versioned fingerprint-based ledger source не сталкивается со старой
    записью, а дневной high-watermark не допускает повторной ENERGY.
3b. `authoritativeTotal` и каждый `buckets[].steps` должны явно присутствовать
    как неотрицательные JSON-числа. Missing/null отклоняется на request boundary
    до user/device state и durable receipt; явный ноль остаётся валидным.
3c. `PlatformCommandRequest.payload` должен явно присутствовать как JSON object.
    Missing/null отклоняется до application service и durable platform receipt;
    явный пустой object остаётся валидным для команд без собственных полей.
3d. Типизированные `authoritativeTotal`, `buckets[].steps` и `energyToSpend`
    принимаются только из JSON number через exact signed-`long` conversion.
    Математически целая decimal-запись допустима; ненулевая дробная часть,
    строковый JSON type и переполнение отклоняются до controller, state/ledger
    mutation и durable receipt. Общий persistence `ObjectMapper` не меняется.
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
9a. Новая platform-команда принимает exact payload keys своего canonical
    `commandType`; проигнорированное поле не может стать частью нового durable
    fingerprint. Exact historical receipt проверяется раньше schema gate и
    сохраняет replay compatibility без повторной мутации.
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
45. Item upgrade не принимает client-owned target/cost/result, не создаёт новый
    unique instance и не допускает частичного material debit; уровень и rarity
    переходят последовательно `1/UNCOMMON → 2/RARE → 3/EPIC`.

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
the validated Auth0 access token. Email, Apple, Google and Telegram terminate at
Auth0 Universal Login; Telegram is an upstream Enterprise OIDC connection and
its ID/access tokens never reach the native session or game API. See ADR 0018,
ADR 0035 and ADR 0037.

### Account data-control boundary

Экспорт читается только через authenticated API, временно staging-ится для
системного share sheet и удаляется из sandbox приложения после передачи.
Backend на одном database connection сначала берёт session-level account
subject lock, затем начинает read-only `REPEATABLE_READ` и строит единый
snapshot. Первый statement возвращает PostgreSQL `statement_timestamp()` как
`exportedAt` того же snapshot; application clock и задержка поздних секций его
не сдвигают. Удаление поэтому сериализуется с export целиком: оно либо ждёт
завершения snapshot, либо уже существующая receipt отклоняет export. Второй
pool slot не нужен; session lock явно снимается до возврата connection.
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
