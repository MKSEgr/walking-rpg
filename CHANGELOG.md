# Changelog

Все заметные изменения проекта фиксируются здесь.

## [Unreleased]

### Added

- `alpha-rc1` release dossier с immutable post-bootstrap `master` SHA/tree,
  exact integrated push runs, build metadata и проверенными SHA-256 для
  unsigned/no-codesign release artifacts;
- idempotent `POST /api/v1/activity/sync` и PostgreSQL activity high-watermark;
- ENERGY wallet и append-only credit/debit ledger;
- production `GET /api/v1/home`;
- персональная дневная цель `adaptive-median-v1` по accepted activity history;
- прозрачный `dailyGoalPolicy` в home response и Flutter UI;
- persistent starter expedition и `POST /api/v1/expeditions/{expeditionId}/advance`;
- первое событие `signal-source-v1` с двумя server-owned choices;
- `POST /api/v1/events/{eventId}/resolve`;
- persistent `pilot_progress`, `pet_progress` и exact event response replay;
- Flutter clients для home, activity, expedition и event commands;
- pluggable `StepSource`;
- Apple HealthKit foreground step source;
- Google Health Connect foreground step source;
- Android Activity Recognition permission flow;
- IANA device timezone provider;
- development-only step source;
- retry coordinator, сохраняющий idempotency key для одного reading после ошибки;
- foreground durable mobile command outbox для activity, expedition и event-команд;
- versioned atomic file store с temporary/backup recovery и corruption detection;
- startup replay с прежним payload/idempotency key и authoritative home reload;
- versioned Android/iOS host projects;
- Android Health Connect и iOS HealthKit native configuration;
- Android debug APK и iOS Simulator build jobs;
- unit/API/PostgreSQL integration/mobile/platform tests;
- `starter-v2` со вторым узлом `lumen-gate` и событием `echo-vault-v1`;
- persistent `inventory_stack` и append-only `inventory_ledger`;
- material rewards `lumen-shard` и `echo-thread` с exact idempotent replay;
- Flyway V5, переводящий завершённых пользователей `starter-v1` на второй узел без повторной награды;
- inventory и material reward snapshots в production home/Flutter UI;
- ADR по activity, economy, home, expedition, event resolution, platform Health boundary, durable mobile outbox и inventory;
- GitHub Actions CI и PR template;
- Flutter `Путевой журнал` для platform snapshot: onboarding, питомцы, навыки, задания, сезон, недельный маршрут, отряды, косметика и эксперименты;
- typed `PlatformApiClient`, `PlatformSnapshot` и `PlatformCommandResult`;
- restart-safe `PLATFORM_COMMAND` в mobile command outbox;
- нижняя навигация между экспедицией и путевым журналом;
- versioned read-only cache последних подтверждённых `home` и `platform` snapshots;
- явный офлайн-баннер, TTL, corruption recovery и запрет mutations поверх cached state;
- Spring Security OAuth2 Resource Server и production JWT profile;
- canonical request identity из JWT `sub`, actor/device claim mapping и `ROLE_USER`/`ROLE_ADMIN` authorization;
- dev-header authentication, изолированная только в local/test profile;
- security filter-chain, identity и controller regression tests.
- mobile-экран «Аккаунт и данные» с JSON export/share;
- двухэтапное подтверждение удаления и fresh OIDC login той же учётной записи;
- idempotent `POST /api/v1/account/deletion-requests` с постоянной квитанцией;
- Flyway V7 с минимизированным deletion receipt без raw OIDC subject;
- `410 ACCOUNT_DELETED` guard против пересоздания данных старым Bearer-токеном;
- общий authenticated-request guard, блокирующий удалённый subject до любого
  user/admin controller;
- server-side `auth_time` gate для удаления аккаунта и `max_age=0` в mobile
  OIDC step-up;
- удаление временной локальной копии JSON сразу после системного share flow;
- guided mobile «Первый путь»: разрешение шагов, первая ENERGY, выбор питомца,
  первый узел и первое событие в одном flow;
- восстановление onboarding milestones из authoritative gameplay facts после
  process restart;
- независимый progression для Искры, Мха и Руны с active-pet home/event
  integration;
- Flyway V9 с exact-once `first_journey_milestone`, legacy backfill и
  транзакционными triggers на activity/economy/platform/expedition/event;
- admin cohort read model conversion и p50/p90 time-to-first-* с отдельной
  data-quality статистикой authoritative/backfilled records;
- milestones первого пути в JSON export и каскадном удалении аккаунта;
- durable `receiptId` и nullable `nextNode` в event-resolution response;
- top-level `pendingEventResult` в `GET /home` и bodyless owner-scoped
  `POST /api/v1/event-results/{receiptId}/acknowledge`;
- Flyway V10 с receipt/delivery-mode/next-node/ack state; backfill и rolling
  legacy writers auto-acknowledged и не всплывают повторно;
- restart-visible mobile result card и persist-before-send
  `EVENT_RESULT_ACKNOWLEDGEMENT` в GAMEPLAY outbox;
- ADR 0022 о durable event-result handoff;
- Flyway V11 с immutable
  `FIRST_EVENT_RESULT_ACKNOWLEDGED`, V10→V11 backfill и transactional
  `NULL → acknowledged_at` trigger;
- final first-journey delivery stage в cohort analytics: explicit durable ACK
  участвует в p50/p90, legacy auto-ACK остаётся только backfilled conversion;
- ADR 0023 об ACK-aware evidence первого пути;
- Flutter recovery center **«Сохранённые действия»** с owner-scoped badge,
  safe `PENDING` replay, подтверждённым dismiss terminal `FAILED` и
  fail-closed corruption state;
- однократный startup replay на lifetime authenticated mobile runtime без
  автоматической повторной отправки или повторного показа исторического
  результата при resume/reload/remount;
- coarse mobile command failure categories без вывода raw payload/key/error в
  presentation;
- ADR 0024 о безопасном recovery и изоляции telemetry;
- явные provider modes:
  `walking-rpg.providers.payment=sandbox|disabled` и
  `walking-rpg.providers.push=development|disabled`;
- disabled payment/push providers и protected-profile startup guard для
  `stage`/`prod`;
- отдельный `application-stage.yml` и fail-closed PostgreSQL datasource
  validation с обязательным verified TLS;
- Flyway V12, выключающий `sandboxPaymentsEnabled` и
  `backgroundHealthSyncEnabled` во всех существующих remote-config snapshots;
- effective `sandboxPaymentsEnabled`, учитывающий доступность provider, и
  скрытие sandbox purchase UI в release build и для disabled/cached snapshot;
- ADR 0025 о production provider isolation;
- явный Android `compileSdk` / `targetSdk` API 36 contract при сохранении
  `minSdk = 26`;
- fail-closed Android protected-signing boundary с внешними properties и
  upload keystore без repository-local или debug-key fallback;
- synthetic signing rehearsal без сохраняемого signed artifact и runbook для
  Android/iOS protected signing;
- ADR 0027 об API 36 и protected mobile signing;
- internal-only `ValidationCenterScreen` с явным compile-time flag,
  fail-closed запретом в release и exact source/app/build metadata;
- owner/session-bound in-memory journal provider/permission/read/sync/
  authoritative checkpoints, ограниченный одним запуском и 64 записями;
- redacted `walking-rpg-device-validation-evidence-v1` export до 64 KiB с
  SHA-256 checksum, временным JSON share/delete и ADR 0028;
- server-authoritative рецепт `resonance-compass-v1` и
  `POST /api/v1/crafting/recipes/{recipeId}/craft`;
- атомарное списание `2 × lumen-shard + 1 × echo-thread`, отрицательные
  audited inventory-ledger записи и уникальный `resonance-compass`;
- persistent `unique_inventory_item`, exact replay snapshot в
  `processed_crafting_command`/`processed_crafting_ingredient` и Flyway V13;
- additive `craftingRecipes`/inventory `kind` в `GET /home`, Flutter
  **«Мастерская»** и restart-safe `CRAFTING` в GAMEPLAY outbox;
- account export/delete и synthetic backup/restore coverage для crafting state;
- ADR 0029 о server-authoritative crafting и unique inventory;
- versioned `equipment-v1`, persistent slot `NAVIGATION` и desired-state
  `POST /api/v1/equipment/slots/{slotId}/equip|unequip` с exact replay;
- owned-item FK, single-slot uniqueness, immutable
  `processed_equipment_command` и Flyway V14;
- additive equipment/item/choice-requirement projection в `GET /home`, Flutter
  **«Снаряжение»** и restart-safe `EQUIPMENT` в GAMEPLAY outbox;
- `chapter-1-v2` с 18 основными узлами и optional `resonance-pocket`, который
  открывается из `mirror-delta-v1` только экипированным
  `resonance-compass`;
- staged `content_release` activation: V14 оставляет v1 активной, а новый
  Home/event/bootstrap открывает v2 только после cluster-wide drain;
- account export/delete, synthetic backup/restore, unit/API/PostgreSQL race и
  widget coverage для equipment/optional route;
- ADR 0030 о server-authoritative equipment и gated routes;
- idempotent `RECORD_COMPASS_IMPRESSION` с canonical recipe/route attributes,
  network-only Home instrumentation и release-gated route telemetry;
- server-reserved compass event names, которые public telemetry ingress
  отклоняет до user/event mutation;
- admin-only cohort endpoint
  `GET /api/v1/admin/platform/analytics/compass-journey` с раздельными
  client-reported показами и authoritative craft/equip/route stages;
- repeatable-read compass funnel с activation-bounded route baseline, ordered
  p50/p90, instrumentation/out-of-order/target-without-start quality counters и
  PostgreSQL/widget/outbox/cache tests;
- Flyway V15 `content_release.activated_at` с first-write timestamp, DB-level
  immutability, fail-closed explicit history для pre-V15 v2 republish и stable
  route baseline при same-version republish;
- ADR 0031 о границе client impressions и authoritative gameplay stages;
- Flyway V17 `platform_cosmetic_slot_state`, additive
  `userState.equippedCosmetics`, legacy-selection backfill и account export/
  delete/backup coverage для независимых `PILOT`, `PET` и `PROFILE` slots;
- ADR 0032 о server-authoritative cosmetic equipment и rolling compatibility;
- ADR 0033 и recursive canonical JSON fingerprint для platform-команд с
  bounded replay compatibility для ранее сохранённых двухполевых payload;
- ADR 0036 и DigitalOcean internal-alpha stage contract с non-root Java 21
  container, PostgreSQL 17 `verify-full` CA delivery, reviewed App Spec,
  раздельными platform probes, alert policy, redacted evidence template и
  owner deployment/rollback runbook;

### Changed

- типизированные API integer-поля `authoritativeTotal`, `buckets[].steps` и
  `energyToSpend` теперь используют exact signed-`long` JSON-number boundary:
  ненулевая дробная часть, строковый type и переполнение отклоняются до
  controller/state/ledger/receipt, а математически целая decimal-запись
  сохраняет прежнее значение без Jackson truncation;
- новые platform-команды теперь принимают exact payload keys своего canonical
  `commandType`: ignored client fields отклоняются до runtime/state/event writes
  и не создают ложные idempotency fingerprints; lookup старого receipt остаётся
  раньше schema gate для безопасного exact replay исторических команд;
- remote-config publication теперь один раз канонизирует exact-integer JSON
  numbers и trimmed `seasonId` до lock: active row, immediate admin response и
  последующий public bootstrap больше не представляют один config как `30.0`
  против `30` или как raw ID с граничными пробелами;
- admin publication responses теперь возвращают тот же trimmed canonical
  version identifier, который записан как active remote config/content release:
  surrounding whitespace больше не создаёт расхождение immediate response с
  последующим authoritative read;
- admin content release теперь сохраняет missing/null `content` до Bean
  Validation и требует непустой JSON object: повреждённая публикация
  отклоняется до application service и publication lock, а непустой content
  сохраняет прежний успешный контракт;
- platform command теперь отличает явный пустой `payload: {}` от
  отсутствующего/null payload: неполная команда отклоняется до application
  service, state mutation и durable idempotency receipt;
- activity sync теперь отличает явный ноль от отсутствующего/null
  `authoritativeTotal` и `buckets[].steps`: неполный payload отклоняется до
  user/device state, ENERGY и durable idempotency receipt, поэтому повреждённая
  outbox-команда не подтверждается как успешный zero-sync;
- account export теперь фиксирует `exportedAt` первым PostgreSQL
  `statement_timestamp()` той же ручной read-only `REPEATABLE_READ`
  транзакции: рассинхронизация JVM clock и поздняя блокировка одной из секций
  больше не датируют единый export snapshot вне его observation boundary;
- production Home, live platform snapshot и content bootstrap теперь начинают
  `REPEATABLE_READ` общим PostgreSQL `statement_timestamp()` и возвращают его
  как `serverTime`: поздняя блокировка следующей секции и рассинхронизация JVM
  clock больше не датируют старый snapshot временем после его observation
  boundary; command timestamps и JSON shape не меняются;
- retention, first-journey и compass analytics теперь получают `generatedAt`
  из PostgreSQL `statement_timestamp()` в том же первом statement, который
  фиксирует population count и `REPEATABLE_READ` snapshot: задержка следующих
  секций и рассинхронизация application clock больше не датируют один snapshot
  раньше или позже его фактической observation boundary;
- D1/D7/D30 retention rates теперь используют отдельные fully-observed
  `eligibleUsers` на едином `generatedAt`: новые аккаунты с незавершённым
  целевым UTC-днём больше не занижают зрелые cohort rates;
- account export теперь на одном connection удерживает общий subject-level
  deletion lock до конца `REPEATABLE_READ` snapshot: deletion не может
  удалить строки во время выгрузки, уже удалённый subject получает
  `ACCOUNT_DELETED`, а `DB_POOL_SIZE=1` не создаёт nested-connection deadlock;
- новые activity ENERGY ledger entries используют versioned operation source
  `v2:<requestFingerprint>` вместо одного `deviceId + idempotencyKey`:
  повторное использование key после retention durable receipt не возвращает
  исторический wallet snapshot и не создаёт ложный ledger conflict;
- activity high-watermark `updated_at` и durable operation `created_at` теперь
  используют тот же post-user-lock `serverTime`: Home `lastActivitySyncAt`,
  account export и retention ordering отражают фактическую сериализацию sync;
- `serverTime` новых squad create/join/leave теперь фиксируется после общего
  squad advisory lock: membership, platform state, audit event и durable
  response отражают фактический межпользовательский serialized порядок;
- время authenticated telemetry/crash ingestion, push registration, test push
  и tester cohort upsert теперь фиксируется после account-deletion subject
  lock; `received_at` и связанные user/device timestamps отражают фактический
  serialized порядок, включая переход через UTC day boundary;
- `serverTime` нового event-result acknowledgement теперь фиксируется после
  account-deletion subject lock: durable ACK и первый onboarding milestone не
  могут предшествовать уже завершённой serialized account mutation;
- `serverTime` нового event resolution теперь фиксируется после общего
  user+expedition lock: progression, material reward, expedition transition и
  durable result не могут предшествовать уже завершённой serialized mutation;
- `serverTime` нового expedition advance теперь фиксируется после общего
  user+expedition lock: ENERGY debit/ledger, progress и durable response не
  могут предшествовать уже завершённой serialized expedition mutation;
- `serverTime` новой activity sync теперь фиксируется после user lock:
  validation, device presence, risk assessment, ENERGY ledger и durable
  response больше не могут предшествовать уже завершённой serialized command;
- `serverTime` новой platform-команды теперь фиксируется после user lock и
  frozen runtime reads: route impression, принятый для новой active content
  version, больше не сохраняется раньше наблюдаемой content activation;
- anti-fraud bucket totals и sudden-growth threshold теперь вычисляются без
  `long` wraparound: переполнение bucket sum сохраняется как
  `BUCKET_TOTAL_MISMATCH`, а недостижимый `8×` threshold не создаёт ложный
  `SUDDEN_MULTIPLIER_GROWTH`;
- новая platform-команда теперь фиксирует active content version один раз:
  route-impression validation, `snapshot.contentVersion`, catalog и durable
  response используют одну версию, а конкурентная content publication видна
  только следующей команде или read request;
- новая platform-команда теперь фиксирует один effective remote config после
  user serialization и использует его для feature/provider gates, стоимости
  недельного маршрута, achievements, catalog и response; параллельная admin-
  публикация целиком применяется только к следующей команде или read request;
- exact platform replay проецирует `sandboxPaymentsEnabled` монотонно
  fail-closed: текущие config/provider могут отключить исходный `true`, но
  более поздняя admin-публикация не расширяет сохранённый `false` до `true`;
- platform snapshot и content bootstrap теперь проецируют `seasonId` и
  `weeklyRouteEnergy` из одного effective remote config: catalog, user-state
  threshold и remote config больше не сообщают разные значения, а
  `catalogDigest` отражает фактически выданную runtime-проекцию;
- `catalogDigest` теперь вычисляется по каноническому содержимому platform
  catalog, а не только по набору его верхнеуровневых ключей; разные content
  versions получают разные стабильные SHA-256 значения, не зависящие от
  форматирования API response;
- equipment `itemInstanceId` и event-result `receiptId` принимаются только в
  полном UUID-формате; shortened/malformed aliases возвращают единый
  `400 VALIDATION_ERROR` до service/DB, а полный uppercase input сохраняет
  совместимость и канонизируется;
- activity-sync exact replay повторно оценивает request-scoped `attestation` и
  сохраняет отдельный shadow-mode risk assessment, не меняя исходный response,
  activity high-watermark или ENERGY ledger;
- `JOIN_SQUAD` проверяет полный UUID и нормализует его до state/DB mutation;
  malformed и укороченные значения возвращают `400 VALIDATION_ERROR` без
  частично сохранённого platform state;
- `processed_roadmap_command.request_fingerprint` больше не зависит от порядка
  ключей JSON object или случайного iteration order `Map.copyOf` между JVM;
  выделенный immutable writer также изолирует persistent hash от pretty-print и
  других настроек API `ObjectMapper` между deployment-ами; default encoding,
  array order, scalar value/type и конфликт другого payload сохранены; bounded
  replay-only candidates покрывают compact/indented hashes предыдущего shared
  mapper без записи legacy-формата для новых команд;
- first playable расширен до двух узлов, двух событий и persistent material reward;
- home read-model возвращает pilot XP, pet bond, event choices, material outcome, inventory и server-owned личную цель;
- Android/iOS mobile по умолчанию использует platform health source;
- demo activity source включается только явным feature flag;
- mobile после каждой команды перечитывает server state без optimistic update;
- host-проекты больше не генерируются bootstrap-скриптами;
- CI дополнительно компилирует нативные Android/iOS приложения;
- roadmap разделяет готовую Health implementation и ещё не пройденную physical-device validation;
- mobile-команды разделены на независимые ACTIVITY/GAMEPLAY lanes с FIFO внутри каждой lane;
- backend-контроллеры больше не принимают user/device/actor headers: identity приходит из `SecurityContext`;
- production defaults стали fail-closed: JWT включён, demo endpoint выключен.
- destructive fresh-auth guard преобразует OIDC `auth_time` в exact epoch
  nanoseconds, больше не округляет дробную NumericDate через `double` и
  fail-closed отклоняет уже lossy floating-point claim;
- signed OIDC `sub`, actor и stable-device claims больше не схлопываются через
  `trim` или неявное преобразование JSON-типа: compact JWS payload проверяется
  до Nimbus/Spring registered-claim conversion, поэтому `sub` принимается
  только как исходная JSON-строка, а
  неоднозначные, управляющие и не помещающиеся в persistent identity boundary
  значения отклоняются до controller; присутствующий malformed optional
  actor/device claim больше не подменяется subject/null fallback, а защищённый
  Prometheus валидирует те же claims без account-state lookup;
- ручные onboarding-кнопки в «Путевом журнале» заменены на продолжение
  реального первого пути;
- `SELECT_PET` одновременно сохраняет выбор питомца и milestone, а event reward
  начисляет bond выбранному питомцу;
- quest bond, evolution level, event reward и home теперь сходятся в одной
  канонической pet progression без потери старого platform progress;
- сюжетные тексты первого пути больше не предполагают, что всегда выбрана
  Искра; стабильные command/choice IDs сохранены;
- haptic feedback первого пути исключён из критического пути server reload;
- backend блокирует новый advance/resolution только до acknowledgement
  capable pending event receipt;
- `receiptId` стал единственным server-side idempotency scope ACK; повтор
  возвращает стабильные `acknowledgedAt` и `serverTime`;
- durable handoff включается capability
  `X-Walking-RPG-Capabilities: durable-event-result-v1` только после явной
  cluster activation; exact replay сохраняет mode первого запроса, старые
  backend instances drain-ятся до активации, rollback требует ноль pending
  receipts.
- `acknowledged_at` становится immutable после первого успешного ACK, а
  `ONBOARDING_COMPLETED` сохраняет исходную V9-семантику отдельно от delivery.
- mobile outbox использует отдельную `TELEMETRY` lane для
  `RECORD_EXPERIMENT_EXPOSURE` и `RECORD_COMPASS_IMPRESSION`, сохраняет
  `ACTIVITY → GAMEPLAY`, replay-ит close-tracked telemetry параллельно с этой
  цепочкой без задержки startup result и выполняет startup replay один раз в
  authenticated shell;
- retryable ACTIVITY удерживает зависимую GAMEPLAY в `PENDING`, а успешный
  manual recovery перечитывает authoritative state без перемонтирования main
  shell; auth boundary закрывает owner-scoped overlay routes;
- v1 command store остаётся совместимым: telemetry lane выводится из
  сохранённого payload, а `lastFailureCategory` является optional additive
  полем.
- sandbox payment и development push больше не регистрируются безусловно:
  они требуют matching property и активный `local`/`test`, а `stage`/`prod`
  принудительно используют `disabled`;
- новая недоступная покупка отклоняется до создания user/payment state, но
  replay сохранённой покупки возвращает прежний outcome/state без нового
  provider call или mutation; capability fields проецируются заново и могут
  стать `false` после disable;
- legacy `BUY_COSMETIC` и canonical `PURCHASE_COSMETIC` разделяют один
  idempotency scope: cross-alias replay возвращает первый immutable response,
  а другой product под тем же key отклоняется до provider call; canonical и
  legacy replay records сохраняются атомарно для mixed-version rollout;
- platform command payload и remote config больше не усекают дробные JSON
  numbers через `Number.longValue()`: `energyToSpend`, season `level`,
  `activityRetentionDays` и `weeklyRouteEnergy` требуют точного целого,
  отклоняются до commit и не оставляют частичного state;
- command/impression и административные platform/provider/status tokens теперь
  используют locale-neutral uppercase: JVM locale вроде `tr-TR` больше не
  меняет маршрутизацию команд и сохраняемые enum-like значения;
- platform snapshot не объявляет sandbox payment доступным при disabled
  provider, а mobile не показывает purchase action в release build, для
  `false` или cached snapshot.
- `EQUIP_COSMETIC` теперь выводит slot из server catalog и заменяет только его;
  `activeCosmeticId` сохранён как legacy pointer, поэтому старый клиент и
  backend могут участвовать в rolling deployment без удаления других slots.
- release metadata и backend/Android/iOS candidates привязаны к одному exact
  source SHA/tree; protected signing связывает post-merge `master` с
  CODEOWNER-approved PR по tree SHA, а backend CI selector gate предотвращает
  пропуск новых тестов.
- `inventory_ledger` принимает ненулевые credit/debit операции при
  неотрицательном `quantityAfter`; event rewards по-прежнему только
  положительные, а crafting consumption выполняется одной транзакцией с
  unique-item и immutable response.
- новая crafting mutation разделяет expedition serialization boundary с
  advance/event resolution и блокируется pending event receipt; exact replay
  уже выполненной craft-команды остаётся доступен до ACK.
- новая equipment mutation использует тот же pending-receipt/expedition
  boundary после exact replay; event prerequisite проверяется backend после
  expedition lock, а mobile availability остаётся только UX projection.
- locked gated choices проецируются отдельно в additive `lockedChoices`, чтобы
  legacy mobile видел только рабочий основной маршрут; новый client объединяет
  их с `choices`, а подтверждённые equipment 4xx становятся terminal recovery
  records и не блокируют GAMEPLAY lane бесконечно.

## [0.1.0] — 2026-07-25

### Added

- первоначальная концепция продукта;
- монорепозиторий;
- Java/Spring Boot backend shell;
- Flutter mobile shell;
- архитектурная документация;
- roadmap, backlog и первые ADR;
- Docker Compose с PostgreSQL.

## Mobile OIDC session lifecycle

- Added Authorization Code + PKCE login for Android and iOS.
- Added Keychain/Android secure token storage and serialized refresh handling.
- Replaced client-supplied identity headers with same-origin Bearer transport.
- Added account-scoped cache/outbox cleanup and a runtime shutdown barrier.
- Added fresh-login confirmation for destructive account operations.
