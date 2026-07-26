# Changelog

Все заметные изменения проекта фиксируются здесь.

## [Unreleased]

### Added

- idempotent `POST /api/v1/activity/sync` и PostgreSQL activity high-watermark;
- ENERGY wallet и append-only credit/debit ledger;
- production `GET /api/v1/home`;
- персональная дневная цель `adaptive-median-v1` по accepted activity history;
- прозрачный `dailyGoalPolicy` в home response и Flutter UI;
- persistent starter expedition и `POST /api/v1/expeditions/{expeditionId}/advance`;
- первое событие `signal-source-v1` с двумя server-owned choices;
- `POST /api/v1/events/{eventId}/resolve`;
- persistent `pilot_progress`, `pet_progress` и exact event response replay;
- Flutter clients для home, activity, expedition и event commands;
- pluggable `StepSource`;
- Apple HealthKit foreground step source;
- Google Health Connect foreground step source;
- Android Activity Recognition permission flow;
- IANA device timezone provider;
- development-only step source;
- retry coordinator, сохраняющий idempotency key для одного reading после ошибки;
- foreground durable mobile command outbox для activity, expedition и event-команд;
- versioned atomic file store с temporary/backup recovery и corruption detection;
- startup replay с прежним payload/idempotency key и authoritative home reload;
- versioned Android/iOS host projects;
- Android Health Connect и iOS HealthKit native configuration;
- Android debug APK и iOS Simulator build jobs;
- unit/API/PostgreSQL integration/mobile/platform tests;
- ADR по activity, economy, home, expedition, event resolution, platform Health boundary и durable mobile outbox;
- GitHub Actions CI и PR template.

### Changed

- first playable loop завершён до состояния `COMPLETED` и persistent rewards;
- home read-model возвращает pilot XP, pet bond, event choices, resolved outcome и server-owned личную цель;
- Android/iOS mobile по умолчанию использует platform health source;
- demo activity source включается только явным feature flag;
- mobile после каждой команды перечитывает server state без optimistic update;
- host-проекты больше не генерируются bootstrap-скриптами;
- CI дополнительно компилирует нативные Android/iOS приложения;
- roadmap разделяет готовую Health implementation и ещё не пройденную physical-device validation;
- mobile-команды разделены на независимые ACTIVITY/GAMEPLAY lanes с FIFO внутри каждой lane.

## [0.1.0] — 2026-07-25

### Added

- первоначальная концепция продукта;
- монорепозиторий;
- Java/Spring Boot backend shell;
- Flutter mobile shell;
- архитектурная документация;
- roadmap, backlog и первые ADR;
- Docker Compose с PostgreSQL.
