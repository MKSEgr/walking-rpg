# Архитектура Walking RPG

## 1. Контекст и принципы

Проект развивается небольшой командой и поставляется проверяемыми вертикальными срезами.

- монорепозиторий;
- Flutter mobile;
- Java 21 / Spring Boot;
- PostgreSQL + Flyway;
- модульный монолит;
- REST/JSON;
- server-authoritative economy/content/progression;
- durable foreground command outbox;
- внешние providers за интерфейсами;
- Redis, broker и микросервисы только по измеренной необходимости.

## 2. Backend-модули

```text
security       — OIDC/JWT resource server, authorities и request identity
identity       — runtime users и pseudonymous device/session keys
activity       — cumulative activity, high-watermark и retention
goal           — персональная дневная цель
economy        — wallet и append-only ledger
expedition     — узлы, события и прохождение
progression    — pilot XP и pet bond
inventory      — stack и reward ledger
home           — агрегированный read model
platform       — onboarding, pets, skills, quests, season, squads, cosmetics, experiments
content        — versioned server-owned releases
risk           — anti-fraud signals, score и audit trail
shared         — общие API/error/transaction primitives
```

Пакеты группируются по функциональности, а не в глобальные слои controller/service/repository.

## 3. Mobile-модули

```text
core/config          — compile-time environment
core/commands        — durable commands, lanes и replay
core/cache           — read-only validated server snapshots
activity             — HealthKit/Health Connect и sync
home                 — authoritative home snapshot
expedition           — ENERGY spend
 event                — event resolution
platform             — typed snapshot, commands и «Путевой журнал»
app                   — навигационный shell
```

Android- и iOS-host проекты versioned в репозитории.

## 4. Сквозной activity flow

```text
HealthKit / Health Connect
→ aggregated steps за local day
→ persist ACTIVITY_SYNC payload + idempotency key
→ POST /api/v1/activity/sync
→ advisory lock user
→ positive delta
→ ENERGY credit + ledger
→ activity state + immutable response
→ authoritative GET /home
```

Mobile не отправляет сырые health samples и не вычисляет награду.

## 5. Gameplay и platform commands

```text
GAMEPLAY lane
├── EXPEDITION_ADVANCE
├── EVENT_RESOLUTION
└── PLATFORM_COMMAND
```

Все команды сохраняются до первой сетевой попытки. Retry использует тот же payload и idempotency key. Подтверждённый terminal 4xx переводит конкретную команду в `FAILED`, а transport/408/429/5xx остаются `PENDING`.

Platform snapshot содержит onboarding, три питомца, skills, quests, achievements, season, weekly route, squad, cosmetics, experiments и remote config. После успешной команды UI заменяет состояние snapshot-ом backend и перечитывает home; optimistic rewards не применяются.

## 6. Контент

Активная версия `chapter-1-v1` содержит 18 последовательных узлов от `outer-beacon` до `dawn-relay`, server-owned choices и material rewards. Stable IDs сохраняются между версиями; mutable user state отделён от definitions. `content_release` и remote config позволяют публиковать активную версию без переписывания исторических command responses.

## 7. Схема данных

Основные таблицы:

```text
app_user, app_device
activity_sync_state, processed_activity_sync
economy_wallet, economy_ledger
expedition_progress, processed_expedition_advance
pilot_progress, pet_progress, processed_event_resolution
inventory_stack, inventory_ledger
roadmap_user_state, processed_roadmap_command
remote_config_snapshot, content_release
roadmap_squad, roadmap_squad_member
platform_event, platform_crash_report
push_registration, payment_intent, tester_cohort_member
activity_risk_assessment
```

`processed_*` хранит fingerprint и immutable response. Повтор после restart не меняет состояние второй раз и возвращает канонический сохранённый результат.

## 8. Конкурентность и транзакции

- transaction-scoped advisory lock по user или user+expedition;
- row lock wallet/progression/inventory при изменении;
- idempotency lookup до мутации;
- source uniqueness в ledger;
- один transaction commit для связанных изменений;
- read endpoints не создают zero-state.

## 9. Ключевые инварианты

1. Клиент не задаёт accepted delta, rewards или баланс.
2. Один idempotency key не создаёт повторное списание/начисление.
3. Тот же key с другим payload возвращает conflict.
4. Wallet не становится отрицательным и меняется через ledger.
5. Activity high-watermark пользователя общий для устройств и не уменьшается.
6. Inventory stack меняется через inventory ledger.
7. Historical response не заменяется более новым snapshot.
8. Process restart не меняет pending payload/key.
9. Platform command first response равен replayed response.
10. Risk engine работает в shadow mode до внешней калибровки.
11. User/device/actor не принимаются контроллерами из произвольных headers или body в production.
12. Валидный JWT без прикладной `ROLE_USER`/`ROLE_ADMIN` не даёт доступ к API.

## 10. Identity и authorization boundary

```text
OIDC access token
→ signature + issuer + audience + expiration validation
→ sub = canonical userId
→ configurable role/scope claims
→ ROLE_USER / ROLE_ADMIN
→ RequestIdentity from SecurityContext
→ controller/application command
```

Базовый режим backend — `jwt`; demo endpoint выключен. `dev-header` существует только в явных `local`/`test` профилях и изолирует технические headers внутри одного filter-а. В production `/api/v1/admin/**` требует `ROLE_ADMIN`, остальные защищённые `/api/v1/**` — `ROLE_USER`.

Activity device identity получается из подписанного session/device claim и хранится как SHA-256 pseudonym. Произвольный `X-Device-Id` в JWT mode игнорируется. Публичными остаются только health/system info/content bootstrap и anonymous telemetry/crash ingestion.

Mobile Authorization Code + PKCE, secure token storage, refresh и logout являются следующим отдельным срезом. Подробности: `docs/adr/0017-production-authentication-boundary.md`.

## 11. Health boundary

```text
StepSource
├── PlatformHealthStepSource
│   ├── HealthGateway
│   ├── ActivityRecognitionGateway
│   └── DeviceTimeZoneProvider
└── DevelopmentStepSource
```

Только `STEPS READ`, local midnight → now, IANA timezone и foreground/manual sync. Resume fallback не выдаётся за гарантированную background delivery. Физическая матрица описана в `DEVICE_VALIDATION_PROTOCOL.md`.

## 12. Offline read model

```text
server GET /home|platform success
→ domain validation
→ versioned local snapshot

transport/408/429/5xx/malformed success
→ повторная domain validation cached JSON
→ read-only UI + explicit cache timestamp
```

Read cache не хранит неподтверждённые изменения и не заменяет command outbox. Перед mutation-attempt зависимый cache инвалидируется, потому что transport failure может скрывать уже принятый backend-ом результат. Terminal `4xx` не скрываются fallback-ом. Cached ENERGY не разрешает расходные команды.

Подробности: `docs/adr/0016-offline-read-cache.md`.

## 13. Release-quality model

```text
Standard CI
→ compile/tests/migrations
→ Flutter format/analyze/tests
→ Android debug APK
→ iOS Simulator build

Release quality
→ policy/static checks
→ deterministic metadata
→ backend JAR
→ Android unsigned release AAB
→ iOS release app --no-codesign

Protected external environment
→ production signing credentials
→ manual owner approval
→ store submission
```

CI не хранит signing material и не выдаёт неподписанный candidate за публикуемый build. Device, push, payment, beta и store gates получают статус `VALIDATED` только после evidence.

## 14. Branch protection

Feature-ветки обновляет `serbin70`; `master` защищён ruleset и CODEOWNERS. Merge выполняет `MKSEgr` после CI/review через `Squash and merge`. Подробности: `BRANCH_PROTECTION.md`.
