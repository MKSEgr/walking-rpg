# Changelog

Все заметные изменения проекта фиксируются здесь.

## [Unreleased]

### Added

- idempotent `POST /api/v1/activity/sync` и PostgreSQL activity high-watermark;
- ENERGY wallet и append-only credit/debit ledger;
- production `GET /api/v1/home`;
- persistent starter expedition и `POST /api/v1/expeditions/{expeditionId}/advance`;
- первое событие `signal-source-v1` с двумя server-owned choices;
- `POST /api/v1/events/{eventId}/resolve`;
- persistent `pilot_progress`, `pet_progress` и exact event response replay;
- Flutter clients для home, activity, expedition и event commands;
- pluggable `StepSource` и development-only source для mobile → backend проверки;
- retry coordinator, сохраняющий idempotency key для одного reading после ошибки;
- unit/API/PostgreSQL integration/mobile widget tests;
- ADR по activity, economy, home, expedition, event resolution и mobile activity boundary;
- GitHub Actions CI и PR template.

### Changed

- first playable loop завершён до состояния `COMPLETED` и persistent rewards;
- home read-model возвращает pilot XP, pet bond, event choices и resolved outcome;
- mobile после каждой команды перечитывает server state без optimistic update;
- документация приведена к фактически реализованному состоянию после PR #16;
- roadmap разделяет стабильный activity HTTP contract и platform Health API risk.

## [0.1.0] — 2026-07-25

### Added

- первоначальная концепция продукта;
- монорепозиторий;
- Java/Spring Boot backend shell;
- Flutter mobile shell;
- архитектурная документация;
- roadmap, backlog и первые ADR;
- Docker Compose с PostgreSQL.
