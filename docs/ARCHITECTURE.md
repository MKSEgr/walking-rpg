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
inventory      — stack и reward ledger
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

## 5. Durable mobile commands

```text
ACTIVITY
└── ACTIVITY_SYNC

GAMEPLAY
├── EXPEDITION_ADVANCE
├── EVENT_RESOLUTION
├── EVENT_RESULT_ACKNOWLEDGEMENT
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

Platform snapshot содержит onboarding, три питомца, skills, quests, achievements, season, weekly route, squad, cosmetics, experiments и remote config. После успешной команды UI заменяет состояние snapshot-ом backend и перечитывает home; optimistic rewards не применяются.

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

`roadmap_user_state.activePetId` — источник выбора питомца. Общий
`ActivePetProvider` связывает platform state с home/progression: event reward
берёт тот же per-user advisory lock, что и `SELECT_PET`, затем блокирует и
изменяет строку выбранного `pet_id`; pilot XP остаётся общим. Quest bond и
evolution level синхронизируются с той же `pet_progress` строкой в транзакции
platform-команды. Для старого раздвоенного состояния read/reward использует
максимальные подтверждённые level/bond. Отсутствующее platform state безопасно
использует `spark-v1`.

## 6. Контент

Активная версия `chapter-1-v1` содержит 18 последовательных узлов от `outer-beacon` до `dawn-relay`, server-owned choices и material rewards. Stable IDs сохраняются между версиями; mutable user state отделён от definitions. `content_release` и remote config позволяют публиковать активную версию без переписывания исторических command responses.

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
roadmap_user_state, processed_roadmap_command
remote_config_snapshot, content_release
roadmap_squad, roadmap_squad_member
platform_event, platform_crash_report
push_registration, payment_intent, tester_cohort_member
activity_risk_assessment
first_journey_milestone
```

`processed_*` хранит fingerprint и immutable response. Повтор после restart не
меняет состояние второй раз и возвращает канонический сохранённый результат.
V10 расширяет event resolution receipt/delivery-mode/next-node/ACK state;
исторические результаты получают receipt, но backfill-ятся acknowledged, чтобы
не показывать старые награды повторно. Defaults и `BEFORE INSERT` trigger
также auto-acknowledge старый backend writer при rolling upgrade.
V11 добавляет ACK milestone и запрещает менять уже установленный
`acknowledged_at`; state-only legacy completion без receipt не превращается в
ложный ACK. Новый durable row обязан начинаться с
`handoff_required = true, acknowledged_at = NULL`; pre-acknowledged INSERT
отклоняется, а delivery mode после INSERT неизменяем.

## 8. Конкурентность и транзакции

- transaction-scoped advisory lock по user или user+expedition;
- row lock wallet/progression/inventory при изменении;
- idempotency lookup до мутации;
- source uniqueness в ledger;
- один transaction commit для связанных изменений;
- capable pending result проверяется под тем же user+expedition serialization
  boundary до advance/resolution;
- ACK заполняет `acknowledged_at` условным `UPDATE`, только пока поле `NULL`;
  тот же commit создаёт ACK milestone, replay читает сохранённое время без
  повторной мутации, а БД запрещает последующую правку timestamp;
- read endpoints не создают zero-state.

## 9. Ключевые инварианты

1. Клиент не задаёт accepted delta, rewards или баланс.
2. Один idempotency key не создаёт повторное списание/начисление.
3. Тот же key с другим payload возвращает conflict.
4. Wallet не становится отрицательным и меняется через ledger.
5. Activity high-watermark пользователя общий для устройств и не уменьшается.
6. Inventory stack меняется через inventory ledger.
7. Historical response не заменяется более новым snapshot.
8. Process restart не меняет pending payload/key.
9. Platform command first response равен replayed response.
10. Risk engine работает в shadow mode до внешней калибровки.
11. User/device/actor не принимаются контроллерами из произвольных headers или body в production.
12. Валидный JWT без прикладной `ROLE_USER`/`ROLE_ADMIN` не даёт доступ к API.
13. Event reward с `handoffRequired = true` считается переданным UI только
    после owner-scoped ACK соответствующего `receiptId`; legacy mode
    auto-acknowledged.
14. Пока capable event result pending, новый advance или resolution той же
    экспедиции запрещён.
15. ACK не имеет request body; replay возвращает стабильные
    `acknowledgedAt/serverTime`.
16. Capability не входит в idempotency fingerprint; exact replay возвращает
    delivery mode первого commit.
17. `ONBOARDING_COMPLETED` сохраняет V9-семантику; доказательством доставки
    первого результата является отдельный
    `FIRST_EVENT_RESULT_ACKNOWLEDGED`.
18. `PENDING` mobile-команда не удаляется пользовательским действием и
    повторяется только с исходным payload/key.
19. Telemetry failure не удерживает ACTIVITY или GAMEPLAY lane.
20. Recovery presentation не раскрывает command payload, idempotency key,
    receipt, raw error или локальный путь.

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

Базовый режим backend — `jwt`; demo endpoint выключен. `dev-header` существует только в явных `local`/`test` профилях и изолирует технические headers внутри одного filter-а. В production `/api/v1/admin/**` требует `ROLE_ADMIN`, остальные защищённые `/api/v1/**` — `ROLE_USER`.

Activity device identity получается из подписанного session/device claim и хранится как SHA-256 pseudonym. Произвольный `X-Device-Id` в JWT mode игнорируется. Публичными остаются только health/system info/content bootstrap и anonymous telemetry/crash ingestion.

Mobile Authorization Code + PKCE, secure token storage, refresh и logout
реализованы как отдельная boundary; production IdP configuration и
device-validation остаются внешними gates. Подробности:
`docs/adr/0018-mobile-oidc-session.md`.

## 11. Health boundary

```text
StepSource
├── PlatformHealthStepSource
│   ├── HealthGateway
│   ├── ActivityRecognitionGateway
│   └── DeviceTimeZoneProvider
└── DevelopmentStepSource
```

Только `STEPS READ`, local midnight → now, IANA timezone и foreground/manual sync. Resume fallback не выдаётся за гарантированную background delivery. Физическая матрица описана в `DEVICE_VALIDATION_PROTOCOL.md`.

## 12. Offline read model

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

## 13. Release-quality model

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

CI не хранит signing material и не выдаёт неподписанный candidate за публикуемый build. Device, push, payment, beta и store gates получают статус `VALIDATED` только после evidence.

## 14. Branch protection

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
См. ADR 0019.
