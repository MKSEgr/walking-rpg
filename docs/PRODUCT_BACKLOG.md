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

## P0 — first playable loop

### US-003. Получить ENERGY

Как пользователь, я хочу увидеть энергию прогулки, чтобы понимать связь движения и игры.

**Статус:** реализовано; mobile после sync перечитывает server-authoritative home.

### US-004. Продвинуть экспедицию

Как пользователь, я хочу тратить ENERGY и последовательно достигать узлов экспедиции.

**Статус:** реализовано для 18 последовательных узлов
`starter-expedition-v1` с persistent progress и idempotent debit.

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

## P1 — расширение MVP

Технически реализованы:

- первая глава из 18 последовательных узлов;
- три питомца, active selection, эволюция и навыки;
- onboarding, задания и достижения;
- development push provider boundary с local/test-only registration;
- product analytics и experiment exposure;
- read-only offline cache валидированных `home` / `platform` snapshots.

После физической device-validation и beta остаются продуктовые расширения:

- дополнительные типы событий и нелинейные ветки;
- расход материалов, crafting и unique items;
- production APNs / FCM;
- background activity research с battery evidence;
- настройка баланса по фактическим retention/economy данным.

## P2 — soft-launch capabilities

Технически реализованы season, weekly route, squads, cosmetics, sandbox
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
