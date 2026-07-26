# Walking RPG

Монорепозиторий мобильной walking-RPG для iOS и Android.

Главный документ проекта: **[PROJECT_VISION.md](PROJECT_VISION.md)**.

## Текущее состояние

Первый технический игровой цикл уже работает сквозным образом:

```text
authoritative step total
→ idempotent activity sync
→ ENERGY wallet + ledger
→ expedition advance
→ first event choice
→ persistent pilot XP + pet bond
→ completed expedition home state
```

В репозитории находятся:

- Java 21 / Spring Boot backend;
- Flutter mobile;
- PostgreSQL + Flyway;
- идемпотентная синхронизация шагов;
- server-authoritative ENERGY economy;
- production `GET /api/v1/home`;
- постоянная стартовая экспедиция;
- два варианта решения события `signal-source-v1`;
- постоянные XP пилота и bond питомца;
- development-only источник шагов для проверки mobile → backend;
- архитектурная документация, roadmap, backlog и ADR;
- GitHub Actions для структуры, backend и mobile.

## Структура

```text
.
├── PROJECT_VISION.md
├── CONTRIBUTING.md
├── backend/
├── mobile/
├── docs/
├── scripts/
└── compose.yaml
```

## Проверки проекта

После открытия pull request GitHub Actions выполняет:

- проверку структуры репозитория;
- compile, unit/API и PostgreSQL Testcontainers tests на Java 21;
- `dart format`, `flutter analyze` и `flutter test` на Flutter 3.44.7.

Локальная структурная проверка:

```bash
./scripts/verify-project.sh
```

## Backend

Требования:

- JDK 21;
- Docker для PostgreSQL и интеграционных тестов;
- доступ в интернет при первом запуске Maven Wrapper.

Запуск:

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
GET  /api/v1/home/demo
GET  /api/v1/home?localDate=YYYY-MM-DD
POST /api/v1/activity/sync
POST /api/v1/expeditions/starter-expedition-v1/advance
POST /api/v1/events/signal-source-v1/resolve
```

Подробности: [backend/README.md](backend/README.md).

## Mobile

Host-проекты Android/iOS пока генерируются локально установленной версией Flutter:

```bash
cd mobile
flutter create --platforms=android,ios \
  --org com.walkingrpg \
  --project-name walking_rpg_mobile .
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080 \
  --dart-define=DEMO_USER_ID=demo-user-1
```

Для iOS Simulator вместо `10.0.2.2` используется `127.0.0.1`.

### Явная development-синхронизация шагов

До подключения Apple Health и Health Connect можно проверить настоящий HTTP-путь mobile → backend через development source:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080 \
  --dart-define=DEMO_USER_ID=demo-user-1 \
  --dart-define=DEMO_DEVICE_ID=demo-device-1 \
  --dart-define=ENABLE_DEMO_ACTIVITY_SYNC=true \
  --dart-define=DEMO_STEP_TOTAL=6842 \
  --dart-define=ACTIVITY_TIME_ZONE=Europe/Berlin
```

Этот режим:

- отображает отдельную кнопку **«Синхронизировать тестовые шаги»**;
- отправляет authoritative total в production activity endpoint;
- после успеха перечитывает `GET /home`;
- не включается без явного feature flag;
- не является заменой HealthKit/Health Connect.

Подробности: [mobile/README.md](mobile/README.md).

## Локальная БД

```bash
docker compose up -d postgres
```

Flyway создаёт activity state, economy wallet/ledger, expedition progress, event resolution и pilot/pet progression. Все command response сохраняются для точного идемпотентного replay после перезапуска.

## Следующая вертикальная цель

```text
StepSource abstraction
→ Apple Health / Health Connect spike
→ permissions and source metadata
→ real authoritative total
→ existing activity sync client
```

Подробности: [docs/ROADMAP.md](docs/ROADMAP.md).
