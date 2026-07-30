# Walking RPG

Монорепозиторий мобильной walking-RPG для iOS и Android.

Главный документ проекта: **[PROJECT_VISION.md](PROJECT_VISION.md)**.

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
→ durable карточка результата и явное подтверждение продолжения
→ завершённое состояние экспедиции
```

В проекте реализованы:

- Java 21 / Spring Boot backend;
- Flutter mobile;
- PostgreSQL + Flyway;
- Apple HealthKit и Google Health Connect как foreground-источники шагов;
- server-owned персональная дневная цель по истории accepted activity;
- development-only источник шагов для воспроизводимых локальных проверок;
- server-authoritative ENERGY economy;
- production `GET /api/v1/home`;
- content-driven первая глава `chapter-1-v1` с 18 узлами и событиями;
- guided «Первый путь» от разрешения шагов до первого решения;
- server-authoritative funnel и time-to-value первого пути для alpha cohort,
  включая отдельное подтверждение показа первого результата;
- три питомца с реальным active selection и независимым progression;
- material inventory с append-only ledger и защитой от повторной выдачи;
- durable event-result receipt, который восстанавливается через `GET /home`
  после потери ответа или restart;
- foreground durable outbox для activity, gameplay, platform и telemetry
  команд с owner-scoped recovery center;
- protected `stage`/`prod` backend profiles с fail-closed datasource и
  отключёнными sandbox payment/development push providers;
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

Текущая интеграция работает только по явному действию пользователя в foreground. Код, unit/widget tests, Android debug APK и iOS Simulator build проверены CI. Проверка чтения реальных данных на физических телефонах и часах остаётся отдельным этапом. Подробности: [docs/HEALTH_API_SPIKE.md](docs/HEALTH_API_SPIKE.md).

## Надёжная отправка команд

Перед первой сетевой попыткой mobile сохраняет полный payload и idempotency key
для activity sync, продвижения экспедиции и решения события. Для подтверждения
результата outbox сохраняет `receiptId`: он же является единственным
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

## Первая глава и инвентарь

`chapter-1-v1` содержит 18 последовательных узлов от `outer-beacon` до
`dawn-relay`. После первого события backend переводит пользователя на
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

Наличие этих guard-ов не означает, что production database/IdP или реальные
payment/push providers уже настроены. Deployment, monitoring и фактический
backup/restore drill остаются отдельными gates.

Основные endpoint-ы:

```text
GET  /actuator/health
GET  /api/v1/system/info
GET  /api/v1/home?localDate=YYYY-MM-DD
POST /api/v1/activity/sync
POST /api/v1/expeditions/starter-expedition-v1/advance
POST /api/v1/events/signal-source-v1/resolve
POST /api/v1/events/echo-vault-v1/resolve
POST /api/v1/event-results/{receiptId}/acknowledge
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
Flyway V1–V12 + PostgreSQL Testcontainers tests
Adaptive daily-goal unit/API/integration tests
Dart formatting + Flutter analyze + Flutter tests
Android debug APK build
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
- production database/deployment, monitoring/alerting и фактический
  backup/restore drill;
- гарантированная background health/command delivery;
- enforcement anti-fraud по источникам (текущий риск-контур работает в shadow
  mode);
- нелинейные события, расход предметов, crafting и уникальные предметы;
- подтверждение темпа первого пути и первой недели на реальной alpha cohort.

Дальнейший порядок работ: [docs/ROADMAP.md](docs/ROADMAP.md).
