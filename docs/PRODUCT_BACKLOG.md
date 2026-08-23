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
`light-canopy`, а staged `chapter-1-v5` добавляет путь с призматическим
секстантом через `spectrum-observatory`; все опциональные ветки возвращаются в
основной путь, progress и debit остаются persistent/idempotent.

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
- staged `prism-sextant-v1` требует `2 × prism-dust`, `1 × ion-bloom` и
  `1 × dawn-fragment`, появляется только вместе с `chapter-1-v5` и создаёт
  единственный `prism-sextant`;
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

**Статус:** backend/mobile/Flyway V13/V20, два server-owned recipe,
unit/API/PostgreSQL/widget tests и операционные policy checks реализованы.
Ценность рецептов и стоимость material sinks требуют beta/economy validation.

### US-015. Экипировать компас и открыть скрытый маршрут

Как пользователь, я хочу экипировать созданный уникальный предмет и получить
новый вариант прохождения, чтобы crafting влиял на игру, а не только на
коллекцию.

Критерии:

- `equipment-v1` содержит server-owned slot `NAVIGATION`, принимающий только
  принадлежащий пользователю `resonance-compass`;
- `equipment-v2` расширяет тот же single-item slot для `prism-sextant`; смена
  прибора атомарно заменяет предыдущий;
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
- `align-prism-sextant` в staged `chapter-1-v5` требует экипированный секстант,
  ведёт через `spectrum-observatory` и возвращается к `horizon-spire`;
- mobile сохраняет `EQUIPMENT` до отправки в GAMEPLAY outbox, не применяет
  optimistic loadout и после успеха перечитывает authoritative home;
- equipment state/processed responses входят в export, cascade deletion и
  backup/restore manifest.

**Статус:** backend/mobile/Flyway V14/V20, staged rollout gates,
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

### US-017. Откалибровать уникальный прибор

Как пользователь, я хочу постоянно улучшить созданный призматический секстант,
чтобы поздние материалы главы давали следующую игровую цель.

Критерии:

- `item-upgrade-v1` и стоимость принадлежат server content и доступны только с
  active `chapter-1-v5`;
- `prism-sextant-calibration-v1` расходует `2 × echo-thread`,
  `1 × prism-dust`, `1 × ion-bloom` и меняет тот же instance с
  `1/UNCOMMON` на `2/RARE`;
- все ingredient checks предшествуют debit, а item, ledger и immutable response
  сохраняются атомарно;
- exact replay не списывает материалы второй раз; новый key после завершения
  получает стабильный state conflict;
- новая mutation сериализуется с crafting/equipment/expedition, блокируется
  pending event receipt и входит в export, account deletion и backup/restore;
- Home возвращает additive `LOCKED|MISSING_MATERIALS|READY|COMPLETED`, а mobile
  хранит `ITEM_UPGRADE` в GAMEPLAY outbox и перечитывает authoritative Home без
  optimistic mutation.

**Статус:** backend/mobile/Flyway V21, unit/API/PostgreSQL/migration/widget и
outbox tests реализованы. Дополнительные уровни и баланс material sink требуют
beta/economy evidence.

### US-018. Использовать откалиброванный секстант в экспедиции

Как пользователь, я хочу открыть новый выбор улучшенным прибором, чтобы
калибровка меняла прохождение, а не оставалась только числом в инвентаре.

Критерии:

- inactive `chapter-1-v6` добавляет `trace-second-dawn` только в
  `spectrum-observatory-v1` и не меняет 23-node topology;
- choice требует `prism-sextant` в `NAVIGATION` с minimum upgrade level `2`;
- level 1, другой либо неэкипированный предмет оставляет choice `LOCKED`, а
  прямой API-вызов отклоняется до reward/progression mutation;
- успешный choice выдаёт `+46 pilot XP`, `+24 pet bond`,
  `+3 dawn-fragment` и возвращает к `horizon-spire`;
- Home/mobile принимают additive minimum-level requirement, сохраняя legacy
  default level `1`; v5 не получает новый choice;
- v6 активируется только после drain pre-V22 backend instances.

**Статус:** backend/mobile/Flyway V22, unit/API/PostgreSQL/migration/parser и
visual-mapping tests реализованы. Баланс награды требует beta evidence.

### US-019. Открыть эпилог второго рассвета

Как пользователь, я хочу применить откалиброванный секстант в финале первой
главы, чтобы улучшенный прибор открывал альтернативное завершение экспедиции.

Критерии:

- inactive `chapter-1-v7` добавляет `open-second-dawn` только в
  `dawn-relay-v1` и увеличивает catalog с 23 до 24 узлов;
- choice требует `prism-sextant` в `NAVIGATION` с minimum upgrade level `2`;
- level 1, другой либо неэкипированный предмет оставляет choice `LOCKED`, а
  прямой API-вызов отклоняется до reward/progression mutation;
- успешный choice выдаёт `+48 pilot XP`, `+26 pet bond`,
  `+1 dawn-fragment` и переводит к optional `second-dawn-threshold`;
- `anchor-second-dawn` выдаёт `+60 pilot XP`, `+22 pet bond`,
  `+2 ion-bloom`, а `leap-beyond-dawn` — `+42 pilot XP`,
  `+34 pet bond`, `+2 dawn-fragment`; оба решения завершают экспедицию;
- v1-v6 не получают новый choice, а v7 активируется только после drain
  pre-V23 backend instances.

**Статус:** backend/mobile/Flyway V23, unit/PostgreSQL/migration/catalog и
visual-mapping tests реализованы. Баланс эпилога требует beta evidence.

### US-020. Настроить секстант на второй рассвет

Как пользователь, завершивший эпилог второго рассвета, я хочу вложить
полученные материалы в дальнейшее улучшение секстанта, чтобы поздняя экономика
главы давала новую постоянную цель.

Критерии:

- inactive `chapter-1-v8` открывает
  `prism-sextant-second-dawn-attunement-v1`, а v1-v7 его не проецируют и не
  принимают;
- upgrade требует тот же `prism-sextant` уровня `2/RARE`, расходует
  `2 × echo-thread`, `2 × ion-bloom`, `2 × dawn-fragment` и переводит instance
  на `3/EPIC`;
- Home возвращает calibration и attunement в стабильном порядке с
  authoritative `LOCKED|MISSING_MATERIALS|READY|COMPLETED`;
- проверки материалов предшествуют debit, exact replay сохраняет item,
  ingredient и timestamp snapshots без повторной мутации;
- V24 сохраняет существующие item/upgrade rows и расширяет database invariants
  для rarity `EPIC`; v8 активируется только после drain pre-V24 backend
  instances.

**Статус:** backend/mobile/Flyway V24, unit/PostgreSQL/migration/parser/widget
tests реализованы. Стоимость второго улучшения требует beta/economy evidence.

### US-021. Пересечь неизведанный рубеж с EPIC-секстантом

Как пользователь, настроивший секстант на второй рассвет, я хочу применить его
в экспедиции, чтобы постоянное улучшение открывало новый маршрут и финальное
решение.

Критерии:

- inactive `chapter-1-v9` добавляет `cross-uncharted-verge` только к
  `second-dawn-threshold-v1`; v1-v8 сохраняют прежние choices и topology;
- выбор требует экипированный `prism-sextant` уровня 3, выдаёт
  `+58 pilot XP`, `+32 pet bond`, `+2 echo-thread` и переводит к optional
  `uncharted-verge`;
- `deploy-return-beacon` выдаёт `+72 pilot XP`, `+28 pet bond`,
  `+3 prism-dust`, а `follow-living-constellation` — `+50 pilot XP`,
  `+42 pet bond`, `+3 dawn-fragment`; оба завершают экспедицию;
- Home показывает v9 choice как locked с authoritative level-3 requirement
  либо available, а event service повторно проверяет его под expedition lock;
- V25 сохраняет active v8 и существующие EPIC item/upgrade rows; v9
  активируется только после drain pre-V25 backend instances.

**Статус:** backend/mobile/Flyway V25, unit/PostgreSQL/migration/catalog и
visual-mapping tests реализованы. Баланс нового рубежа требует beta evidence.

### US-022. Дать активному питомцу собственный путь на рубеже

Как пользователь, выбравший спутника, я хочу увидеть его уникальный способ
освоить неизведанный рубеж, чтобы active selection влиял на решение экспедиции,
а не только на получателя bond.

Критерии:

- inactive `chapter-1-v10` сохраняет topology v9 и добавляет в
  `uncharted-verge-v1` по одному choice для Искры, Мха и Навигатора; v1-v9
  новые IDs не проецируют и не принимают;
- Home помещает choice активного питомца в `choices`, два остальных — в
  `lockedChoices` с authoritative `type=ACTIVE_PET` и причиной блокировки;
- прямой API-вызов чужого pet choice отклоняется до progression, inventory и
  expedition mutation, а exact replay успешного выбора не дублирует награды;
- Искра получает `+48 XP / +46 bond / 3 ion-bloom`, Мох —
  `+64 XP / +34 bond / 3 ash-seed`, Навигатор —
  `+56 XP / +40 bond / 3 echo-thread`; каждый исход завершает экспедицию;
- V26 сохраняет active v9 и существующие active-pet/progression rows; v10
  активируется только после drain pre-V26 backend instances.

**Статус:** backend/mobile/Flyway V26, unit/API/PostgreSQL/migration/catalog,
parser/widget и visual-mapping tests реализованы. Баланс pet-specific наград
требует beta evidence.

### US-023. Довести starter pets до взрослой формы

Как пользователь с развитой связью, я хочу провести выбранного питомца через
вторую эволюцию, чтобы трёхступенчатый рост имел достижимую финальную форму.

Критерии:

- inactive `chapter-1-v11` сохраняет 25-node topology и разрешает
  server-authoritative переход `1 → 2`; v1-v10 сохраняют maximum stage `1`;
- Spark эволюционирует при `140` bond в «Искру-звездочёта», Moss при `125` в
  «Мох-оплот», `rune-v1` при `150` в «Навигатора созвездий»;
- user-state pet projection возвращает следующий `evolutionBond` и additive
  `maximumEvolutionStage`; старый mobile/backend безопасно используют maximum
  `1` во время rolling upgrade, а content rollback не опускает effective
  maximum ниже уже сохранённой стадии;
- обе эволюции синхронизируют level/bond с независимой `pet_progress` строкой,
  а exact replay второй команды не повторяет mutation;
- V27 сохраняет active v10 и существующие platform/progression rows; v11
  активируется только после drain pre-V27 backend instances.

**Статус:** backend/mobile/Flyway V27, unit/migration/catalog/parser/widget
tests реализованы. Баланс взрослых thresholds требует beta evidence.

### US-024. Открыть взрослым питомцам путь за Неизведанный рубеж

Как пользователь со взрослым активным питомцем, я хочу продолжить экспедицию
за обычным финалом Неизведанного рубежа, чтобы вторая эволюция открывала новое
решение и место, а не оставалась только визуальным состоянием журнала.

Критерии:

- inactive `chapter-1-v12` добавляет 26-й узел
  `constellation-sanctuary` и событие `constellation-sanctuary-v1`; v1-v11
  сохраняют прежнюю topology и не принимают новые choice IDs;
- `uncharted-verge-v1` получает по одному маршруту для Искры-звездочёта,
  Мха-оплота и Навигатора созвездий; выбор требует exact active pet и
  `evolutionStage >= 2`;
- Home проецирует additive `minimumEvolutionStage`: доступен только маршрут
  текущего взрослого питомца, остальные adult routes остаются в
  `lockedChoices`;
- event service повторно проверяет pet ID/stage до progression, inventory и
  expedition mutation; успешный choice выдаёт награду один раз и переводит в
  Святилище созвездий;
- два решения святилища выдают собственные XP/bond/material rewards и
  завершают экспедицию с exact replay;
- V28 сохраняет active v11 и существующие platform/pet/expedition rows; v12
  активируется только после drain pre-V28 backend instances.

**Статус:** backend/mobile/Flyway V28, unit/API/PostgreSQL/migration/catalog,
parser/widget и visual-mapping tests реализованы. Баланс наград и ценность
adult-only continuation требуют beta evidence.

### US-025. Применить «Чтение сигналов» в финале первой главы

Как пользователь, открывший навык «Чтение сигналов», я хочу обнаружить
скрытый исход Святилища созвездий, чтобы развитие пилота меняло доступные
решения экспедиции.

Критерии:

- inactive `chapter-1-v13` сохраняет 26-node topology v12 и добавляет в
  `constellation-sanctuary-v1` choice `decode-sanctuary-signal`; v1-v12 новый
  ID не проецируют и не принимают;
- Home помещает choice в `choices` только при наличии `signal-reader` в
  server-owned `unlockedSkills`, иначе возвращает его в `lockedChoices` с
  `type=UNLOCKED_SKILL` и понятной причиной;
- event service повторно читает authoritative platform state до XP, bond,
  material и expedition mutation; прямой вызов без навыка не меняет state;
- успешный choice выдаёт `+96 XP / +50 bond / 4 echo-thread`, завершает
  экспедицию и сохраняет exactly-once результат;
- additive mobile parser и UI показывают server-owned requirement без нового
  клиентского источника истины;
- V29 сохраняет active v12 и существующие platform/pet/expedition rows; v13
  активируется только после drain pre-V29 backend instances.

**Статус:** backend/mobile/Flyway V29, unit/API/PostgreSQL/migration/catalog,
parser/widget и visual-mapping tests реализованы. Ценность скрытого исхода и
баланс награды требуют beta evidence.

### US-026. Пройти по расшифрованному сигналу в скрытую обсерваторию

Как пользователь с открытым «Чтением сигналов», я хочу продолжить путь после
расшифровки хора, чтобы навык открывал отдельный игровой узел, а не только
другую финальную награду.

Критерии:

- inactive `chapter-1-v14` добавляет 27-й узел
  `hidden-signal-observatory`; v13 сохраняет прежнее завершение после
  `decode-sanctuary-signal`;
- в active v14 тот же skill-gated choice выдаёт `+96 XP / +50 bond /
  4 echo-thread` и переводит экспедицию в новый узел;
- событие `hidden-signal-observatory-v1` предлагает два финала: карта сектора
  за `+112 XP / +54 bond / 4 prism-dust` или ключ эха за
  `+86 XP / +76 bond / 5 echo-thread`;
- Home и Flutter отображают новый узел и оба server-owned choice без
  специальной клиентской логики, а exact replay не дублирует награды;
- rollback контента с v14 на v13 не мешает завершить уже сохранённый 27-й
  узел; rollback binary на pre-V30 после сохранения такого state запрещён;
- V30 сохраняет active v13 и существующие platform/pet/expedition rows.

**Статус:** backend/mobile/Flyway V30, unit/PostgreSQL/migration/catalog,
parser/widget и visual-mapping tests реализованы. Баланс двух финалов требует
beta evidence.

### US-027. Восстановить забытый маршрут с «Памятью маршрута»

Как пользователь с развитым пилотом, я хочу применить «Память маршрута» в
Обсерватории скрытого сигнала, чтобы ранний навык открывал отдельное
продолжение поздней экспедиции.

Критерии:

- inactive `chapter-1-v15` добавляет 28-й узел `memory-constellation`; v1-v14
  не проецируют и не принимают новый route choice;
- `hidden-signal-observatory-v1` получает skill-gated
  `reconstruct-forgotten-route`; v14 сохраняет два прежних terminal outcome;
- Home возвращает route в `choices` только при server-owned `trail-memory`,
  иначе в `lockedChoices` с `UNLOCKED_SKILL`; event service повторяет проверку
  до любых mutation;
- успешный переход выдаёт `+104 XP / +64 bond / 3 dawn-fragment`, а событие
  `memory-constellation-v1` завершает journey либо за
  `+120 XP / +58 bond / 4 ion-bloom`, либо за
  `+92 XP / +82 bond / 6 echo-thread`;
- exact replay не дублирует награды, а content rollback v15 → v14 позволяет
  завершить уже сохранённый 28-й узел;
- V31 сохраняет active v14 и существующие platform/pet/expedition rows;
  rollback binary на pre-V31 после сохранения нового node запрещён.

**Статус:** backend/mobile/Flyway V31, unit/PostgreSQL/migration/catalog,
parser/widget и visual-mapping tests реализованы. Ценность позднего применения
раннего навыка и баланс финалов требуют beta evidence.

### US-028. Стабилизировать Меридиан рассвета с «Дисциплиной энергии»

Как пользователь с открытой «Дисциплиной энергии», я хочу выровнять поток в
Созвездии памяти, чтобы навык управления ресурсом открывал отдельное
продолжение поздней экспедиции.

Критерии:

- inactive `chapter-1-v16` добавляет 29-й узел `dawn-meridian`; v1-v15 не
  проецируют и не принимают новый route choice;
- `memory-constellation-v1` получает skill-gated
  `stabilize-dawn-current`; v15 сохраняет два прежних terminal outcome;
- Home возвращает route в `choices` только при server-owned
  `energy-discipline`, иначе в `lockedChoices` с `UNLOCKED_SKILL`; event
  service повторяет проверку до любых mutation;
- успешный переход выдаёт `+112 XP / +70 bond / 3 ion-bloom`, а событие
  `dawn-meridian-v1` завершает journey либо за
  `+132 XP / +64 bond / 5 dawn-fragment`, либо за
  `+100 XP / +90 bond / 7 echo-thread`;
- exact replay не дублирует награды, а content rollback v16 → v15 позволяет
  завершить уже сохранённый 29-й узел;
- V32 сохраняет active v15 и существующие platform/pet/expedition rows;
  rollback binary на pre-V32 после сохранения нового node запрещён.

**Статус:** backend/mobile/Flyway V32, unit/PostgreSQL/migration/catalog,
parser/widget и visual-mapping tests реализованы. Ценность позднего применения
навыка и баланс финалов требуют beta evidence.

### US-029. Перейти по первому свету с «Ровным шагом»

Как пользователь с открытым «Ровным шагом», я хочу удержать ритм Меридиана
рассвета, чтобы первый навык пилота открывал отдельное продолжение поздней
экспедиции.

Критерии:

- inactive `chapter-1-v17` добавляет 30-й узел `first-light-causeway`; v1-v16
  не проецируют и не принимают новый route choice;
- `dawn-meridian-v1` получает skill-gated `cross-first-light-causeway`; v16
  сохраняет два прежних terminal outcome;
- Home возвращает route в `choices` только при server-owned `steady-step`,
  иначе в `lockedChoices` с `UNLOCKED_SKILL`; event service повторяет проверку
  до любых mutation;
- успешный переход выдаёт `+118 XP / +76 bond / 4 prism-dust`, а событие
  `first-light-causeway-v1` завершает journey либо за
  `+144 XP / +72 bond / 6 ion-bloom`, либо за
  `+110 XP / +100 bond / 8 echo-thread`;
- exact replay не дублирует награды, а content rollback v17 → v16 позволяет
  завершить уже сохранённый 30-й узел;
- V33 сохраняет active v16 и существующие platform/pet/expedition rows;
  rollback binary на pre-V33 после сохранения нового node запрещён.

**Статус:** backend/mobile/Flyway V33, unit/PostgreSQL/migration/catalog,
parser/widget и visual-mapping tests реализованы. Ценность позднего применения
первого навыка и баланс финалов требуют beta evidence.

### US-030. Начать новый поход после завершения главы

Как игрок, завершивший экспедицию, я хочу снова выйти на маршрут,
чтобы повторять игровой цикл и продолжать постоянную прогрессию.

Критерии:

- новый поход доступен только из `COMPLETED` и после ACK финального
  event result;
- route state возвращается на первый узел active content, а первое
  продвижение снова требует ENERGY;
- XP пилота, питомец/эволюция, skills, inventory, unique items и
  equipment сохраняются;
- persistent `journeyNumber` увеличивается ровно один раз; exact replay и
  stale multi-device command имеют разные безопасные исходы;
- Home и Flutter показывают номер похода; cached state и pending
  result не разрешают mutation;
- event uniqueness ограничена текущим походом, поэтому тот же event
  может выдать награду в следующем цикле, но не дважды в одном.

**Статус:** backend/mobile/Flyway V34, unit/API/PostgreSQL/migration,
parser/outbox/widget, account export/delete и synthetic backup coverage реализованы.

### US-031. Видеть пройденный маршрут текущего похода

Как игрок, я хочу видеть уже открытый след текущего похода, чтобы понимать,
через какие узлы прошла моя экспедиция и где она находится сейчас.

Критерии:

- Home возвращает упорядоченный `routeTrail` только для текущего
  `journeyNumber`;
- обработанные event nodes имеют literal state `VISITED`, а последняя точка —
  `CURRENT` или `COMPLETED`;
- backend строит read model из durable event results и текущего expedition
  state, не публикуя будущие узлы и развилки;
- новый поход начинает новый след с первого текущего узла, не смешивая историю
  предыдущего прохождения;
- Flutter сохраняет порядок и state ответа, показывает code-native маршрут и
  не выводит topology из content version, ID или отображаемых названий;
- legacy snapshots без `routeTrail` остаются читаемыми.

**Статус:** backend/mobile read model, unit/API/PostgreSQL, parser/widget и
RU/EN accessibility coverage реализованы. GPS и real-time walking map не
входят в этот slice.

### US-032. Вспомнить решения текущего похода

Как игрок, я хочу видеть в путевом журнале уже принятые решения текущего
похода и их последствия, чтобы понимать историю своего маршрута.

Критерии:

- Home возвращает упорядоченный `decisionLog` только для текущего
  `journeyNumber`;
- каждая запись содержит stable event/choice identity, сохранённые заголовки
  события, выбора и исхода, описание результата и `resolvedAt`;
- backend читает copy из durable event resolution, поэтому content
  republish/rollback не меняет уже принятую запись;
- новый поход начинает пустой журнал и не смешивает решения предыдущего
  прохождения;
- Flutter сохраняет порядок ответа, показывает code-native записи и доступный
  empty state без client-side topology inference;
- legacy snapshots без `decisionLog` остаются читаемыми.

**Статус:** additive Home projection, current-journey PostgreSQL scope,
mobile parser и путевой журнал с unit/API/parser/widget coverage реализованы.

### US-033. Видеть награды за решения текущего похода

Как игрок, я хочу видеть фактически полученные награды рядом с каждым решением,
чтобы понимать, как история похода изменила пилота, питомца и инвентарь.

Критерии:

- Home дополняет каждую запись `decisionLog` сохранёнными XP пилота, stable
  identity/name питомца, полученной связью и nullable material reward;
- backend читает значения из той же immutable event resolution текущего
  `journeyNumber`, а не вычисляет разницу между текущими totals;
- material reward содержит persisted item identity/name и quantity gained;
- Flutter показывает literal reward chips и включает тот же список в одну
  accessibility summary записи без client-side расчётов;
- legacy snapshots без reward fields остаются читаемыми и не показывают
  выдуманные нулевые награды;
- unit/API/PostgreSQL/parser/widget coverage проверяет persisted copy,
  nullable material и новый поход через существующий current-journey scope.

**Статус:** additive backend/mobile projection и доступное отображение наград
с regression coverage реализованы без новой миграции.

### US-034. Увидеть итог завершённого похода

Как игрок, я хочу после финиша увидеть суммарный результат текущего похода,
чтобы быстро понять, что маршрут дал пилоту, спутникам и инвентарю.

Критерии:

- Home возвращает nullable `completionRecap` только при `COMPLETED` и только
  для текущего `journeyNumber`;
- backend суммирует XP пилота и связь по immutable event resolutions, а
  materials группирует по persisted `itemId + itemName` в порядке первого
  появления без current-content lookup;
- новый или незавершённый поход не получает recap, а legacy completed snapshot
  без поля остаётся читаемым;
- Flutter показывает отдельную code-native карточку перед журналом решений и
  озвучивает решение/награды одной accessibility summary без client totals;
- unit/API/PostgreSQL/parser/widget coverage проверяет completed, in-progress,
  legacy, invalid и aggregated material cases.

**Статус:** additive Home recap и доступная mobile-карточка реализованы без
изменения экономики и без новой миграции.

### US-035. Вспомнить итоги недавних походов

Как игрок, я хочу видеть несколько последних завершённых походов после старта
нового, чтобы сравнить решения и полученные награды без потери текущего
маршрута.

Критерии:

- Home возвращает не более пяти `recentJourneyRecaps` от нового к старому и
  никогда не включает текущий `journeyNumber`;
- завершение прошлого похода подтверждается immutable receipt старта
  следующего похода, а не историческим `expedition_status` event resolution;
- decision count, XP, связь и materials агрегируются из persisted resolutions
  каждого подтверждённого похода без current-content lookup;
- mobile валидирует прошлые положительные номера и строгий убывающий порядок,
  а legacy snapshot без поля получает пустой архив;
- журнал показывает доступную code-native карточку после решений текущего
  похода; unit/PostgreSQL/parser/widget coverage проверяет limit, порядок,
  ложный current `COMPLETED`, награды и legacy fallback.

**Статус:** архив пяти последних походов реализован поверх существующих
immutable receipts без миграции и без изменения экономики.

### US-036. Понять вклад питомцев в завершённый поход

Как игрок, я хочу видеть полученную связь отдельно по каждому участвовавшему
питомцу, чтобы понимать постоянную прогрессию спутников после смены активного
питомца между решениями.

Критерии:

- `completionRecap` и каждый `recentJourneyRecaps[]` содержат ordered
  `petBondRewards[]` из persisted `petId + petName + petBondGained`;
- backend группирует только положительную связь по identity в порядке первого
  появления, а сумма breakdown точно равна совместимому `petBondGained`;
- текущий content, активный питомец и current bond totals не участвуют в
  восстановлении истории;
- mobile валидирует положительные значения, уникальность identity и сумму,
  но legacy recap без массива продолжает показывать общий итог;
- карточки итогов показывают named bond chips и озвучивают тот же ordered
  список; unit/API/PostgreSQL/parser/widget coverage проверяет оба режима.

**Статус:** additive backend/mobile breakdown реализован без миграции и без
изменения экономики.

### US-037. Вспомнить финал завершённого похода

Как игрок, я хочу видеть последнее решение и исход в итогах похода, чтобы
архив сохранял историю маршрута, а не только числовые награды.

Критерии:

- `completionRecap` и каждый `recentJourneyRecaps[]` получают nullable
  `finalDecision` с persisted event/choice/outcome copy и `resolvedAt`;
- backend выбирает последнюю immutable resolution по repository-owned порядку
  `expedition_version, receipt_id`, не используя current content или node ID;
- content republish/rollback не переписывает сохранённый финал, а пустая или
  legacy history безопасно даёт `null`;
- mobile валидирует обязательные строки и ISO timestamp, показывает компактный
  finale block перед наградами и включает тот же текст в recap semantics;
- unit/API/PostgreSQL/parser/widget coverage проверяет current, recent, legacy,
  invalid timestamp и точную persisted copy.

**Статус:** additive финал текущего и недавних походов реализован поверх
существующей immutable history без миграции и без изменения экономики.

### US-038. Увидеть решения прямо на следе текущего похода

Как игрок, я хочу видеть сохранённый выбор и исход у каждой пройденной точки,
чтобы считывать историю маршрута на карте без перехода к полному журналу.

Критерии:

- resolved points в `routeTrail[]` получают nullable `decision` со stable
  `choiceId` и persisted `choiceTitle + outcomeTitle`;
- backend сопоставляет узел и решение из одного repository-ordered списка
  immutable resolutions exact текущего `journeyNumber`;
- unresolved `CURRENT` не получает выдуманной annotation, а completed terminal
  сохраняет фактическое решение при смене literal state;
- mobile не соединяет route trail с `decisionLog`, показывает компактный
  `choice → outcome` и озвучивает тот же ordered текст в RU/EN;
- legacy route nodes без поля остаются валидными; unit/API/PostgreSQL/parser,
  widget и Home integration coverage проверяет persisted copy и long text.

**Статус:** additive backend/mobile annotation реализована без миграции,
изменения topology или экономики.

### US-039. Раскрыть полную историю недавнего похода

Как игрок, я хочу раскрыть завершённый поход в архиве и увидеть все его
сохранённые решения, чтобы вспомнить путь целиком, а не только финал и награды.

Критерии:

- `completionRecap` и каждый `recentJourneyRecaps[]` получают additive ordered
  `decisions[]` из immutable resolutions exact `journeyNumber`;
- каждая запись содержит persisted event/choice/outcome copy, `resolvedAt` и
  фактически выданные XP, pet bond identity и nullable material reward;
- backend не читает current content, не восстанавливает topology и не выводит
  историю из агрегированных totals;
- mobile принимает legacy recap без массива, а при наличии проверяет длину
  относительно `decisionCount` и совпадение последней записи с
  `finalDecision`;
- архив по умолчанию остаётся компактным и раскрывает numbered decision entries
  отдельной accessible кнопкой; текущий recap не дублирует уже видимый журнал;
- unit/API/PostgreSQL/parser/widget coverage проверяет порядок, literal copy,
  rewards, invalid shape, large text и legacy fallback.

**Статус:** полный persisted журнал недавних походов реализован поверх
существующей immutable history без миграции, изменения topology или экономики.

### US-040. Видеть летопись всех завершённых походов

Как игрок, я хочу видеть постоянный итог всех завершённых походов, чтобы
ощущать накопленную историю даже после выхода старых маршрутов из недавнего
архива.

Критерии:

- Home возвращает additive nullable `journeyChronicle` с lifetime totals
  завершённых походов, решений, pilot XP и companion bond;
- прошлый поход считается завершённым только по immutable receipt старта
  следующего `journeyNumber`, а authoritative current `COMPLETED` добавляется
  ровно один раз до старта следующего похода;
- агрегат охватывает всю доказанную историю независимо от archive limit 5 и
  читает rewards только из persisted resolutions без current-content lookup,
  progression delta или inventory balance;
- mobile принимает legacy omission, отклоняет нулевой completed count и
  отрицательные totals, показывает wrapping code-native card между decision
  log и archive и озвучивает один полный semantic summary;
- unit/API/PostgreSQL/parser/widget coverage проверяет current + previous
  totals, отсутствие double count, историю длиннее архива, invalid shape,
  compact large text и legacy fallback.

**Статус:** lifetime-летопись реализована без миграции, изменения topology,
экономики или archive pagination.

### US-041. Закрепить Навигатора как третьего спутника

Как игрок, я хочу видеть одного и того же канонического Навигатора во всех
текущих игровых поверхностях, чтобы имя спутника не расходилось с его
утверждённым образом и не смешивалось с ролью пилота.

Критерии:

- stable companion ID `rune-v1`, pilot ID `navigator-v1`, внутренние enum,
  asset paths и исторические receipts/migrations не переименовываются;
- текущий catalog и progression используют формы «Навигатор», «Навигатор
  потоков», «Навигатор созвездий» и trait «Точный проводник»;
- pet-gated choices и требования используют те же формы без legacy «Руна»;
- обязательный first-journey mapping разрешает `rune-v1` как
  «Навигатор» / `Navigator` с актуальным trait в RU/EN;
- paired crew copy называет `navigator-v1` ролью «Пилот», сохраняя имя
  «Навигатор» в portrait/dossier контексте;
- backend, Flutter и accessibility tests фиксируют current copy и stable-ID
  compatibility.

**Статус:** canonical copy реализована без schema migration, изменения
gameplay identity, экономики, topology или external validation status.

### US-042. Продолжить выбранный язык в основной экспедиции

Как игрок, выбравший русский или английский язык до входа, я хочу сохранить
его после первого пути, чтобы основной игровой цикл не возвращался внезапно к
другому языку.

Критерии:

- compact и wide navigation используют generated RU/EN labels;
- весь client-authored Home chrome — loading/error/offline states, primary
  action, feedback, route/activity/team/event/equipment/inventory/crafting и
  upgrade copy — приходит из ARB;
- числа, server values и diagnostics передаются typed placeholders, а locale
  не определяется по display text;
- companion growth/motion и saved-action entry имеют RU/EN semantics при
  compact viewport и text scale 1.6;
- current expedition/node/pilot/pet/item/equipment/recipe/upgrade identities
  локализуются только по stable ID; additive `pilotId` допускает legacy
  omission, а unknown content сохраняет server literal;
- все 30 известных READY event title/summary, 78 exact event/choice pairs и 16
  gated requirements локализуются только по stable ID; unlock feedback
  использует ту же границу, а unknown content сохраняет server literal;
- resolved event copy, immutable decisions, outcomes, pending results, receipts
  и recaps не переписываются при смене locale;
- полный Platform journal, progression/catalog actions и accessibility-сигналы
  weekly route, quest progress и companion bond используют generated RU/EN;
- current onboarding/skill/quest/achievement/cosmetic/season/experiment copy
  разрешается только по stable ID, известные command results — по command type,
  а unknown content и immutable journey history сохраняют literal fallback;
- account, locale-specific destructive confirmation, recovery, validation,
  activity и остальные boundary-экраны используют generated RU/EN copy;
- stable failure/status categories дают безопасный локализованный feedback,
  raw exception/backend diagnostics не выводятся игроку, а literal receipts,
  filenames, timestamps, wire values и server-owned IDs не переписываются.

**Статус:** expedition shell, current identity catalog и current event
narrative, полный Platform journal и оставшиеся client-authored boundary-
экраны реализованы. Milestone 26 `CODE_COMPLETE`; external validation gates и
immutable `alpha-rc1` не изменены.

### US-043. Увидеть вклад спутников во всей летописи

Как игрок, я хочу видеть вклад каждого спутника в накопленную связь всех
завершённых походов, чтобы lifetime-итог сохранял не только сумму, но и историю
моей команды.

Критерии:

- `journeyChronicle` получает additive ordered `petBondRewards[]` из
  положительных persisted reward facts всех receipt-proven завершённых
  походов;
- связь группируется по persisted `petId + petName` в порядке первого
  immutable появления, а её сумма точно равна совместимому `petBondGained`;
- authoritative current `COMPLETED` объединяется ровно один раз до старта
  следующего похода; archive limit, current pet/content и progression totals
  не используются для вывода истории;
- mobile принимает legacy omission, отклоняет не-массив, неположительную
  связь, повтор identity и несовпадающую сумму;
- летопись показывает ordered именные chips и один полный RU/EN semantic
  summary, сохраняя общий неназванный fallback для legacy snapshot;
- backend unit/API/PostgreSQL и Flutter parser/widget coverage проверяют
  persisted copy, порядок, current merge, invalid data и compact large text.

**Статус:** lifetime-разбивка связи реализована без миграции, изменения
экономики, topology, archive pagination или external validation status.

### US-044. Увидеть материалы всей летописи

Как игрок, я хочу видеть суммарные материалы всех завершённых походов, чтобы
lifetime-летопись сохраняла фактическую историю наград независимо от текущего
инвентаря.

Критерии:

- `journeyChronicle` получает additive ordered `materials[]` из положительных
  persisted reward facts всех receipt-proven завершённых походов;
- quantity группируется по persisted `itemId + itemName` в порядке первого
  immutable появления, без current catalog или inventory balance;
- authoritative current `COMPLETED` объединяется ровно один раз до старта
  следующего похода; recent archive limit не ограничивает lifetime history;
- mobile принимает legacy omission и отклоняет не-массив, неположительное
  quantity и повтор persisted identity;
- летопись показывает ordered RU/EN material chips и включает их в один полный
  semantic summary;
- backend unit/API/PostgreSQL и Flutter parser/widget coverage проверяют
  persisted copy, порядок, current merge, invalid data и compact large text.

**Статус:** lifetime-разбивка материалов реализована без миграции, изменения
экономики, inventory projection, topology или external validation status.

### US-045. Увидеть финалы всей летописи

Как игрок, я хочу видеть, сколько раз был достигнут каждый сохранённый финал,
чтобы lifetime-летопись отражала историю моих маршрутов за пределами окна
недавних походов.

Критерии:

- `journeyChronicle` получает additive ordered `finaleOutcomes[]` из последней
  immutable event resolution каждого receipt-proven завершённого похода;
- финалы группируются по persisted `eventId + eventTitle + choiceId +
  choiceTitle + outcomeTitle` в порядке первого immutable появления, без
  current content lookup;
- authoritative current `COMPLETED` объединяется ровно один раз до старта
  следующего похода, а неподтверждённый текущий history row не попадает в
  lifetime breakdown;
- при наличии массива положительные `journeyCount` уникальны по persisted
  identity и в сумме точно равны `completedJourneyCount`; legacy omission
  остаётся валидным;
- летопись показывает отдельные ordered RU/EN finale chips и включает полный
  список в одну semantic summary без усечения;
- backend unit/API/PostgreSQL и Flutter parser/widget coverage проверяют
  persisted copy, порядок, current merge, invalid data и compact text 1.6.

**Статус:** lifetime-разбивка финалов реализована без миграции, изменения
контента, topology, экономики или external validation status.

### US-046. Увидеть решения всей летописи

Как игрок, я хочу видеть, сколько раз принималось каждое сохранённое решение,
чтобы lifetime-летопись отражала не только финалы, но и весь пройденный путь за
пределами окна недавних походов.

Критерии:

- `journeyChronicle` получает additive ordered `decisionOutcomes[]` из всех
  immutable event resolutions receipt-proven завершённых походов;
- решения группируются по persisted `eventId + eventTitle + choiceId +
  choiceTitle + outcomeTitle` в порядке первого immutable появления, без
  current content lookup;
- authoritative current `COMPLETED` объединяет все свои решения ровно один раз
  до старта следующего похода, а неподтверждённый current history row не
  попадает в lifetime breakdown;
- при наличии массива положительные `decisionCount` уникальны по persisted
  identity и в сумме точно равны lifetime `decisionCount`; legacy omission
  остаётся валидным;
- летопись показывает отдельные ordered RU/EN decision chips и включает полный
  список в одну semantic summary без усечения;
- backend unit/API/PostgreSQL и Flutter parser/widget coverage проверяют
  persisted copy, порядок, current merge, invalid data и compact text 1.6.

**Статус:** lifetime-разбивка решений реализована без миграции, изменения
контента, topology, экономики или external validation status.

### US-047. Увидеть опыт пилотов всей летописи

Как игрок, я хочу видеть вклад каждого сохранённого пилота в накопленный опыт
всех завершённых походов, чтобы lifetime-итог объяснял XP независимо от
текущего progression и переименований контента.

Критерии:

- `journeyChronicle` получает additive ordered `pilotExperienceRewards[]` из
  положительных persisted reward facts всех receipt-proven завершённых
  походов;
- XP группируется по persisted `pilotId + pilotName` в порядке первого
  immutable появления, а его сумма точно равна совместимому
  `pilotExperienceGained`;
- authoritative current `COMPLETED` объединяется ровно один раз до старта
  следующего похода; recent archive, current pilot/content и progression total
  не используются для вывода истории;
- mobile принимает legacy omission, отклоняет не-массив, неположительный XP,
  повтор persisted identity и несовпадающую сумму;
- летопись показывает ordered именные RU/EN XP chips и включает их в один
  полный semantic summary, сохраняя общий fallback для legacy snapshot;
- backend unit/API/PostgreSQL и Flutter parser/widget coverage проверяют
  persisted copy, порядок, current merge, invalid data и compact text 1.6.

**Статус:** lifetime-разбивка XP пилотов реализована без миграции, изменения
XP economy, progression, topology или external validation status.

### US-048. Увидеть вклад пилотов в итогах каждого похода

Как игрок, я хочу видеть вклад каждого сохранённого пилота в XP конкретного
завершённого похода, чтобы текущий итог и недавний архив объясняли награду тем
же persisted copy, что и lifetime-летопись.

Критерии:

- `completionRecap` и каждый элемент `recentJourneyRecaps[]` получают
  additive ordered `pilotExperienceRewards[]` из положительных immutable
  reward facts exact `journeyNumber`;
- XP группируется по persisted `pilotId + pilotName` в порядке первого
  появления, а сумма точно равна совместимому `pilotExperienceGained`;
- при неполной historical pilot identity backend опускает весь additive
  массив, не публикуя частичную историю;
- mobile принимает legacy omission, отклоняет non-list, неположительный XP,
  повтор identity и несовпадающую сумму;
- current и archived recap показывают ordered именные RU/EN chips и включают
  их в одну полную semantic summary, сохраняя generic XP fallback для legacy;
- backend unit/API/PostgreSQL и Flutter parser/widget coverage проверяют
  persisted copy, порядок, omission, invalid data и compact text scale 1.6.

**Статус:** per-journey разбивка XP пилотов реализована без миграции, изменения
XP economy, progression, topology или external validation status.

### US-049. Увидеть время завершения похода

Как игрок, я хочу видеть, когда был завершён текущий или недавний поход, чтобы
связывать сохранённый итог с конкретной прогулкой и не путать маршруты в
архиве.

Критерии:

- current `completionRecap` и каждый recent archive entry используют только
  immutable `finalDecision.resolvedAt` как persisted completion moment;
- client clock, cache time, current content и время HTTP-response не участвуют
  в выводе результата;
- UTC instant переводится в локальную timezone только для presentation, а
  дата и время форматируются по выбранной RU/EN locale;
- видимый completion label и accessibility summary используют один и тот же
  текст без скрытого или повторно вычисленного значения;
- legacy recap без `finalDecision` остаётся валидным и не показывает
  выдуманный timestamp;
- RU/EN widget и compact text-scale 1.6 coverage проверяют current, archived и
  legacy presentation.

**Статус:** locale-aware completion time реализован поверх persisted final
resolution без backend/API/schema migration и без изменения исторических
данных.

### US-050. Увидеть время сохранённого решения

Как игрок, я хочу видеть, когда было принято каждое сохранённое решение,
чтобы сопоставлять последовательность событий текущего и недавнего похода с
прогулкой.

Критерии:

- каждая запись current `decisionLog` и раскрытого `decisions[]` недавнего
  похода использует только immutable `decision.resolvedAt`;
- UTC instant переводится в локальную timezone только для presentation, а
  дата и время форматируются по выбранной RU/EN locale;
- видимый label и accessibility summary используют один и тот же текст;
- client clock, cache/Home-response time, current content и вычисленная
  длительность не участвуют в выводе;
- RU/EN widget и compact text-scale 1.6 coverage проверяют текущие и архивные
  записи без layout overflow.

**Статус:** locale-aware decision time реализован поверх persisted resolution
без backend/API/schema migration и без изменения исторических данных.

### US-051. Увидеть длительность завершённого похода

Как игрок, я хочу видеть, сколько длился текущий или недавний
завершённый поход, чтобы сопоставлять результат с прогулкой без
зависимости от часов устройства.

Критерии:

- current `completionRecap` и каждый `recentJourneyRecaps[]` получают
  additive nullable non-negative `durationSeconds`;
- backend считает целые секунды только между persisted start
  exact journey и immutable `finalDecision.resolvedAt`;
- journey 1 использует initial cycle/progress creation, journey 2+ —
  immutable journey-start receipt `server_time`;
- missing start/final или start позже final приводят к omission, а mobile
  отклоняет malformed/negative value и duration без final decision;
- RU/EN current/archive UI и accessibility используют один формат,
  а legacy omission ничего не выдумывает;
- backend unit/API/PostgreSQL и Flutter parser/widget/localization coverage
  проверяют authoritative sources, invalid data и compact text scale 1.6.

**Статус:** authoritative journey duration реализована без migration и
без изменения rewards/economy, progression, topology, archive limit или
external validation status.

### US-052. Увидеть общее время завершённых походов

Как игрок, я хочу видеть суммарную длительность всех завершённых походов,
чтобы lifetime-летопись отражала время полного пройденного пути, а не только
пять недавних итогов.

Критерии:

- `journeyChronicle` получает additive nullable non-negative
  `totalDurationSeconds` по всем receipt-proven завершённым походам;
- journey 1 использует initial cycle/progress creation, journey 2+ — exact
  journey-start receipt `server_time`, а final берётся из последней immutable
  resolution exact journey;
- authoritative current `COMPLETED` добавляется ровно один раз, а после старта
  следующего похода тот же duration приходит только из historical SQL;
- missing start/final или start позже final любого included journey опускают
  всё поле без partial total; recent archive, client clock и response/cache
  time не используются;
- mobile принимает legacy omission, fail-closed отклоняет malformed/negative
  value и показывает один RU/EN chip в полной accessibility summary;
- backend unit/API/PostgreSQL и Flutter parser/widget/localization coverage
  проверяют full history, current merge, invalid data и compact text scale 1.6.

**Статус:** authoritative lifetime journey duration реализована без migration
и без изменения rewards/economy, progression, topology, archive limit или
external validation status.

### US-053. Увидеть рекорд длительности завершённого похода

Как игрок, я хочу видеть длительность самого долгого завершённого похода,
чтобы lifetime-летопись показывала личный рекорд по всей истории, а не только
по пяти недавним итогам.

Критерии:

- `journeyChronicle` получает additive nullable non-negative
  `longestDurationSeconds` по всем receipt-proven завершённым походам;
- historical maximum использует те же exact start/final boundaries, что и
  lifetime total, а authoritative current `COMPLETED` сравнивается ровно один
  раз;
- после старта следующего похода тот же duration приходит только из history;
- missing start/final или start позже final любого included journey опускают
  всё поле без recent/partial maximum;
- longest публикуется только вместе с `totalDurationSeconds`, не превышает его,
  а mobile fail-closed отклоняет malformed/negative/inconsistent value;
- RU/EN chip и accessibility используют один duration formatter, а backend
  unit/API/PostgreSQL и Flutter parser/widget/localization coverage проверяют
  full history, current merge и compact text scale 1.6.

**Статус:** authoritative longest journey duration реализована без migration
и без изменения rewards/economy, progression, topology, archive limit или
external validation status.

### US-054. Увидеть среднюю длительность завершённого похода

Как игрок, я хочу видеть среднюю длительность завершённого похода, чтобы
понимать обычный масштаб прогулки по всей подтверждённой истории, а не только
суммарное время или рекорд.

Критерии:

- `journeyChronicle` получает additive nullable non-negative
  `averageDurationSeconds`;
- backend вычисляет значение после authoritative current `COMPLETED` merge как
  floor `totalDurationSeconds / completedJourneyCount`, поэтому один и тот же
  поход учитывается ровно один раз;
- полная receipt-proven history и exact boundaries наследуются от lifetime
  total без recent archive, client clock или current-content inference;
- omission total приводит к omission average, а mobile fail-closed отклоняет
  malformed/negative value, average без total и несовпадающий floor-result;
- RU/EN chip и accessibility используют один duration formatter, а backend
  unit/API/PostgreSQL и Flutter parser/widget/localization coverage проверяют
  full history, current merge, rounding и compact text scale 1.6.

**Статус:** authoritative average journey duration реализована без migration
и без изменения rewards/economy, progression, topology, archive limit или
external validation status.

### US-055. Узнать номер самого долгого завершённого похода

Как игрок, я хочу видеть номер похода, установившего рекорд длительности, чтобы
личный рекорд в lifetime-летописи был связан с конкретным маршрутом, а не
оставался безымянной величиной.

Критерии:

- `journeyChronicle` получает additive nullable positive
  `longestJourneyNumber` только вместе с `longestDurationSeconds`;
- backend выбирает winner по duration DESC, journey number ASC на полной
  receipt-proven history с теми же exact boundaries;
- authoritative current `COMPLETED` учитывается ровно один раз и заменяет
  historical identity только при строго большей duration;
- incomplete/reversed boundary опускает identity вместе с lifetime duration,
  без recent archive или client-side inference;
- mobile принимает legacy omission, fail-closed отклоняет malformed,
  non-positive, out-of-range identity или number без longest duration;
- RU/EN chip и accessibility называют journey, используют общий duration
  formatter, а backend unit/API/PostgreSQL и Flutter parser/widget/localization
  coverage проверяют tie-break, current merge и compact text scale 1.6.

**Статус:** authoritative longest journey identity реализована без migration
и без изменения rewards/economy, progression, topology, archive limit или
external validation status.

### US-056. Узнать, когда был установлен рекорд похода

Как игрок, я хочу видеть момент завершения самого долгого похода, чтобы
понимать, когда был установлен личный рекорд, без поиска по пяти недавним
итогам.

Критерии:

- `journeyChronicle` получает additive nullable ISO-8601 instant
  `longestJourneyCompletedAt` только вместе с record duration и identity;
- backend выбирает timestamp из immutable final resolution winner по duration
  DESC, journey number ASC на полной receipt-proven history;
- authoritative current `COMPLETED` учитывается ровно один раз и заменяет
  historical timestamp только при строго большей duration, а tie сохраняет
  прежний record;
- incomplete/reversed boundary опускает timestamp вместе с lifetime duration
  и identity без recent archive или client-side inference;
- mobile принимает legacy omission, fail-closed отклоняет malformed,
  timezone-less или unpaired instant;
- RU/EN chip и accessibility переводят UTC instant в timezone устройства
  только для presentation, а backend unit/API/PostgreSQL и Flutter
  parser/widget/localization coverage проверяют tie-break, current merge и
  compact text scale 1.6.

**Статус:** authoritative longest journey completion time реализовано без
migration и без изменения rewards/economy, progression, topology, archive
limit или external validation status.

### US-057. Увидеть самый короткий завершённый поход

Как игрок, я хочу видеть длительность самого короткого завершённого похода,
чтобы lifetime-летопись показывала нижнюю границу моего опыта по всей
подтверждённой истории, а не только по пяти недавним итогам.

Критерии:

- `journeyChronicle` получает additive nullable non-negative
  `shortestDurationSeconds` по всем receipt-proven завершённым походам;
- historical minimum использует те же exact start/final boundaries, что
  lifetime total, а authoritative current `COMPLETED` сравнивается ровно один
  раз;
- missing или reversed boundary любого included journey опускает shortest
  вместе с остальными lifetime duration fields без recent/partial fallback;
- shortest публикуется только вместе с total и не превышает average/longest,
  когда они присутствуют; mobile fail-closed отклоняет malformed, negative и
  inconsistent value;
- RU/EN chip и accessibility используют общий duration formatter, а backend
  unit/API/PostgreSQL и Flutter parser/widget/localization coverage проверяют
  full history, current merge и compact text scale 1.6.

**Статус:** authoritative shortest journey duration реализована без migration
и без изменения rewards/economy, progression, topology, archive limit или
external validation status.

### US-058. Узнать номер самого короткого завершённого похода

Как игрок, я хочу видеть номер похода с минимальной длительностью, чтобы
нижняя граница lifetime-летописи была связана с конкретным маршрутом, а не
оставалась безымянной величиной.

Критерии:

- `journeyChronicle` получает additive nullable positive
  `shortestJourneyNumber` только вместе с `shortestDurationSeconds`;
- backend выбирает winner по duration ASC, journey number ASC на полной
  receipt-proven history с теми же exact boundaries;
- authoritative current `COMPLETED` учитывается ровно один раз и заменяет
  historical identity только при строго меньшей duration; tie сохраняет более
  ранний historical journey;
- incomplete/reversed boundary опускает identity вместе с lifetime duration
  без recent archive или client-side inference;
- mobile принимает legacy omission, fail-closed отклоняет malformed,
  non-positive, out-of-range identity или number без shortest duration;
- RU/EN chip и accessibility называют journey, используют общий duration
  formatter, а backend unit/API/PostgreSQL и Flutter parser/widget/localization
  coverage проверяют tie-break, current merge и compact text scale 1.6.

**Статус:** authoritative shortest journey identity реализована без migration
и без изменения rewards/economy, progression, topology, archive limit или
external validation status.

### US-059. Узнать, когда завершён самый короткий поход

Как игрок, я хочу видеть момент завершения самого короткого похода, чтобы
понимать, когда была установлена нижняя граница моей lifetime-летописи, без
поиска по пяти недавним итогам.

Критерии:

- `journeyChronicle` получает additive nullable ISO-8601 instant
  `shortestJourneyCompletedAt` только вместе с shortest duration и identity;
- backend выбирает timestamp из immutable final resolution winner по duration
  ASC, journey number ASC на полной receipt-proven history;
- authoritative current `COMPLETED` учитывается ровно один раз и заменяет
  historical timestamp только при строго меньшей duration, а tie сохраняет
  прежний winner;
- incomplete/reversed boundary опускает timestamp вместе с lifetime duration
  и identity без recent archive или client-side inference;
- mobile принимает legacy omission, fail-closed отклоняет malformed,
  timezone-less или unpaired instant;
- RU/EN chip и accessibility переводят UTC instant в timezone устройства
  только для presentation, а backend unit/API/PostgreSQL и Flutter
  parser/widget/localization coverage проверяют tie-break, current merge и
  compact text scale 1.6.

**Статус:** authoritative shortest journey completion time реализовано без
migration и без изменения rewards/economy, progression, topology, archive
limit или external validation status.

### US-060. Видеть мягкий недельный ритм активности

Как игрок, я хочу видеть несколько активных дней из семи, чтобы поддерживать
регулярность без наказания за отдых и без разрушительного streak reset.

Критерии:

- Home получает additive `weeklyActivityRhythm` с фактическим active-day count,
  окном 7 дней, целью 4 дня и derived `targetReached`;
- backend считает target local date и шесть предыдущих дат только по persisted
  `activity_sync_state.accepted_total > 0`, не используя client Health history;
- отсутствие activity не создаёт отдельный reset, penalty, награду или ENERGY;
- mobile принимает legacy omission и fail-closed отклоняет невозможные
  диапазоны или inconsistent `targetReached`;
- RU/EN presentation явно нормализует дни отдыха, использует одну semantics-
  строку и выдерживает compact text scale 1.6;
- backend unit/API/PostgreSQL и Flutter parser/widget/localization coverage
  подтверждают inclusive current date, нижнюю границу окна и совместимость.

**Статус:** non-punitive weekly activity rhythm реализован без migration и без
изменения daily goal, rewards/economy, progression, topology или external
validation status.

### US-061. Видеть форму своей недели без наказания за отдых

Как игрок, я хочу видеть активные и спокойные дни внутри мягкого ритма 4/7,
чтобы понимать форму недели без streak reset, чувства провала и просмотра
Health history.

Критерии:

- Home расширяет `weeklyActivityRhythm` полным `days` trail из семи элементов
  `{localDate, active}` от target `localDate - 6` до target date;
- backend отмечает active только по persisted
  `activity_sync_state.accepted_total > 0`, строит rest dates как
  authoritative read projection и не публикует step totals;
- порядок хронологический, даты непрерывны, последняя совпадает с Home
  `localDate`, а количество active entries равно `activeDays`;
- mobile принимает legacy weekly object без `days`, но fail-closed отклоняет
  malformed types, неверную длину, gap/duplicate/end date или inconsistent
  count;
- RU/EN presentation использует walking marker для activity и нейтральный rest
  marker, одну полную semantics-строку и compact reflow при text scale 1.6;
- backend unit/API/PostgreSQL и Flutter parser/widget/localization coverage
  подтверждают inclusive endpoint, lower boundary и no-punishment semantics.

**Статус:** authoritative weekly activity day trail реализован без migration и
без изменения daily goal, rewards/economy, progression, topology или external
validation status.

### US-062. Понимать, сколько активных дней осталось до мягкой цели

Как игрок, я хочу видеть спокойную подсказку об оставшемся числе активных дней,
чтобы понимать ближайший ориентир ритма 4/7 без streak pressure и ощущения,
что день отдыха является провалом.

Критерии:

- mobile выводит `max(targetActiveDays - activeDays, 0)` только из уже
  валидированного server-authoritative `weeklyActivityRhythm`;
- при остатке 1 и 2–4 RU/EN copy использует корректную singular/plural форму и
  явно сохраняет правило, что отдых не сбрасывает прогресс;
- после достижения цели UI оставляет success/rest-normal copy и не показывает
  нулевую remaining-подсказку или reward claim;
- legacy Home без weekly object остаётся без weekly presentation, а client не
  читает Health history и не использует clock для восстановления данных;
- visible guidance входит в общую semantics summary; RU/EN widget и compact
  text-scale 1.6 coverage проверяют copy, отсутствие дублей и reflow.

**Статус:** gentle weekly rhythm guidance реализована как mobile presentation
над существующим authoritative контрактом без изменения API, migration,
daily goal, rewards/economy, progression, topology или external validation
status.

### US-063. Узнать, какой день в недельном ритме является сегодняшним

Как игрок, я хочу сразу видеть сегодняшний день и его active/rest status,
чтобы понимать текущую форму rolling week без расшифровки порядка маркеров и
без ощущения, что нейтральный отдых является провалом.

Критерии:

- mobile определяет today только совпадением server-owned Home `localDate` с
  authoritative endpoint `weeklyActivityRhythm.days`, без device clock;
- RU/EN visible copy показывает ту же локализованную дату и active либо
  нейтральный rest status;
- exact today marker получает тонкую primary outline, но сохраняет walking или
  moon glyph и соответствующий active/rest tone;
- today status входит в одну weekly semantics summary ровно один раз, а visual
  child не создаёт duplicate screen-reader announcement;
- legacy weekly object без `days` не получает today copy или marker highlight;
- RU/EN active/rest widget и compact text-scale 1.6 coverage проверяют copy,
  distinction, omission и отсутствие overflow.

**Статус:** authoritative today status реализован как presentation exact Home
local date без изменения API, migration, Health history, daily goal,
rewards/economy, progression, topology или external validation status.

### US-064. Видеть точные границы учитываемой недели

Как игрок, я хочу видеть первую и последнюю даты текущего rolling window,
чтобы понимать, какие дни входят в мягкий ритм 4/7, без расшифровки weekday
markers и без ощущения приближающегося streak reset.

Критерии:

- mobile выводит range только из first/last dates уже валидированного полного
  `weeklyActivityRhythm.days`, без device clock или нового window calculation;
- RU/EN copy локализует обе server-owned даты и называет их учитываемыми, не
  создавая deadline, future prediction, penalty или reward claim;
- legacy weekly object без `days` не получает inferred range;
- visible range входит в одну weekly semantics summary ровно один раз, а
  visual child не создаёт duplicate screen-reader announcement;
- RU/EN widget, legacy omission и compact 320 px / text scale 1.6 coverage
  проверяют copy, accessibility и отсутствие overflow.

**Статус:** authoritative weekly window range реализован как mobile
presentation над accepted trail без изменения Home API, migration, Health
history, daily goal, rewards/economy, progression, topology или external
validation status.

### US-065. Понимать остаток до личной дневной цели

Как игрок, я хочу видеть, сколько принятых шагов осталось до моей личной цели
сегодня, чтобы понимать ближайший ориентир без расчёта в уме и без ложного
обещания награды.

Критерии:

- mobile выводит `max(dailyGoal - dailySteps, 0)` только из уже принятого Home
  snapshot, без Health history, client clock или optimistic sync state;
- до цели RU/EN copy корректно склоняет remaining steps, а при равенстве или
  превышении показывает спокойное reached-состояние без surplus/reward claim;
- exact accepted total и feedback входят в одну daily-goal semantics summary,
  а visual children не создают duplicate screen-reader announcement;
- daily goal policy, weekly rhythm, Home API, backend, persistence и migration
  не меняются;
- domain и RU/EN widget coverage проверяют below/exact/above goal, semantics и
  compact 320 px / text scale 1.6 без overflow.

**Статус:** authoritative daily-goal feedback реализован как mobile
presentation над accepted `dailySteps`/`dailyGoal` без изменения расчёта цели,
ENERGY/rewards, progression или external validation status.

### US-066. Понимать, что делает день ритма активным

Как игрок, я хочу явно знать, когда день засчитывается в мягкий недельный ритм,
чтобы не считать достижение 100% личной цели обязательным условием active day.

Критерии:

- weekly presentation объясняет, что любая accepted activity делает день
  активным, а personal daily goal остаётся отдельной мерой;
- RU/EN clarification не меняет persisted positive-activity rule, не читает
  Health history и не выводит historical step totals;
- visible line входит в существующую weekly semantics summary ровно один раз,
  а visual child исключён из duplicate announcement;
- legacy aggregate-only weekly object получает правило без inferred dates,
  today status или day trail, а Home без weekly object остаётся без copy;
- RU/EN, semantics, legacy/absence и compact 320 px / text scale 1.6 widget
  coverage фиксируют presentation contract.

**Статус:** weekly active-day qualification реализована как mobile copy над
существующим authoritative contract без изменения API, daily goal,
ENERGY/rewards, progression или external validation status.

### US-067. Понимать, что сегодняшняя цель не растёт вместе с шагами

Как игрок, я хочу знать, что принятые сегодня шаги не повышают сегодняшнюю
личную цель, чтобы адаптивная система оставалась предсказуемой во время ходьбы.

Критерии:

- для explicit DEFAULT/ADAPTIVE policy Home объясняет, что accepted steps на
  текущей server-owned local date не повышают цель этой даты и могут
  учитываться в будущих личных целях;
- copy использует существующую backend-границу history `toExclusive =
  targetDate` и не вычисляет policy, дату или следующее значение на клиенте;
- visible RU/EN line входит в daily-goal semantics summary ровно один раз, а
  visual child исключён из duplicate announcement;
- legacy snapshot без `dailyGoalPolicy` не получает inferred stability rule;
- adaptive/default, RU/EN, semantics, legacy omission и compact 320 px / text
  scale 1.6 widget coverage фиксируют presentation contract.

**Статус:** daily-goal stability реализована как mobile presentation над
существующим accepted policy contract без изменения API, формулы цели,
ENERGY/rewards, progression или external validation status.

### US-068. Видеть, сколько XP осталось пилоту до следующего уровня

Как игрок, я хочу видеть точный остаток XP до следующего уровня пилота, чтобы
понимать близость развития без самостоятельного вычитания двух чисел.

Критерии:

- mobile принимает только progression snapshot с положительными level/target,
  неотрицательным current XP и target выше current; невозможные API-значения
  отклоняются до отображения;
- Home выводит одну RU/EN строку с current, target и exact remaining XP и
  bounded progress indicator только из accepted pilot state;
- индикатор исключён из semantics, а точная строка объявляется один раз без
  generic percentage duplicate;
- legacy/internal direct snapshot без валидного порога сохраняет прежний
  literal `current / target` fallback без индикатора и inferred remaining;
- domain, RU/EN, semantics и compact 320 px / text scale 1.6 coverage фиксируют
  presentation contract без изменения backend/API, порогов, level-up и наград.

**Статус:** pilot-level guidance реализована как mobile presentation над
существующими accepted Home XP fields без изменения progression, economy,
reward или external validation status.

### US-069. Видеть, сколько связи осталось до эволюции спутника

Как игрок, я хочу видеть точный остаток связи до следующей эволюции спутника,
чтобы понимать близость новой формы без самостоятельного вычитания.

Критерии:

- mobile выводит non-negative remaining только из принятых Platform полей
  `bond` и server-authored `evolutionBond`;
- растущий спутник получает точную RU/EN строку, а ready-to-evolve и fully
  evolved состояния сохраняют прежние guidance и не получают fake target;
- exact remaining входит в семантику `CompanionBondSignal` ровно один раз,
  а повторяющая его visual line исключена из assistive announcement;
- domain, RU/EN, semantics, ready/final и compact text-scale 1.6 coverage
  фиксируют presentation contract;
- backend/API/schema, thresholds, evolution command, rewards, economy и
  external validation status не меняются.

**Статус:** companion evolution guidance реализована как mobile presentation
над существующим accepted Platform pet snapshot без переноса server-owned
порогов или evolution rules на клиент.

### US-070. Видеть, сколько сезонного XP осталось до открытия навыка

Как игрок, я хочу видеть точный остаток сезонного XP до закрытого навыка,
чтобы понимать близость открытия без самостоятельного вычитания.

Критерии:

- mobile fail-closed отклоняет отрицательный server-authored
  `requiredSeasonXp` до rendering/cache handoff;
- remaining вычисляется только из accepted `seasonXp` и skill requirement и
  ограничивается снизу нулём;
- закрытый unavailable навык получает точную RU/EN строку, а ready-to-unlock и
  unlocked состояния сохраняют прежние requirement copy и действия;
- exact visible guidance входит в accessibility tree один раз без отдельного
  client-owned progress или reward promise;
- domain, RU/EN, reached/unlocked и compact text-scale 1.6 coverage фиксируют
  presentation contract без изменения backend/API, порогов или unlock command.

**Статус:** skill XP guidance реализована как mobile presentation над
существующими accepted Platform fields без переноса server-owned skill rules
на клиент.

### US-071. Видеть, сколько осталось до выполнения задания

Как игрок, я хочу видеть точный остаток шагов или событий до незавершённого
задания, чтобы понимать близость выполнения без самостоятельного вычитания.

Критерии:

- remaining вычисляется только как non-negative разность accepted `target` и
  `progress` задания;
- незавершённые `TOTAL_ACCEPTED_STEPS` и `RESOLVED_EVENTS` получают короткую
  точную RU/EN строку с корректной формой единицы;
- ready и claimed задания не получают fake remaining и сохраняют прежние
  badges, rewards и claim action;
- `SQUAD_MEMBERSHIP` и неизвестная метрика сохраняют literal progress без
  client-inferred единицы или правила выполнения;
- exact remaining входит в существующую semantics summary ровно один раз;
- domain, RU/EN, ready/fallback и compact text-scale 1.6 coverage фиксируют
  presentation contract без изменения backend/API, targets или rewards.

**Статус:** quest remaining guidance реализована как mobile presentation над
существующими accepted Platform fields без переноса server-owned quest rules
на клиент.

### US-072. Видеть, сколько сезонного XP осталось до следующей награды

Как игрок, я хочу видеть следующий уровень сезонной награды и точный остаток
XP до него, чтобы понимать ближайшую цель без знания шага сезонной шкалы.

Критерии:

- Platform catalog публикует положительный `season.xpPerLevel`, а backend
  использует то же значение для reward eligibility, season level и связанного
  достижения;
- mobile fail-closed валидирует новый порог и вычисляет next level/remaining
  только из accepted `seasonXp`, `levels` и `xpPerLevel`;
- RU/EN guidance показывается до следующего reward level, но не обещает его
  содержимое и не меняет существующую claim action;
- final level не получает fake next reward, а legacy cached snapshot без
  `xpPerLevel` сохраняет прежний claim fallback без inferred guidance;
- backend catalog/service, mobile domain, RU/EN, semantics, final/legacy и
  compact text-scale 1.6 coverage фиксируют authoritative boundary без
  persistence migration или изменения reward payload.

**Статус:** season reward guidance реализована над additive server-authored
catalog field; persisted state, reward contents и command protocol не меняются.

### US-073. Видеть, сколько достижений осталось открыть

Как игрок, я хочу видеть точный остаток достижений до полного каталога, чтобы
понимать общий прогресс без самостоятельного вычитания.

Критерии:

- unlocked count — пересечение stable IDs accepted achievement catalog и
  accepted user achievement set;
- dynamic season-reward receipts и будущие non-catalog IDs не увеличивают
  catalog progress и не делают совместимый snapshot невалидным;
- неполный каталог получает точную RU/EN remaining-строку, полный — спокойное
  complete state без обещания награды;
- aggregate progress и guidance входят в одну semantics summary, а отдельные
  achievement tiles сохраняют собственные locked/unlocked semantics;
- domain, RU/EN и compact text-scale 1.6 coverage фиксируют presentation
  boundary без изменения backend/API или unlock rules.

**Статус:** achievement collection guidance реализована как mobile projection
двух accepted Platform полей; отдельные условия достижений не выводятся и не
дублируются на клиенте.

## P1 — расширение MVP

### US-076. Видеть прогресс коллекции косметики

Как игрок, я хочу видеть точный остаток косметики до полного accepted каталога,
чтобы понимать общий прогресс коллекции без ручного подсчёта.

Критерии:

- owned count — пересечение accepted `content.cosmetics` и
  `userState.ownedCosmetics`;
- retired и будущие non-catalog owned IDs не увеличивают progress;
- неполная коллекция получает exact RU/EN remaining, полная — спокойное
  complete state без обещания награды;
- progress и guidance объявляются одной semantics summary;
- purchase/equip actions, slots, prices и ownership rules не меняются.

**Статус:** cosmetic collection guidance реализована как mobile projection
двух accepted Platform полей без изменения backend/API или commerce commands.

### US-077. Видеть прогресс коллекции навыков пилота

Как игрок, я хочу видеть точный остаток навыков до полного accepted каталога,
чтобы понимать общий прогресс развития пилота без ручного подсчёта карточек.

Критерии:

- unlocked count — пересечение accepted `content.skills` и
  `userState.unlockedSkills`;
- retired и будущие non-catalog unlocked IDs не увеличивают progress;
- неполная коллекция получает exact RU/EN remaining, полная — спокойное
  complete state без обещания награды;
- progress и guidance объявляются одной semantics summary;
- per-skill thresholds, availability, unlock actions и server rules не
  меняются.

**Статус:** pilot skill collection guidance реализована как mobile projection
двух accepted Platform полей без изменения backend/API или unlock command.

### US-078. Видеть число доступных наград за задания

Как игрок, я хочу видеть, сколько выполненных заданий ещё имеют неполученную
награду, чтобы не искать готовые действия среди всех карточек.

Критерии:

- claimable count включает только accepted quests с `ready == true` и
  `claimed == false`;
- incomplete и claimed quests не входят в count;
- положительный count получает короткую RU/EN singular/plural строку, zero не
  создаёт шум или fake reward promise;
- visible guidance объявляется одной semantics node;
- progress, targets, reward contents/order и claim command не меняются.

**Статус:** claimable quest reward count реализован как mobile projection
accepted per-quest state без изменения backend/API или reward economy.

### US-079. Видеть число навыков, доступных для открытия

Как игрок, я хочу видеть, сколько навыков уже достигли своего порога сезонного
XP, чтобы не искать доступные действия среди всех карточек.

Критерии:

- unlockable count включает только accepted catalog skills, которых нет в
  accepted `unlockedSkills` и чей `requiredSeasonXp` не выше accepted
  `seasonXp`;
- unlocked, threshold-not-reached и non-catalog identities не входят в count;
- положительный count получает короткую RU/EN singular/plural строку, zero не
  создаёт шум или fake unlock promise;
- visible guidance объявляется одной semantics node;
- thresholds, availability rules, unlock command и rewards не меняются.

**Статус:** unlockable pilot skill count реализован как mobile projection
accepted catalog thresholds и user state без изменения backend/API.

### US-080. Видеть число питомцев, готовых к эволюции

Как игрок, я хочу видеть, сколько питомцев уже готовы к эволюции, чтобы не
искать доступные действия среди всех карточек спутников.

Критерии:

- ready count включает только accepted pets с существующим `canEvolve == true`;
- growing и fully evolved pets не входят в count;
- положительный count получает короткую RU/EN singular/plural строку, zero не
  создаёт шум или fake evolution promise;
- visible guidance объявляется одной semantics node;
- bond thresholds, maximum stage, evolution command и rewards не меняются.

**Статус:** evolvable companion count реализован как mobile projection
accepted pet state без изменения backend/API или progression rules.

### US-081. Видеть число косметических предметов, доступных для экипировки

Как игрок, я хочу видеть, сколько принадлежащих мне образов сейчас можно
надеть, чтобы не искать доступные действия среди всех карточек косметики.

Критерии:

- count включает только accepted catalog cosmetics, которые присутствуют в
  accepted `ownedCosmetics` и отсутствуют в accepted equipped cosmetic IDs;
- equipped, unowned и retired/non-catalog cosmetics не входят в count;
- положительный count получает короткую RU/EN singular/plural строку, zero не
  создаёт шум или fake availability promise;
- visible guidance объявляется одной semantics node;
- prices, purchase availability, ownership, slots и equip command не меняются.

**Статус:** equippable cosmetic count реализован как mobile projection
accepted catalog, ownership и equipped state без изменения backend/API или
commerce rules.

### US-082. Видеть число рецептов, готовых к созданию

Как игрок, я хочу видеть, сколько рецептов мастерской уже готовы к созданию,
чтобы не искать доступные действия среди всех рецептов.

Критерии:

- count включает только accepted crafting recipes с server-authored
  `status == READY`;
- `MISSING_MATERIALS` и `CRAFTED` не входят в count;
- mobile не пересчитывает availability по количеству материалов;
- положительный count получает короткую RU/EN singular/plural строку, zero не
  создаёт шум или fake availability promise;
- visible guidance объявляется одной semantics node;
- recipes, material costs, rewards и craft command не меняются.

**Статус:** craftable recipe count реализован как mobile projection accepted
server-authored recipe status без изменения backend/API или crafting economy.

### US-083. Видеть число улучшений предметов, готовых к применению

Как игрок, я хочу видеть, сколько улучшений снаряжения уже готовы к применению,
чтобы не искать доступные действия среди всех калибровок.

Критерии:

- count включает только accepted item upgrades с server-authored
  `status == READY`;
- `LOCKED`, `MISSING_MATERIALS` и `COMPLETED` не входят в count;
- mobile не пересчитывает availability по наличию предмета, уровню, редкости
  или количеству материалов;
- положительный count получает короткую RU/EN singular/plural строку, zero не
  создаёт шум или fake availability promise;
- visible guidance объявляется одной semantics node;
- upgrades, material costs, resulting level/rarity и apply command не
  меняются.

**Статус:** ready item upgrade count реализован как mobile projection accepted
server-authored upgrade status без изменения backend/API или upgrade economy.

### US-084. Видеть число предметов инвентаря, доступных для экипировки

Как игрок, я хочу видеть, сколько предметов инвентаря сейчас можно
экипировать, чтобы не искать доступные действия среди материалов и находок.

Критерии:

- count включает только accepted inventory items, для которых существующая
  projection `isEquippable` истинна, а `isEquipped` ложна;
- materials/non-equippable и уже equipped items не входят в count;
- mobile не пересчитывает availability по состоянию equipment slot, kind,
  rarity, level или собственным ownership rules;
- положительный count получает короткую RU/EN singular/plural строку, zero не
  создаёт шум или fake availability promise;
- visible guidance объявляется одной semantics node;
- equipment slots, route requirements и equip command не меняются.

**Статус:** equippable inventory item count реализован как mobile projection
accepted item identities без изменения backend/API или equipment command.

### US-085. Видеть число доступных решений текущего события

Как игрок, я хочу видеть, сколько решений текущего события уже доступно, чтобы
не искать рабочие действия среди заблокированных вариантов.

Критерии:

- count включает только accepted choices текущего unresolved event с
  существующим `availability == AVAILABLE`;
- `LOCKED` choices не входят в count;
- mobile не пересчитывает availability по equipment, item level, active pet,
  evolution stage, unlocked skills или другим требованиям;
- положительный count получает короткую RU/EN singular/plural строку, zero и
  resolved event не создают шум или fake availability promise;
- visible guidance объявляется одной semantics node;
- event topology, requirements, rewards, choice ordering и resolve command не
  меняются.

**Статус:** available expedition choice count реализован как mobile projection
accepted choice availability без изменения backend/API или event rules.

### US-086. Видеть заполнение комплекта снаряжения

Как игрок, я хочу видеть, сколько принятых слотов снаряжения уже заполнено,
чтобы понимать состояние комплекта без просмотра каждого слота.

Критерии:

- equipped count включает только accepted equipment slots с существующим
  `status == EQUIPPED`;
- total равен длине accepted equipment list;
- mobile не пересчитывает occupancy по inventory, item kind, compatibility,
  route requirements или собственным ownership rules;
- RU/EN guidance показывает exact `equipped / total`, включая zero equipped;
- visible guidance объявляется одной semantics node;
- equipment slot catalog, compatibility, route requirements и equipment
  command не меняются.

**Статус:** equipped slot progress реализован как mobile projection accepted
equipment status без изменения backend/API или equipment rules.

### US-087. Видеть число открытых узлов текущего похода

Как игрок, я хочу сразу видеть число уже открытых узлов текущего похода,
чтобы оценить длину принятого следа без ручного подсчёта точек.

Критерии:

- discovered count равен длине accepted `routeTrail` текущего похода;
- mobile не выводит future topology, total узлов, процент или следующий узел;
- непустой trail получает короткую RU/EN строку, legacy/empty trail не
  создаёт отдельную секцию или fake progress;
- видимая строка исключена из semantics, потому что существующий route summary
  уже объявляет то же число вместе с последней точкой;
- Home API, backend, persistence, route ordering и node states не меняются.

**Статус:** discovered route node count реализован как mobile projection
accepted current-journey trail без изменения backend/API или route rules.

### US-088. Видеть число решений текущего похода

Как игрок, я хочу сразу видеть число уже принятых решений текущего похода,
чтобы оценить историю маршрута без ручного подсчёта записей журнала.

Критерии:

- accepted count равен длине текущего `decisionLog`;
- mobile не соединяет журнал с `routeTrail`, не выводит event completion и не
  пересчитывает rewards или route state;
- непустой журнал получает существующую RU/EN count-строку, legacy/empty
  журнал сохраняет подсказку без отдельного zero-count сообщения;
- видимая строка исключена из semantics, потому что каждая запись уже
  объявляет свой index и total;
- Home API, backend, persistence, event resolution и ordering не меняются.

**Статус:** accepted current-journey decision count реализован как mobile
projection `decisionLog` без изменения backend/API или event rules.

### US-089. Видеть последнее сохранённое решение текущего похода

Как игрок, я хочу сразу видеть последнее уже сохранённое решение текущего
похода, чтобы вспомнить последний принятый исход без прокрутки всего журнала.

Критерии:

- latest summary использует только последний элемент accepted `decisionLog`;
- mobile сохраняет server list ordering, не сортирует записи по `resolvedAt` и
  не соединяет журнал с `routeTrail` или event state;
- непустой журнал показывает literal event/outcome и accepted save time в
  RU/EN, legacy/empty state сохраняет прежнюю подсказку;
- summary объявляется одной semantics node и остаётся читаемым на compact
  large-text layout;
- Home API, backend, persistence, rewards и event resolution не меняются.

**Статус:** latest accepted current-journey decision реализован как mobile
projection последнего элемента `decisionLog` без изменения server ordering.

### US-090. Видеть последний сохранённый выбор текущего похода

Как игрок, я хочу видеть, какой именно выбор был принят в последнем решении
текущего похода, чтобы восстановить контекст без поиска записи в полном журнале.

Критерии:

- latest summary использует literal `choiceTitle` только последнего элемента
  accepted `decisionLog`;
- mobile не соединяет запись с `routeTrail` или текущим event state, не
  выводит доступность, правильность или последствия выбора;
- RU/EN summary показывает accepted choice рядом с event/outcome/save time;
- summary сохраняет одну semantics node и compact large-text layout;
- legacy/empty state, Home API, backend, persistence, rewards и event
  resolution не меняются.

**Статус:** latest accepted current-journey choice реализован как literal
mobile projection `decisionLog.last.choiceTitle` без client inference.

### US-091. Видеть описание результата последнего решения

Как игрок, я хочу видеть, что именно произошло после последнего сохранённого
решения текущего похода, чтобы понять результат без поиска полной записи.

Критерии:

- latest summary использует literal `outcomeSummary` только последнего
  элемента accepted `decisionLog`;
- mobile не соединяет запись с `routeTrail` или текущим event state, не
  интерпретирует последствия и не агрегирует rewards;
- RU/EN summary показывает accepted outcome summary рядом с
  event/choice/outcome/save time;
- summary сохраняет одну semantics node и compact large-text layout;
- legacy/empty state, Home API, backend, persistence и event resolution не
  меняются.

**Статус:** latest accepted current-journey outcome summary реализован как
literal mobile projection `decisionLog.last.outcomeSummary`.

### US-092. Видеть награды последнего решения

Как игрок, я хочу видеть награды последнего сохранённого решения текущего
похода, чтобы сразу понимать полученный результат без поиска полной записи.

Критерии:

- latest summary использует reward fields только последнего элемента accepted
  `decisionLog`;
- mobile не агрегирует rewards между решениями, не пересчитывает economy и не
  соединяет запись с текущим state;
- RU/EN summary показывает persisted pilot XP, pet bond и material reward;
- summary сохраняет одну semantics node и compact large-text layout;
- legacy/no-reward/empty state, Home API, backend, persistence и event
  resolution не меняются.

**Статус:** latest accepted current-journey rewards реализованы как literal
mobile projection reward fields из `decisionLog.last`.

### US-093. Видеть время начала текущего похода

Как игрок, я хочу видеть, когда начался текущий поход, чтобы понимать его
временной контекст без привязки к первому сохранённому решению.

Критерии:

- Home возвращает additive nullable `expedition.startedAt` из persisted
  journey-start source exact текущего `journeyNumber`;
- backend не выводит start из первого decision, content или response time;
- RU/EN journal показывает locale-aware дату и время без расчёта elapsed
  duration на клиенте;
- malformed timestamp отклоняется, legacy response без поля остаётся читаемым;
- persistence, rewards, event resolution и внешние gates не меняются.

**Статус:** authoritative current-journey start time реализован как nullable
Home projection `expedition.startedAt`.

### US-094. Видеть текущую фазу похода

Как игрок, я хочу видеть фазу текущего похода в журнале, чтобы понимать,
продолжается путь, доступно решение или поход уже завершён.

Критерии:

- mobile принимает только authoritative `expedition.status` со значениями
  `IN_PROGRESS`, `EVENT_READY` или `COMPLETED`;
- phase не выводится повторно из energy, `routeTrail`, `decisionLog`, unlocked
  event или completion recap;
- RU/EN journal показывает одну visible phase label и одну semantics node;
- cached snapshot сохраняет accepted server status без пересчёта;
- Home API, backend, persistence, commands, rewards и event resolution не
  меняются.

**Статус:** current-journey phase реализована как literal mobile projection
accepted `expedition.status`.

### US-095. Видеть текущую точку похода

Как игрок, я хочу видеть текущую точку похода в журнале, чтобы понимать своё
положение без поиска последнего узла на карте маршрута.

Критерии:

- position использует только accepted `currentNodeId/currentNode`;
- known mutable current content локализуется существующим stable-ID catalog,
  unknown future ID сохраняет literal server fallback;
- mobile не выбирает position из последнего `routeTrail`, `decisionLog`, phase
  или unlocked event;
- RU/EN journal показывает одну visible position label и одну semantics node;
- Home API, backend, persistence, commands и event resolution не меняются.

**Статус:** current-journey position реализована как stable-ID-aware mobile
projection accepted current-node identity и copy.

### US-096. Видеть ENERGY-прогресс текущего похода

Как игрок, я хочу видеть принятый сервером ENERGY-прогресс текущего похода в
журнале, чтобы понимать его числовое состояние без перехода на главный экран.

Критерии:

- journal использует только accepted `expedition.progress/requiredEnergy`;
- RU/EN copy сохраняет literal integers, включая accepted over-target value;
- только visual indicator ограничивается диапазоном `0..1`;
- mobile не выводит из чисел phase, decision availability, completion,
  rewards, spendability или command eligibility;
- одна semantics node и compact large-text coverage фиксируют boundary без
  изменения Home API, backend, persistence или commands.

**Статус:** current-journey ENERGY progress реализован как literal mobile
projection accepted progress/target с bounded visual indicator.

### US-097. Видеть текущее событие похода

Как игрок, я хочу видеть принятое сервером текущее событие в журнале, чтобы
понимать, какое решение ожидает меня в активном походе.

Критерии:

- journal показывает только `unlockedEvent` со status exact `READY`;
- known mutable title локализуется по stable `eventId`, unknown future ID
  сохраняет literal server fallback;
- absent, `RESOLVED` и unknown status fail-closed не создают label;
- phase, current node, ENERGY progress, route trail, choices и decision log не
  используются для выбора или восстановления event;
- RU/EN label, одна semantics node и compact large-text coverage фиксируют
  boundary без изменения Home API, backend, persistence или commands.

**Статус:** current READY event title реализован как stable-ID-aware mobile
projection accepted `unlockedEvent`.

### US-098. Читать описание текущего события похода

Как игрок, я хочу видеть принятое сервером описание текущего события в
журнале, чтобы понимать контекст ожидающего решения.

Критерии:

- journal читает summary только из `unlockedEvent` со status exact `READY`;
- known mutable summary локализуется по stable `eventId`, unknown future ID
  сохраняет literal server fallback;
- absent, `RESOLVED` и unknown status fail-closed не создают event block;
- phase, current node, ENERGY progress, route trail, choices и decision log не
  используются для выбора или восстановления summary;
- RU/EN title и summary объявляются одной semantics node, compact large-text
  coverage не меняет Home API, backend, persistence или commands.

**Статус:** current READY event summary реализован как stable-ID-aware mobile
projection accepted `unlockedEvent` рядом с его authoritative title.

### US-099. Видеть число доступных вариантов текущего события

Как игрок, я хочу видеть число доступных вариантов READY-события в журнале,
чтобы заранее понимать объём ожидающего решения.

Критерии:

- count читается только из `unlockedEvent` со status exact `READY`;
- учитываются только choices с accepted server-owned `availability=AVAILABLE`,
  locked choices не увеличивают count и requirements не проверяются повторно;
- positive count виден в RU/EN, а legacy/empty, locked-only, absent,
  `RESOLVED` и unknown status не создают count;
- phase, current node, ENERGY progress, route trail, decision log, topology и
  catalog rules не используются для восстановления choices;
- title, summary и count объявляются одной semantics node; journal не получает
  actions, а compact large-text coverage не меняет API/backend/commands.

**Статус:** positive current READY event choice count реализован как mobile
projection accepted choice availability без client-owned eligibility rules.

### US-074. Видеть, сколько этапов первого пути осталось

Как игрок, я хочу видеть точный остаток этапов первого пути, чтобы понимать
общий прогресс без самостоятельного вычитания.

Критерии:

- completed count — пересечение accepted `content.onboardingSteps` и
  `userState.completedOnboardingSteps`;
- retired и будущие non-catalog completed IDs не увеличивают прогресс;
- неполный путь получает точную RU/EN remaining-строку, полный — спокойное
  complete state без обещания награды;
- progress и guidance объявляются одной route semantics summary, а строки
  этапов сохраняют собственные complete/incomplete semantics;
- domain, RU/EN и compact large-text coverage фиксируют boundary без изменения
  backend/API, порядка, completion rules или resume command.

**Статус:** first-journey remaining guidance реализована как mobile projection
двух accepted Platform полей без переноса onboarding rules на клиент.

### US-075. Видеть число доступных сезонных наград

Как игрок, я хочу видеть, сколько уже заработанных сезонных наград ещё не
получено, чтобы понимать доступный результат без ручного подсчёта уровней.

Критерии:

- earned boundary выводится только из accepted season XP, positive catalog
  `xpPerLevel` и final season level;
- accepted `season-reward-N` receipts исключают уже полученные уровни, а
  unrelated/future achievement IDs не влияют на count;
- положительный count получает короткую RU/EN singular/plural строку, нулевой
  и legacy cadence-absent state не создают шум или fake guidance;
- существующая кнопка по-прежнему получает первый доступный уровень и не
  меняет claim order, payload или reward contents;
- visible guidance объявляется одной semantics node; domain, RU/EN и compact
  large-text coverage фиксируют boundary.

**Статус:** claimable season reward count реализован как mobile projection
accepted cadence и receipt IDs без изменения backend/API или claim command.

Технически реализованы:

- первая глава из 18 основных узлов и staged optional topology вплоть до
  `first-light-causeway`;
- три питомца, active selection, две эволюции, навыки и собственные финальные
  исходы экспедиции;
- onboarding, задания и достижения;
- development push provider boundary с local/test-only registration;
- product analytics и experiment exposure;
- cohort funnel crafting/equipment/resonance с authoritative gameplay stages;
- read-only offline cache валидированных `home` / `platform` snapshots;
- расход материалов, два crafting recipe, два persistent unique item и
  server-authoritative single-item equipment slot;
- две последовательные server-authoritative ступени unique item вплоть до
  уровня 3/EPIC;
- expedition choices с authoritative minimum item level, active-pet,
  minimum evolution stage и unlocked-skill prerequisites.
- повторяемый цикл экспедиции с сохранением постоянной прогрессии.
- server-authoritative визуальный след узлов текущего похода без спойлеров
  будущей топологии.
- persisted выборы и исходы прямо на разрешённых точках текущего следа.
- server-authoritative журнал решений текущего похода со стабильным
  persisted outcome copy.
- persisted награды XP/связи/material рядом с каждой записью журнала решений.
- server-authoritative суммарный итог завершённого текущего похода.
- persisted разбивка полученной связи по питомцам в итогах текущего и недавних
  походов.
- lifetime-летопись всех подтверждённых походов с persisted разбивкой связи по
  спутникам, XP по пилотам, material rewards, решений, финалов маршрутов и
  legacy fallback.
- persisted финальное решение и исход в итогах текущего и недавних походов.

После физической device-validation и beta остаются продуктовые расширения:

- дальнейшие механики событий и нелинейные ветки сверх resonance/storm/orchard routes;
- дополнительные upgrade levels/rarity tiers и баланс material sinks;
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
