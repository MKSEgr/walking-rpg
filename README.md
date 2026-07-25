# Walking RPG

Монорепозиторий мобильной walking-RPG для iOS и Android.

Главный документ проекта: **[PROJECT_VISION.md](PROJECT_VISION.md)**.

## Что уже находится в репозитории

- зафиксированная продуктовая концепция;
- Java/Spring Boot backend;
- Flutter mobile shell;
- идемпотентная синхронизация шагов с PostgreSQL persistence;
- economy wallet и append-only ENERGY ledger;
- production `GET /api/v1/home` и загрузка состояния во Flutter;
- постоянная стартовая экспедиция с атомарным расходом ENERGY;
- первый игровой узел и событие `signal-source-v1`;
- архитектурная документация, roadmap, backlog и ADR;
- локальный PostgreSQL в Docker Compose;
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

Запуск из корня репозитория:

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
GET  http://localhost:8080/actuator/health
GET  http://localhost:8080/api/v1/system/info
GET  http://localhost:8080/api/v1/home/demo
GET  http://localhost:8080/api/v1/home?localDate=2026-07-25
POST http://localhost:8080/api/v1/activity/sync
POST http://localhost:8080/api/v1/expeditions/starter-expedition-v1/advance
```

Подробности: [backend/README.md](backend/README.md).

## Mobile

Сгенерированные host-проекты Android/iOS создаёт установленная локально версия Flutter:

```bash
cd mobile
flutter create --platforms=android,ios --org com.walkingrpg --project-name walking_rpg_mobile .
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080 \
  --dart-define=DEMO_USER_ID=demo-user-1
```

Для iOS Simulator вместо `10.0.2.2` используется `127.0.0.1`.

Или используйте bootstrap-скрипты:

```bash
./scripts/bootstrap-mobile.sh
```

```powershell
.\scripts\bootstrap-mobile.ps1
```

## Локальная БД

```bash
docker compose up -d postgres
```

Flyway создаёт activity state, economy wallet/ledger и expedition progress. Синхронизация шагов, начисление энергии, её расход, продвижение экспедиции и идемпотентные command response переживают перезапуск backend.

## Текущая вертикальная цель

```text
реальные шаги
→ идемпотентная синхронизация
→ ENERGY wallet и ledger
→ production home state
→ атомарный расход ENERGY
→ постоянная экспедиция
→ первый узел и событие
→ выбор исхода события
→ награда пилоту и питомцу
```

Подробности: [docs/ROADMAP.md](docs/ROADMAP.md).
