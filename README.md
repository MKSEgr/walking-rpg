# Walking RPG

Монорепозиторий первоначального проекта мобильной walking-RPG для iOS и Android.

Главный документ проекта: **[PROJECT_VISION.md](PROJECT_VISION.md)**.

## Что уже находится в репозитории

- зафиксированная продуктовая концепция;
- Java/Spring Boot backend;
- Flutter mobile shell с демонстрационным главным экраном;
- activity-sync контракт с PostgreSQL persistence и idempotency;
- economy wallet и append-only ENERGY ledger;
- черновая архитектура и API;
- roadmap и стартовый backlog;
- ADR с ключевыми решениями;
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

Проверка:

```text
GET  http://localhost:8080/actuator/health
GET  http://localhost:8080/api/v1/system/info
GET  http://localhost:8080/api/v1/home/demo
POST http://localhost:8080/api/v1/activity/sync
```

Подробности: [backend/README.md](backend/README.md).

## Mobile

В архив намеренно не включены сгенерированные host-проекты Android/iOS: их создаёт установленная локально версия Flutter, чтобы не фиксировать устаревшие Gradle/Xcode-шаблоны.

```bash
cd mobile
flutter create --platforms=android,ios --org com.walkingrpg --project-name walking_rpg_mobile .
flutter pub get
flutter run
```

Или используйте скрипт:

```bash
./scripts/bootstrap-mobile.sh
```

Windows PowerShell:

```powershell
.\scripts\bootstrap-mobile.ps1
```

## Локальная БД

```bash
docker compose up -d postgres
```

Backend подключается к PostgreSQL по умолчанию и автоматически применяет Flyway-миграции. Accepted activity state, idempotent response, ENERGY wallet и ledger сохраняются между перезапусками. Дневной reward high-watermark общий для пользователя, поэтому разные устройства не создают независимое начисление за один cumulative total.

## Текущая вертикальная цель

```text
реальные шаги
→ идемпотентная синхронизация
→ PostgreSQL activity state
→ economy wallet и ledger
→ production home state
→ трата энергии
→ один игровой узел
→ одно событие
```

Подробности: [docs/ROADMAP.md](docs/ROADMAP.md).
