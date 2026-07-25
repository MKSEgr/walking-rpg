# Changelog

Все заметные изменения проекта фиксируются здесь.

## [Unreleased]

### Added

- первый контракт `POST /api/v1/activity/sync`;
- расчёт положительной дельты authoritative total;
- накопительное начисление энергии без потери остатка шагов;
- in-memory idempotency spike и диагностические risk status;
- единый формат validation/conflict ошибок с trace ID;
- ADR по семантике синхронизации активности;
- PostgreSQL persistence для пользователя, устройства, дневного sync state и idempotent response;
- Flyway-миграция первой постоянной модели;
- SHA-256 fingerprint нормализованного activity payload без сохранения сырых bucket-ов и attestation;
- PostgreSQL advisory transaction lock для конкурентных sync одного пользователя, включая разные устройства;
- Testcontainers integration tests для миграций, persistence и конкурентной обработки;
- ADR по постоянному activity state и транзакционной сериализации;
- `economy_wallet` и append-only `economy_ledger` для ENERGY;
- backfill ранее рассчитанной энергии из `processed_activity_sync`;
- economy snapshot `energyBalanceAfter` и `economyVersion` в activity response;
- economy-level защита от повторного source credit;
- транзакционный rollback-тест activity state + wallet + ledger + processed response;
- ADR по economy wallet/ledger;
- GitHub Actions CI для структуры репозитория, Java backend и Flutter mobile;
- шаблон pull request с критериями проверки.

### Changed

- activity sync repository по умолчанию переведён с in-memory на Spring JDBC;
- activity sync выполняется в одной транзакции;
- положительная энергия проводится через ledger в той же транзакции;
- processed response хранит activity и economy snapshot для точного идемпотентного повтора;
- документация веток приведена к фактической основной ветке `master`;
- roadmap отмечает созданный удалённый репозиторий, CI, persistent activity slice и первый economy slice.

## [0.1.0] — 2026-07-25

### Added

- первоначальная концепция продукта;
- монорепозиторий;
- Java/Spring Boot backend shell;
- Flutter mobile shell;
- архитектурная документация;
- roadmap, backlog и первые ADR;
- Docker Compose с PostgreSQL.
