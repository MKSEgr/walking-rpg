# Walking RPG

Монорепозиторий мобильной walking-RPG для iOS и Android.

Главный документ проекта: **[PROJECT_VISION.md](PROJECT_VISION.md)**.

Текущая delivery-оценка и операционный план:
[project assessment](docs/PROJECT_ASSESSMENT_2026-08-07.md),
[validation backlog](docs/VALIDATION_BACKLOG.md) и
[prompt «следующая задача → PR»](docs/NEXT_TASK_TO_PR_PROMPT.md).

## Текущее состояние

Первый технический игровой цикл уже работает сквозным образом:

```text
суммарные шаги текущего дня
→ идемпотентная синхронизация активности
→ ENERGY wallet + append-only ledger
→ home с личной дневной целью из предыдущих активных дней
→ реальный выбор одного из трёх питомцев
→ guided первый узел и событие
→ 18 узлов первой главы
→ постоянные XP пилота, bond питомца и материалы
→ persistent inventory
→ server-authoritative crafting и уникальный предмет
→ server-authoritative экипировка компаса
→ опциональный резонансный маршрут
→ durable карточка результата и явное подтверждение продолжения
→ завершённое состояние экспедиции
```

В проекте реализованы:

- Java 21 / Spring Boot backend;
- Flutter mobile;
- системная light/dark дизайн-основа в направлении soft science-fantasy,
  атмосферный экран экспедиции и плавающая игровая навигация;
- PostgreSQL + Flyway;
- Apple HealthKit и Google Health Connect как foreground-источники шагов;
- server-owned персональная дневная цель по истории accepted activity с
  RU/EN remaining/reached feedback и пояснением, что сегодняшние принятые шаги
  влияют только на будущие цели, а не повышают текущую;
- server-authoritative мягкий недельный ритм 4/7 с лентой active/rest dates,
  локализованными границами учитываемого окна, явным today-status и спокойной
  подсказкой об оставшихся активных днях; любая accepted activity засчитывает
  active day отдельно от личной цели, без streak reset и наград;
- development-only источник шагов для воспроизводимых локальных проверок;
- internal-only Validation Center с bounded per-launch journal и redacted
  schema-v1 JSON evidence, недоступный в release build;
- server-authoritative ENERGY economy;
- Home показывает принятые из backend значения: текущий XP пилота, порог
  следующего уровня и точный остаток в RU/EN; визуальный индикатор не меняет
  пороги, награды или progression на клиенте;
- production `GET /api/v1/home`;
- content-driven первая глава с 18 основными и staged optional узлами вплоть
  до `constellation-sanctuary` за Неизведанным рубежом, equipment-, active-pet-
  adult-pet- и unlocked-skill-gated server-owned choices;
- повторяемые походы после завершения главы: новый цикл начинается
  с первого узла, а пилот, питомец, навыки, инвентарь и снаряжение
  сохраняются;
- guided «Первый путь» от разрешения шагов до первого решения;
- server-authoritative funnel и time-to-value первого пути для alpha cohort,
  включая отдельное подтверждение показа первого результата;
- cohort compass funnel: client-reported recipe/route impressions отдельно от
  server-authoritative craft/equip/choice/completion facts;
- три питомца с реальным active selection, независимым progression и
  двумя эволюциями до взрослой формы, а также собственными исходами события
  на неизведанном рубеже;
- Platform показывает точный остаток server-authored bond до следующей
  эволюции спутника в RU/EN, не перенося пороги или evolution rules на mobile;
- закрытый навык показывает точный остаток сезонного XP до server-authored
  порога в RU/EN, сохраняя прежние ready/unlocked состояния и команды;
- незавершённые шаговые и событийные задания показывают точный остаток до
  server-authored target в RU/EN; ready, claimed и неизвестные метрики
  сохраняют прежние состояния и действия;
- material inventory с append-only credit/debit ledger, server-authoritative
  crafting, persistent unique item и equipment slot `NAVIGATION`;
- последовательное улучшение призматического секстанта до уровня 3/EPIC на
  материалах эпилога второго рассвета;
- level-3/EPIC маршрут секстанта к неизведанному рубежу с двумя общими и тремя
  зависящими от активного питомца server-owned исходами, а взрослая форма
  открывает 26-й узел и новое финальное событие, где «Чтение сигналов» ведёт
  в 27-й узел — Обсерваторию скрытого сигнала, а «Память маршрута» открывает
  28-й узел «Созвездие памяти»; «Дисциплина энергии» продолжает путь в 29-й
  узел «Меридиан рассвета», а «Ровный шаг» открывает 30-й узел «Переход
  первого света» с двумя финалами;
- durable event-result receipt, который восстанавливается через `GET /home`
  после потери ответа или restart;
- foreground durable outbox для activity, gameplay, platform и telemetry
  команд с owner-scoped recovery center;
- protected `stage`/`prod` backend profiles с fail-closed datasource и
  отключёнными sandbox payment/development push providers;
- reviewed DigitalOcean `walking-rpg-alpha-eu` deployment contract: non-root
  Java 21 container, managed PostgreSQL 17 bindables, pgJDBC CA delivery,
  immutable GHCR image digest с source SHA/tree guard, раздельные
  `/livez`/`/readyz` probes и owner runbook; реальный paid stage остаётся
  external validation;
- Auth0 Universal Login contract с email/Apple/Google и Telegram Enterprise
  OIDC template; Telegram использует back-channel PKCE S256 и только
  `openid profile`, а реальный bot/credential/device flow остаётся external
  validation;
- explicit Android API 36 target и fail-closed external protected-signing
  contract при unsigned/no-codesign обычном CI;
- effective sandbox-payment capability, учитывающая backend provider
  availability; mobile скрывает purchase UI в release build, при `false` и
  для cached snapshot;
- GitHub Actions для backend, Flutter, Android APK и iOS Simulator build.

## Платформенные шаги

Обычный Android/iOS запуск использует системное хранилище здоровья:

```text
Android → Health Connect
 iOS    → Apple HealthKit
```

Приложение запрашивает только чтение количества шагов. Оно не запрашивает пульс, сон, вес, геолокацию или медицинские записи. Mobile формирует cumulative total за текущий локальный день и отправляет на backend:

```text
localDate + IANA timeZone + authoritativeTotal
```

Клиент не рассчитывает энергию и не изменяет баланс оптимистично. После успешного `POST /api/v1/activity/sync` приложение заново читает `GET /api/v1/home`. Backend также возвращает личную дневную цель: медиана положительных accepted total за предыдущие семь локальных дней, увеличенная на 5%, округлённая до 250 и ограниченная диапазоном 2 000–12 000. Пока собрано меньше трёх активных дней, используется стартовая цель 6 000.

Текущая интеграция работает только по явному действию пользователя в
foreground. Код, unit/widget tests, Android debug APK и iOS Simulator build
проверены CI. Внутренний Validation Center связывает ручной прогон с exact
source/app/build metadata и создаёт redacted JSON, но сам по себе не является
evidence физического прогона. Проверка чтения реальных данных на физических
телефонах и часах остаётся отдельным этапом. Подробности:
[docs/HEALTH_API_SPIKE.md](docs/HEALTH_API_SPIKE.md) и
[docs/DEVICE_VALIDATION_PROTOCOL.md](docs/DEVICE_VALIDATION_PROTOCOL.md).

## Надёжная отправка команд

Перед первой сетевой попыткой mobile сохраняет полный payload и idempotency key
для activity sync, продвижения экспедиции, решения события, crafting и
equipment. Для
подтверждения результата outbox сохраняет `receiptId`: он же является единственным
server-side idempotency scope bodyless ACK-запроса. После потери ответа или
завершения процесса следующий запуск повторяет исходную команду. Успешно
восстановленные state-changing команды завершаются повторным чтением
`GET /api/v1/home`; локальная очередь не считается источником игрового
состояния.

Очередь разделена на `ACTIVITY`, `GAMEPLAY` и `TELEMETRY` lane.
Внутри lane команды обрабатываются FIFO; replay сохраняет state dependency
`ACTIVITY → GAMEPLAY`: retryable ACTIVITY оставляет GAMEPLAY нетронутой до
следующего replay, а `TELEMETRY` выполняется параллельно с этой цепочкой.
Experiment exposure не может задержать игровой ACK. Network error, `408`,
`429`, `5xx` и неоднозначный response остаются pending; подтверждённые
остальные `4xx` становятся terminal failed и не блокируют следующие команды.
Startup replay возвращает управление после state-changing цепочки;
close-tracked telemetry завершается отдельно и обновляет recovery badge.

Экран **«Сохранённые действия»** показывает только безопасную owner-scoped
сводку. `PENDING` можно повторить с исходным payload/key, но нельзя удалить.
`FAILED` не отправляется снова; пользователь может убрать только локальную
диагностическую запись. Повреждённый store виден fail-closed и не очищается
автоматически. Успешный ручной replay перечитывает authoritative state без
повторного startup replay и без перемонтирования основного shell; потеря
authenticated-сессии закрывает owner-scoped recovery/account routes. Подробности:
[ADR 0012](docs/adr/0012-foreground-durable-mobile-command-outbox.md) и
[ADR 0024](docs/adr/0024-mobile-command-recovery-and-telemetry-isolation.md).

## Первая глава, инвентарь, crafting и equipment

`chapter-1-v2` содержит 18 основных узлов от `outer-beacon` до `dawn-relay` и
опциональный `resonance-pocket`. После первого события backend переводит пользователя на
`lumen-gate`, для которого требуется ещё 45 ENERGY. Второе событие
`echo-vault-v1` выдаёт XP, bond активному питомцу и одну из материальных наград:

```text
stabilize-core → 2 × Люминовый осколок
follow-echo    → 1 × Нить эха
```

Материалы сохраняются в `inventory_stack`, а каждое начисление — в append-only
`inventory_ledger`. Повтор события с тем же idempotency key возвращает исходный
snapshot и не выдаёт предмет повторно. Существующие пользователи, завершившие
`starter-v1`, мигрируют без потери XP/bond и без ретроактивной material reward.
Подробности: [ADR 0014](docs/adr/0014-second-node-and-persistent-inventory.md).

Recipe `resonance-compass-v1` превращает `2 × lumen-shard` и
`1 × echo-thread` в единственный `resonance-compass`. Backend под
transaction-scoped user lock проверяет оба stack, пишет отрицательные audited
ledger entries, создаёт unique item instance и immutable response одним
commit. Flutter показывает server-owned статус рецепта в **«Мастерской»**,
сохраняет `CRAFTING` в GAMEPLAY outbox и после успеха перечитывает `GET /home`.
Cached state и неподтверждённый результат события остаются read-only.
Подробности: [ADR 0029](docs/adr/0029-server-authoritative-crafting.md).

Созданный компас можно экипировать в server-owned slot `NAVIGATION` через
restart-safe `EQUIPMENT` command. Home показывает authoritative loadout и
причину недоступности gated choice. В событии `mirror-delta-v1` выбор
`follow-resonance` повторно проверяется backend под expedition lock: только
экипированный компас открывает `resonance-pocket`, после которого путь
возвращается в `storm-archive`; обычный выбор продолжает основной маршрут.
V14 stage-ит v2 inactive: маршрут появляется только после отдельной
cluster-wide активации и полного drain старого backend pool.
V15 сохраняет время первой активации в immutable `activated_at`, поэтому
повторная публикация той же content version не сдвигает beta baseline. Для
нестандартного upgrade, где v2 уже публиковалась на V14, V15 требует явное
подтверждённое время первой активации и fail-closed отклоняет mutable
`created_at` как исторический источник.
V16 добавляет `(user_id, received_at)` index для server-owned D1/D7/D30
telemetry retention и сохраняет client `occurredAt` только как диагностику.
Mobile не меняет slot или availability оптимистично. Подробности:
[ADR 0030](docs/adr/0030-equipment-and-gated-routes.md).

Для закрытой beta network Home регистрирует idempotent compass impressions в
отдельной `TELEMETRY` lane. Cohort endpoint сопоставляет их с immutable
craft/equip/expedition/event receipts, отдельно показывает coverage и
out-of-order gaps и не выдаёт client display за игровой факт. Подробности:
[ADR 0031](docs/adr/0031-compass-beta-funnel.md).

Platform command fingerprint канонизирует JSON object keys рекурсивно и
сохраняет array order/scalar semantics. Это устраняет ложный idempotency
conflict после backend restart для двухполевых telemetry payload; исторические
fingerprints поддерживаются bounded fallback. Подробности:
[ADR 0033](docs/adr/0033-canonical-platform-command-fingerprints.md).

Новый mobile объявляет capability
`X-Walking-RPG-Capabilities: durable-event-result-v1`. После cluster-wide
активации `DURABLE_EVENT_RESULT_HANDOFF_ENABLED=true` backend возвращает для
такого resolution стабильный `receiptId`, `handoffRequired = true` и nullable
`nextNode`. Пока пользователь не подтвердил результат,
`GET /api/v1/home` возвращает top-level `pendingEventResult`, а mobile
показывает полную карточку решения и наград даже после restart. Кнопка
продолжения отправляет bodyless
`POST /api/v1/event-results/{receiptId}/acknowledge` через GAMEPLAY outbox и
только после подтверждённого ответа перечитывает home. Пока receipt не
подтверждён, backend отклоняет следующий advance или event resolution. Cached
карточка остаётся видимой, но read-only.

Если capability отсутствует или activation gate выключен, новый backend
сохраняет результат в legacy delivery mode (`handoffRequired = false`) и сразу
отмечает receipt подтверждённым: старый mobile не блокируется после события.
Новый mobile также принимает response старого backend без receipt/handoff
fields. Exact replay всегда возвращает delivery mode первого запроса.
Activation разрешена только после полного drain старых backend instances; для
rollback gate сначала выключается и число pending receipts доводится до нуля.
Если capable-клиент уже создал pending receipt, старый клиент того же аккаунта
должен быть обновлён или результат нужно подтвердить на capable-клиенте.
Подробности:
[ADR 0022](docs/adr/0022-durable-event-result-handoff.md) и
[ADR 0023](docs/adr/0023-acknowledged-first-journey-result.md).

## Структура

```text
.
├── PROJECT_VISION.md
├── CONTRIBUTING.md
├── backend/
├── mobile/
│   ├── android/
│   └── ios/
├── docs/
├── scripts/
└── compose.yaml
```

Android- и iOS-host проекты находятся в репозитории и не генерируются при каждом клонировании.

## Быстрый запуск backend

Требования:

- JDK 21;
- Docker;
- доступ в интернет при первой загрузке Maven Wrapper и зависимостей.

```bash
docker compose up -d postgres
cd backend
./mvnw spring-boot:run
```

Windows:

```powershell
docker compose up -d postgres
cd backend
.\mvnw.cmd spring-boot:run
```

Локальный профиль явно включает development providers:
`walking-rpg.providers.payment=sandbox` и
`walking-rpg.providers.push=development`. Базовая конфигурация, `stage` и
`prod` используют `disabled`. Protected startup также требует явные
PostgreSQL credentials и verified-TLS JDBC URL; пример переменных без секретов
находится в `backend/.env.production.example`.

Наличие этих guard-ов и synthetic backup/restore CI не означает, что
production database/IdP или реальные payment/push providers уже настроены.
Deployment, monitoring и датированный restore реального backup остаются
отдельными gates.

Основные endpoint-ы:

```text
GET  /livez
GET  /readyz
GET  127.0.0.1:8081/actuator/health/{liveness,readiness}
GET  127.0.0.1:8081/actuator/prometheus (ROLE_ADMIN)
GET  /api/v1/system/info
GET  /api/v1/home?localDate=YYYY-MM-DD
POST /api/v1/activity/sync
POST /api/v1/expeditions/starter-expedition-v1/advance
POST /api/v1/expeditions/starter-expedition-v1/journeys
POST /api/v1/events/signal-source-v1/resolve
POST /api/v1/events/echo-vault-v1/resolve
POST /api/v1/event-results/{receiptId}/acknowledge
POST /api/v1/crafting/recipes/{recipeId}/craft
POST /api/v1/equipment/slots/{slotId}/equip
POST /api/v1/equipment/slots/{slotId}/unequip
POST /api/v1/platform/commands
GET  /api/v1/admin/platform/analytics/first-journey?cohortCode=...
GET  /api/v1/admin/platform/analytics/compass-journey?cohortCode=...
```

Подробности: [backend/README.md](backend/README.md).

## Быстрый запуск mobile

Требования:

- Flutter 3.44.7;
- Android SDK и/или Xcode;
- запущенный backend.

Android Emulator:

```bash
cd mobile
flutter pub get
flutter run \
  --dart-define=MOBILE_AUTH_MODE=development \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080 \
  --dart-define=DEMO_USER_ID=demo-user-1 \
  --dart-define=DEMO_DEVICE_ID=android-emulator-1
```

iOS Simulator:

```bash
cd mobile
flutter pub get
flutter run \
  --dart-define=MOBILE_AUTH_MODE=development \
  --dart-define=API_BASE_URL=http://127.0.0.1:8080 \
  --dart-define=DEMO_USER_ID=demo-user-1 \
  --dart-define=DEMO_DEVICE_ID=ios-simulator-1
```

На физическом устройстве вместо loopback/emulator host указывается LAN-адрес компьютера с backend.

В Android/iOS приложении появляется действие **«Синхронизировать шаги»**. Разрешения запрашиваются в момент этого действия.

### Явный development-режим

Для проверки без HealthKit/Health Connect:

```bash
flutter run \
  --dart-define=MOBILE_AUTH_MODE=development \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080 \
  --dart-define=DEMO_USER_ID=demo-user-1 \
  --dart-define=DEMO_DEVICE_ID=demo-device-1 \
  --dart-define=ENABLE_DEMO_ACTIVITY_SYNC=true \
  --dart-define=DEMO_STEP_TOTAL=6842 \
  --dart-define=ACTIVITY_TIME_ZONE=Europe/Berlin
```

Этот источник никогда не включается без явного feature flag.

Подробности: [mobile/README.md](mobile/README.md).

## Проверки

Pull request CI выполняет:

```text
Project structure
Backend compile + unit/API tests
Flyway V1–V17 + PostgreSQL Testcontainers tests
Synthetic PostgreSQL backup/restore drill + sanitized evidence
Adaptive daily-goal unit/API/integration tests
Dart formatting + Flutter analyze + Flutter tests
Android debug APK build
Android API 36 / external-signing scaffold rehearsal
iOS Simulator debug build
```

Локально:

```bash
./scripts/verify-project.sh
./scripts/bootstrap-mobile.sh
```

## Текущие границы

Пока не реализованы:

- проверка на физических iPhone/Android и связках телефон + часы;
- production IdP, APNs/FCM, store billing, signing и submission;
- production database/deployment, management network, monitoring/alerting,
  backup policy/PITR и датированный restore реального backup;
- гарантированная background health/command delivery;
- enforcement anti-fraud по источникам (текущий риск-контур работает в shadow
  mode);
- дополнительные нелинейные события, recipes, rarity/upgrades и
  проверенный по beta-данным баланс material sinks;
- подтверждение по реальному beta cohort пути recipe → craft → equip и
  обнаружения/завершения resonance route;
- подтверждение темпа первого пути и первой недели на реальной alpha cohort.

Дальнейший порядок работ: [docs/ROADMAP.md](docs/ROADMAP.md).

Protected signing не использует repository-local key files и описан отдельно:
[docs/PROTECTED_MOBILE_SIGNING.md](docs/PROTECTED_MOBILE_SIGNING.md).
