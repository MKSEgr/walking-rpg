# Changelog

Все заметные изменения проекта фиксируются здесь.

## [Unreleased]

### Added

- первый контракт `POST /api/v1/activity/sync`;
- расчёт положительной дельты authoritative total;
- накопительное начисление энергии без потери остатка шагов;
- in-memory idempotency spike и диагностические risk status;
- единый формат validation/conflict ошибок с trace ID;
- ADR по семантике синхронизации активности.

- GitHub Actions CI для структуры репозитория, Java backend и Flutter mobile;
- шаблон pull request с критериями проверки.

### Changed

- документация веток приведена к фактической основной ветке `master`;
- roadmap отмечает созданный удалённый репозиторий и добавленный CI.

## [0.1.0] — 2026-07-25

### Added

- первоначальная концепция продукта;
- монорепозиторий;
- Java/Spring Boot backend shell;
- Flutter mobile shell;
- архитектурная документация;
- roadmap, backlog и первые ADR;
- Docker Compose с PostgreSQL.
