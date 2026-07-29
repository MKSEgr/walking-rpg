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
- три питомца с реальным active selection и независимым progression;
- material inventory с append-only ledger и защитой от повторной выдачи;
- foreground durable outbox для activity, expedition и event-команд;
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

Перед первой сетевой попыткой mobile сохраняет полный payload и idempotency key для activity sync, продвижения экспедиции и решения события. После потери ответа или завершения процесса следующий запуск повторяет ту же команду с тем же key. Успешно восстановленные команды всегда завершаются повторным чтением `GET /api/v1/home`; локальная очередь не считается источником игрового состояния.

Очередь разделена на независимые `ACTIVITY` и `GAMEPLAY` lane. Внутри lane команды обрабатываются FIFO. Network error, `408`, `429`, `5xx` и неоднозначный response остаются pending; подтверждённые остальные `4xx` становятся terminal failed и не блокируют следующие команды. Подробности: [ADR 0012](docs/adr/0012-foreground-durable-mobile-command-outbox.md).

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

Основные endpoint-ы:

```text
GET  /actuator/health
GET  /api/v1/system/info
GET  /api/v1/home?localDate=YYYY-MM-DD
POST /api/v1/activity/sync
POST /api/v1/expeditions/starter-expedition-v1/advance
POST /api/v1/events/signal-source-v1/resolve
POST /api/v1/events/echo-vault-v1/resolve
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
Flyway V1–V7 + PostgreSQL Testcontainers tests
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
- гарантированная background health/command delivery;
- enforcement anti-fraud по источникам (текущий риск-контур работает в shadow
  mode);
- нелинейные события, расход предметов, crafting и уникальные предметы;
- подтверждение темпа первого пути и первой недели на реальной alpha cohort.

Дальнейший порядок работ: [docs/ROADMAP.md](docs/ROADMAP.md).
