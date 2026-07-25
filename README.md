# Walking RPG

Монорепозиторий первоначального проекта мобильной walking-RPG для iOS и Android.

Главный документ проекта: **[PROJECT_VISION.md](PROJECT_VISION.md)**.

## Что уже находится в репозитории

- зафиксированная продуктовая концепция;
- Java/Spring Boot backend shell;
- Flutter mobile shell с демонстрационным главным экраном;
- черновая архитектура и API;
- roadmap и стартовый backlog;
- ADR с ключевыми решениями;
- локальный PostgreSQL в Docker Compose для следующего этапа.

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

## Backend

Требования:

- JDK 21;
- доступ в интернет при первом запуске Maven Wrapper.

Запуск:

```bash
cd backend
./mvnw spring-boot:run
```

Windows:

```powershell
cd backend
.\mvnw.cmd spring-boot:run
```

Проверка:

```text
GET http://localhost:8080/actuator/health
GET http://localhost:8080/api/v1/system/info
GET http://localhost:8080/api/v1/home/demo
```

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

PostgreSQL пока не подключён к стартовому endpoint-у, но инфраструктура подготовлена для следующего вертикального среза:

```bash
docker compose up -d postgres
```

## Первая цель

Реализовать путь:

```text
реальные шаги → идемпотентная синхронизация → энергия → продвижение одной экспедиции → одно событие
```

Подробности: [docs/ROADMAP.md](docs/ROADMAP.md).
