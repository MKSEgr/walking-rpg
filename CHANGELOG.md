# Changelog

Все заметные изменения проекта фиксируются здесь.

## [Unreleased]

### Added

- идемпотентный `POST /api/v1/activity/sync`;
- PostgreSQL activity state и multi-device advisory lock;
- ENERGY wallet и append-only ledger;
- activity credit и exact response snapshot;
- production `GET /api/v1/home`;
- Flutter loading/error/retry и production JSON mapping;
- `POST /api/v1/expeditions/{expeditionId}/advance`;
- атомарный ENERGY debit с запретом отрицательного баланса;
- `expedition_progress` и `processed_expedition_advance`;
- стартовая экспедиция `starter-expedition-v1`;
- первый узел `outer-beacon` с порогом 30 ENERGY;
- событие `signal-source-v1` в статусе READY;
- Flutter client и UI-действие продвижения экспедиции;
- unit/API/PostgreSQL integration/mobile tests;
- ADR по activity sync, economy ledger, home read-model и expedition advance;
- GitHub Actions CI и PR template.

### Changed

- home read-model возвращает persistent expedition progress/status/version/event;
- economy repository поддерживает credit и debit;
- mobile больше не ограничивается чтением: progress command отправляется на backend;
- roadmap доведён до первого открытого события.

## [0.1.0] — 2026-07-25

### Added

- первоначальная концепция продукта;
- монорепозиторий;
- Java/Spring Boot backend shell;
- Flutter mobile shell;
- архитектурная документация;
- roadmap, backlog и первые ADR;
- Docker Compose с PostgreSQL.
