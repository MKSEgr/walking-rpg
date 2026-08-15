# Product backlog

## P0 — physical Health validation

### US-001. Получить реальные шаги

Как пользователь, я хочу разрешить приложению читать мои шаги, чтобы реальная прогулка влияла на игру.

Критерии:

- разрешение запрашивается в контексте пользы;
- отказ не ломает home screen;
- читается cumulative total текущего локального дня;
- несколько источников не создают клиентское суммирование;
- удаление/коррекция platform record не создаёт отрицательную награду;
- Android и iOS используют один `StepSource` domain contract;
- mobile не отправляет сырые health samples;
- результат проходит через существующий server-authoritative sync.

**Статус:** код, tests, Android APK и iOS Simulator build готовы. Физические iPhone/Android и телефон + часы не проверены.

### US-002. Идемпотентно синхронизировать активность

Как система, я хочу принимать cumulative authoritative total и начислять только новую активность.

**Статус:** реализовано с PostgreSQL, wallet/ledger, multi-device lock, Flutter client, platform source, foreground durable outbox, retention и shadow-mode risk/attestation signals.

### US-013. Собрать обезличенное evidence физической проверки

Как внутренний тестировщик, я хочу получить ограниченный журнал provider →
permission → read → sync → authoritative reload, чтобы связать физический прогон
с точной версией кода и проверить его без небезопасных логов.

Критерии:

- Validation Center требует явный `ENABLE_VALIDATION_CENTER=true`, доступен
  только в non-release build и отклоняет release-конфигурацию fail-closed;
- build передаёт exact 40-символьный lowercase
  `VALIDATION_SOURCE_GIT_SHA`, а app version и build number читаются из
  фактически установленного native package;
- журнал живёт только в памяти одного authenticated owner и одной ревизии
  auth-сессии, не персистируется и не объединяется после logout/new session/
  account switch;
- фиксируются platform/OS/app/build и typed permission/provider/read/sync/
  authoritative checkpoints;
- в evidence отсутствуют raw samples, tokens, identifiers, endpoints, paths,
  request/response body и raw errors;
- export использует `walking-rpg-device-validation-evidence-v1`, redaction
  policy `walking-rpg-evidence-redaction-v1` и проверяемый SHA-256 checksum;
- journal ограничен 64 entries, JSON — 64 KiB; переполнение не маскируется
  как полный успешный прогон;
- share использует temporary JSON и пытается удалить его после возврата или
  ошибки platform share flow.

**Статус:** код, автоматические tests, ADR, protocol и evidence template
реализованы. Реальные прогоны iPhone/Android, provider/watch matrix,
midnight/timezone, permission revoke и battery evidence не выполнены и остаются
`EXTERNAL_VALIDATION_REQUIRED` в US-001/Roadmap Milestone 1.

## P0 — first playable loop

### US-003. Получить ENERGY

Как пользователь, я хочу увидеть энергию прогулки, чтобы понимать связь движения и игры.

**Статус:** реализовано; mobile после sync перечитывает server-authoritative home.

### US-004. Продвинуть экспедицию

Как пользователь, я хочу тратить ENERGY и последовательно достигать узлов экспедиции.

**Статус:** реализовано для 18 основных узлов `starter-expedition-v1`,
`resonance-pocket`, staged `chapter-1-v3` маршрута через `storm-scriptorium`
и staged `chapter-1-v4` развилки Сада пустоты через `root-memory` или
`light-canopy`; все опциональные ветки возвращаются в основной путь, progress
и debit остаются persistent/idempotent.

### US-005. Разрешить первое событие

Как пользователь, я хочу выбрать действие в событии и получить постоянный результат.

Критерии:

- событие разрешается один раз;
- выбор идемпотентен;
- результат получает durable `receiptId` и хранится сервером до
  acknowledgement;
- pilot XP и pet bond сохраняются;
- home показывает top-level `pendingEventResult` после потери ответа или
  restart;
- следующий advance/resolution запрещён до owner-scoped ACK receipt;
- поздняя ошибка откатывает progression и expedition completion.

**Статус:** реализовано для `signal-source-v1` с choices `analyze-signal` и
стабильным legacy id `trust-spark` (пользовательский текст «Довериться
питомцу»); после resolution открывается второй узел, а result card остаётся
pending до явного подтверждения.

### US-006. Завершить второй узел и получить material reward

Как пользователь, я хочу разрешить второе событие и сохранить найденный материал, чтобы экспедиция давала накопительный предметный результат.

Критерии:

- второй узел открывается после первого события без потери progression;
- advance использует существующий ENERGY ledger и idempotency;
- второе событие имеет два server-owned выбора;
- material reward выдаётся один раз и записывается в inventory ledger;
- home возвращает inventory stack и durable immutable reward snapshot с
  `receiptId` и `nextNode`;
- пользователи `starter-v1` мигрируют на второй узел без повторной награды;
- durable outbox replay-ит second-event command с исходным key.

**Статус:** реализовано для `lumen-gate` / `echo-vault-v1`, items `lumen-shard` и `echo-thread`.

### US-007. Получить персональную дневную цель

Как пользователь, я хочу получать достижимую цель относительно собственной активности, а не общий порог для всех.

Критерии:

- backend использует предыдущие семь локальных дней, не включая текущий;
- baseline — медиана положительных accepted total;
- цель растёт на 5%, округляется до 250 и ограничивается диапазоном 2 000–12 000;
- пока валидных дней меньше трёх, используется стартовая цель 6 000;
- mobile показывает понятное объяснение источника цели;
- `GET /home` остаётся read-only.

**Статус:** policy `adaptive-median-v1`, API metadata и Flutter explanation реализованы; продуктовая проверка параметров остаётся частью device/beta validation.

### US-008. Пройти честный первый путь

Как новый пользователь, я хочу за один понятный маршрут подключить шаги,
получить ENERGY, выбрать питомца, достигнуть узла и принять решение.

Критерии:

- этапы завершаются реальными игровыми действиями;
- выбранный питомец появляется в home и получает event bond;
- маршрут можно отложить и безопасно продолжить после restart;
- подтверждаемые этапы восстанавливаются из server facts;
- cached state не разрешает mutations;
- анимация и вибрация не блокируют progression.

**Статус:** код и автоматические tests готовы. Server-authoritative milestones
и cohort read model отдельно измеряют resolution, завершение platform
onboarding и result-ACK. Continuity conversion для ACK допускает legacy
backfill, а explicit delivery completion считается по
`authoritativeConversionFromStarted`; legacy auto-ACK не участвует в этой
метрике или p50/p90. Фактический темп первых 10 минут, permission UX и
эмоциональная ценность требуют alpha validation на физических устройствах.

### US-009. Не потерять результат события

Как пользователь, я хочу увидеть решение и награду после сетевой ошибки или
перезапуска приложения, прежде чем перейти к следующему узлу.

Критерии:

- capable event resolution атомарно сохраняет уникальный receipt, delivery mode
  и nullable следующий узел вместе с reward/progression;
- `GET /home` возвращает top-level `pendingEventResult`, пока receipt не
  подтверждён;
- result card переживает restart и видна из cached snapshot в read-only режиме;
- ACK использует bodyless
  `POST /api/v1/event-results/{receiptId}/acknowledge`;
- `receiptId` является единственным server-side idempotency scope, replay
  возвращает стабильное время первого ACK;
- mobile сохраняет acknowledgement в durable GAMEPLAY outbox до отправки;
- backend блокирует следующий advance/resolution до ACK только для
  `handoffRequired = true`;
- capability отсутствует у старого mobile или cluster activation gate
  выключен: backend auto-acknowledge результат и не создаёт gameplay gate;
  новый mobile принимает старый response без handoff fields;
- exact replay сохраняет delivery mode первого запроса;
- activation выполняется только после drain старых backend instances; rollback
  требует disabled gate и ноль capable pending receipts;
- V10 помечает backfill и rolling legacy writes acknowledged, чтобы не
  показывать старые награды повторно.
- первый explicit ACK атомарно создаёт immutable
  `FIRST_EVENT_RESULT_ACKNOWLEDGED`; replay не меняет его время;
- legacy auto-ACK и migration backfill видны только как `BACKFILLED`, поэтому
  не выдают resolution time за пользовательское подтверждение.

**Статус:** backend/mobile код и автоматические API, PostgreSQL migration,
outbox и widget tests реализованы. V11 связывает ACK lifecycle с
first-journey analytics без изменения исторической семантики
`ONBOARDING_COMPLETED`. Это не заменяет physical-device и alpha cohort
validation из US-001/US-008.

### US-010. Восстановить сохранённое действие без дублирования

Как alpha-пользователь, я хочу увидеть действие, ответ на которое потерялся,
и безопасно повторить доставку после восстановления сети.

Критерии:

- экран доступен из первого пути, home, путевого журнала и аккаунта;
- список изолирован по authenticated owner;
- UI не показывает payload, idempotency key, fingerprint, receipt, Health
  cursor, raw error или локальный путь;
- `PENDING` повторяется исходным payload/key и не может быть удалён;
- `FAILED` не retry-ится автоматически и удаляется только как локальная
  диагностическая запись после подтверждения;
- успешный replay приводит к authoritative reload;
- retryable ACTIVITY не позволяет replay перейти к зависимой GAMEPLAY;
- startup replay memoize-ится на lifetime authenticated runtime; targeted
  reload/resume не создаёт повторную сетевую попытку и не перемонтирует
  основной shell, а новый runtime после process restart/401 reauthentication
  получает новый replay;
- startup report/error показывается только первому активному UI-владельцу:
  in-flight remount принимает outcome, а завершённый outcome после обработки
  повторно не используется;
- auth boundary закрывает owner-scoped routes;
- corrupt store не очищается и не перезаписывается молча;
- experiment exposure выполняется отдельно от gameplay, сохраняя FIFO внутри
  каждой lane, и не удерживает завершение startup state replay;
- старые v1 records читаются без локальной schema migration.

**Статус:** Flutter runtime/UI и unit/widget/concurrency regression tests
реализованы. Foreground/restart поведение на физических устройствах остаётся
частью alpha validation из US-001/US-008.

### US-011. Не попасть в development provider из protected runtime

Как владелец релиза, я хочу, чтобы защищённые окружения физически не могли
выполнить sandbox payment или development push, даже при ошибочном remote
config.

Критерии:

- `stage`/`prod` несовместимы с `local`/`test`;
- protected backend требует явную PostgreSQL configuration с проверяемым TLS;
- development providers создаются только при explicit opt-in в `local`/`test`;
- в остальных окружениях disabled providers отклоняют новые операции;
- недоступная новая покупка не создаёт user/payment state;
- replay завершённой покупки сохраняет command outcome/user state без нового
  provider call или mutation, но capability fields заново проецируются из
  текущего deployment и после disable могут стать `false`;
- backend возвращает effective sandbox capability с учётом provider, а mobile
  скрывает purchase UI в release build, при `false` и для cached state;
- migration выключает sandbox-payment/background-health flags во всех
  существующих snapshots, но не считается единственной security boundary.

**Статус:** A4a backend/mobile guards, Flyway V12, tests и release-policy checks
реализованы. Production billing/APNs/FCM, secrets, реальный deployment и
physical evidence не реализованы и остаются external gates.

### US-012. Ограничить production operational surface

Как владелец релиза, я хочу иметь проверяемые operational boundaries без
production credential, чтобы code candidate не зависел от небезопасных
framework defaults и не выдавал synthetic CI за реальный deployment.

Критерии:

- anonymous telemetry/crash ingress имеет raw-body, DTO, per-process client и
  global limits; `413/429` не создают database state и не отражают raw payload;
- forwarded headers не становятся доверенной limiter identity;
- client buckets ограничены по количеству и idle TTL, а raw client/IP не
  персистируется и не используется как metric label;
- liveness, readiness и Prometheus имеют разные endpoint semantics;
- protected management listener по умолчанию отделён и привязан к loopback,
  health details скрыты, metrics требуют admin authorization;
- HTTP, datasource, query, transaction и graceful-shutdown waits имеют
  конечные fail-closed bounds;
- synthetic PostgreSQL 17 backup/restore drill применяет Flyway V1–latest,
  проверяет checksum до restore и exact schema/data/sequence manifests после;
- synthetic evidence явно содержит `scope=SYNTHETIC_CI` и
  `productionValidated=false`.

**Статус:** A4b code/config/tests, operational ADR/runbook и synthetic drill
pack реализованы. Production secrets, DNS/TLS endpoint, WAF/distributed
limiter, deployed management network, alerts, backup policy, PITR/RPO/RTO и
датированный restore реального backup остаются external gates.

### US-014. Собрать уникальный предмет из накопленных материалов

Как пользователь, я хочу потратить найденные материалы на постоянный
уникальный предмет, чтобы inventory давал следующую цель после события.

Критерии:

- рецепт, стоимость, имя и результат принадлежат server content;
- `resonance-compass-v1` требует `2 × lumen-shard` и `1 × echo-thread`;
- backend под user-scoped transaction lock проверяет оба stack, списывает их
  без отрицательного остатка, пишет по одному debit ledger entry и создаёт
  единственный `resonance-compass`;
- нехватка любого ingredient не выполняет частичную мутацию;
- повтор исходного `recipeId + idempotencyKey` возвращает exact response без
  второго списания; новый key после создания unique item получает стабильный
  state conflict;
- `GET /home` возвращает additive recipe status `READY`,
  `MISSING_MATERIALS` или `CRAFTED`, ingredients и unique result preview;
- mobile сохраняет `CRAFTING` до отправки в GAMEPLAY outbox, не разрешает
  mutation для cached home/pending event result и после успеха перечитывает
  authoritative home;
- unique inventory и immutable crafting snapshots входят в account export,
  каскадное удаление и backup/restore manifest.

**Статус:** backend/mobile/Flyway V13, unit/API/PostgreSQL/widget tests и
операционные policy checks реализованы. Ценность рецепта и стоимость material
sink требуют beta/economy validation.

### US-015. Экипировать компас и открыть скрытый маршрут

Как пользователь, я хочу экипировать созданный уникальный предмет и получить
новый вариант прохождения, чтобы crafting влиял на игру, а не только на
коллекцию.

Критерии:

- `equipment-v1` содержит server-owned slot `NAVIGATION`, принимающий только
  принадлежащий пользователю `resonance-compass`;
- equip/unequip — desired-state команды с persistent exact replay и конфликтом
  при повторном key с другим payload;
- новая equipment mutation сериализуется с expedition/event/crafting и
  account deletion, а при pending event receipt отклоняется без изменения;
- `GET /home` возвращает slot state, item equipment metadata и availability/
  requirement каждого gated choice;
- `follow-resonance` в `mirror-delta-v1` недоступен без экипированного компаса,
  а backend повторно проверяет prerequisite под expedition lock;
- V14 stage-ит v2 inactive; Home/event/bootstrap открывают route только после
  cluster-wide activation и полного drain старого backend pool;
- доступный выбор ведёт в optional `resonance-pocket`, после которого маршрут
  возвращается в `storm-archive`; основной выбор сохраняет прежний путь;
- mobile сохраняет `EQUIPMENT` до отправки в GAMEPLAY outbox, не применяет
  optimistic loadout и после успеха перечитывает authoritative home;
- equipment state/processed responses входят в export, cascade deletion и
  backup/restore manifest.

**Статус:** backend/mobile/Flyway V14, staged rollout gate,
unit/API/PostgreSQL concurrency/widget tests и release-policy checks
реализованы. Понятность экипировки и ценность опционального маршрута требуют
beta validation.

### US-016. Измерить путь от рецепта до скрытого маршрута

Как владелец закрытой beta, я хочу видеть cohort funnel первого уникального
предмета и связанной ветки, чтобы менять UX и баланс по наблюдаемым фактам, а
не по synthetic предположениям.

Критерии:

- Home отправляет только показы свежего network snapshot; cached/offline
  snapshot не создаёт telemetry;
- recipe и route impression имеют server-canonical IDs/enum values, server
  receive time и exact idempotent replay;
- route impression до cluster-wide активации `chapter-1-v2` отклоняется;
- telemetry использует независимую mobile lane, не инвалидирует read cache и
  не задерживает gameplay recovery;
- `COMPASS_CRAFTED`, `COMPASS_EQUIPPED`, `MIRROR_DELTA_REACHED`,
  `RESONANCE_ROUTE_CHOSEN` и `RESONANCE_ROUTE_COMPLETED` выводятся только из
  persistent gameplay tables, не из client payload;
- route baseline начинается не раньше фактической активации `chapter-1-v2` и
  исключает пользователей, resolved Mirror Delta в legacy content; V15
  immutable activation timestamp переживает same-version republish;
- admin endpoint возвращает агрегаты без user IDs, поддерживает
  `cohortCode`, один repeatable-read snapshot и явно различает
  `CLIENT_REPORTED`/`AUTHORITATIVE`;
- conversion считает достигнутую стадию, а timing — только пары, где target
  не раньше baseline; out-of-order и target-without-start видны отдельно;
- низкая instrumentation rate, client-reported показы или code-complete
  endpoint не закрывают beta gate без фактического cohort evidence.

**Статус:** backend/mobile instrumentation, cohort read model, V15 activation
metadata и unit/API/PostgreSQL/migration/widget/cache/outbox tests реализованы.
Пороговые значения и продуктовые выводы остаются внешней beta validation.

## P1 — расширение MVP

Технически реализованы:

- первая глава из 18 основных узлов и трёх опциональных маршрутов, последний
  из которых разветвляется на два самостоятельных события;
- три питомца, active selection, эволюция и навыки;
- onboarding, задания и достижения;
- development push provider boundary с local/test-only registration;
- product analytics и experiment exposure;
- cohort funnel crafting/equipment/resonance с authoritative gameplay stages;
- read-only offline cache валидированных `home` / `platform` snapshots;
- расход материалов, starter crafting recipe, persistent unique item и
  server-authoritative equipment slot.

После физической device-validation и beta остаются продуктовые расширения:

- дальнейшие механики событий и нелинейные ветки сверх resonance/storm/orchard routes;
- дополнительные recipes, rarity/upgrade mechanics и баланс material sinks;
- production APNs / FCM;
- background activity research с battery evidence;
- настройка баланса по фактическим retention/economy данным.

## P2 — soft-launch capabilities

Технически реализованы season, weekly route, squads, cosmetics, независимые
server-authoritative `PILOT`/`PET`/`PROFILE` cosmetic slots, sandbox
payment boundary с local/test-only registration, effective-capability UI gate,
risk/admin read models и базовый content/remote-config admin API.

До включения этих функций в публичный релиз остаются:

- production store billing и server-side purchase verification;
- production push;
- полноценный операторский UI для контента, anti-fraud и cohorts;
- beta-проверка отрядов, сезонной экономики и косметики;
- rollout/rollback и support-процессы.

## Icebox

- GPS-мир;
- PvP;
- открытый чат;
- маркетплейс;
- торговля питомцами;
- отдельные watch-приложения;
- 3D;
- криптовалюта.
