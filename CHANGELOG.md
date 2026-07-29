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
- `starter-v2` со вторым узлом `lumen-gate` и событием `echo-vault-v1`;
- persistent `inventory_stack` и append-only `inventory_ledger`;
- material rewards `lumen-shard` и `echo-thread` с exact idempotent replay;
- Flyway V5, переводящий завершённых пользователей `starter-v1` на второй узел без повторной награды;
- inventory и material reward snapshots в production home/Flutter UI;
- ADR по activity, economy, home, expedition, event resolution, platform Health boundary, durable mobile outbox и inventory;
- GitHub Actions CI и PR template;
- Flutter `Путевой журнал` для platform snapshot: onboarding, питомцы, навыки, задания, сезон, недельный маршрут, отряды, косметика и эксперименты;
- typed `PlatformApiClient`, `PlatformSnapshot` и `PlatformCommandResult`;
- restart-safe `PLATFORM_COMMAND` в mobile command outbox;
- нижняя навигация между экспедицией и путевым журналом;
- versioned read-only cache последних подтверждённых `home` и `platform` snapshots;
- явный офлайн-баннер, TTL, corruption recovery и запрет mutations поверх cached state;
- Spring Security OAuth2 Resource Server и production JWT profile;
- canonical request identity из JWT `sub`, actor/device claim mapping и `ROLE_USER`/`ROLE_ADMIN` authorization;
- dev-header authentication, изолированная только в local/test profile;
- security filter-chain, identity и controller regression tests.
- mobile-экран «Аккаунт и данные» с JSON export/share;
- двухэтапное подтверждение удаления и fresh OIDC login той же учётной записи;
- idempotent `POST /api/v1/account/deletion-requests` с постоянной квитанцией;
- Flyway V7 с минимизированным deletion receipt без raw OIDC subject;
- `410 ACCOUNT_DELETED` guard против пересоздания данных старым Bearer-токеном;
- удаление временной локальной копии JSON сразу после системного share flow;

### Changed

- first playable расширен до двух узлов, двух событий и persistent material reward;
- home read-model возвращает pilot XP, pet bond, event choices, material outcome, inventory и server-owned личную цель;
- Android/iOS mobile по умолчанию использует platform health source;
- demo activity source включается только явным feature flag;
- mobile после каждой команды перечитывает server state без optimistic update;
- host-проекты больше не генерируются bootstrap-скриптами;
- CI дополнительно компилирует нативные Android/iOS приложения;
- roadmap разделяет готовую Health implementation и ещё не пройденную physical-device validation;
- mobile-команды разделены на независимые ACTIVITY/GAMEPLAY lanes с FIFO внутри каждой lane;
- backend-контроллеры больше не принимают user/device/actor headers: identity приходит из `SecurityContext`;
- production defaults стали fail-closed: JWT включён, demo endpoint выключен.

## [0.1.0] — 2026-07-25

### Added

- первоначальная концепция продукта;
- монорепозиторий;
- Java/Spring Boot backend shell;
- Flutter mobile shell;
- архитектурная документация;
- roadmap, backlog и первые ADR;
- Docker Compose с PostgreSQL.

## Mobile OIDC session lifecycle

- Added Authorization Code + PKCE login for Android and iOS.
- Added Keychain/Android secure token storage and serialized refresh handling.
- Replaced client-supplied identity headers with same-origin Bearer transport.
- Added account-scoped cache/outbox cleanup and a runtime shutdown barrier.
- Added fresh-login confirmation for destructive account operations.
