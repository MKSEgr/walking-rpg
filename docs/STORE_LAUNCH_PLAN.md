# Walking RPG — план до первой публикации в App Store и Google Play

Статус на 30 июля 2026 года. Документ отделяет:

- техническую готовность к сборке;
- готовность к загрузке в TestFlight / Play Console;
- готовность к отправке на review;
- фактическую публикацию;
- внешнюю проверку на устройствах и реальных пользователях.

## 1. Текущее состояние

Уже реализованы и проходят standard CI / Release quality:

- Java backend, PostgreSQL/Flyway, server-authoritative economy и activity sync;
- HealthKit / Health Connect foreground adapters;
- durable mobile command outbox;
- первая content-driven глава, progression, inventory и platform state;
- mobile UI «Экспедиция» и «Путевой журнал»;
- onboarding, питомцы, навыки, задания, сезон, недельный маршрут, отряды и косметика;
- remote config, analytics, crash ingestion, risk audit и tester cohorts;
- server-authoritative funnel первого пути и cohort time-to-value read model;
- mobile OIDC Authorization Code + PKCE, secure refresh/logout и
  owner-scoped local cleanup;
- экран «Аккаунт и данные», JSON export/share и idempotent удаление с durable
  receipt;
- backend account deletion registry, блокирующий stale Bearer token;
- backend OIDC/JWT resource-server boundary с `sub`, `ROLE_USER`/`ROLE_ADMIN` и fail-closed production profile;
- защищённые `stage`/`prod` profiles, verified-TLS datasource guard и
  local/test-only sandbox payment/development push;
- effective sandbox capability и mobile UI, скрывающий purchase action при
  release/disabled/cached state;
- bounded diagnostics/telemetry ingress, public no-detail probes, loopback
  management/Prometheus и fail-closed operational timeouts;
- synthetic PostgreSQL backup/restore drill с machine-verifiable evidence и
  явным `productionValidated=false`;
- backend JAR, Android release AAB candidate и iOS release no-codesign candidate;
- deterministic build metadata, privacy/store declaration drafts, release checklist и device validation protocol.

Последние завершённые программные срезы:

- guided первый путь от Health sync до первого события с реальным выбором
  активного питомца;
- exact-once milestones и cohort funnel/time-to-value read model для alpha;
- account export/delete с fresh OIDC authentication и локальной очисткой;
- A4a profile/provider isolation с Flyway V12 и effective-capability UI gate;
- A4b operational ingress/probes/timeouts и synthetic restore tooling.

## 2. Gate A — завершить store-candidate software

### A1. Offline read cache — `CODE_COMPLETE`

- валидированный fallback только для read-запросов;
- явный read-only режим и время сохранения snapshot;
- запрет расходных команд поверх cached state;
- invalidation перед state-changing server-командами; при ошибке локальной очистки команда не отправляется и остаётся retryable;
- TTL, corruption recovery, owner isolation и size/cap tests;
- standard CI, Android/iOS host builds и Release quality.

### A2. Production identity и authentication

Backend boundary — `CODE_COMPLETE`:

- Spring Security OAuth2 Resource Server;
- JWT signature, issuer, audience, expiration и обязательный `sub`;
- `sub` как canonical userId, actor из настраиваемого username claim;
- `ROLE_USER` для пользовательского API и `ROLE_ADMIN` для `/api/v1/admin/**`;
- activity device/session identity только из подписанного claim, с SHA-256 pseudonym;
- production profile принудительно использует JWT и отключает demo endpoint;
- `X-User-Id`, `X-Device-Id`, `X-Mock-*` изолированы в явном local/test filter-е и игнорируются в JWT mode;
- regression tests на 401/403, forged dev headers, role separation и security-context identity.

Mobile/session boundary — `CODE_COMPLETE`:

- Authorization Code + PKCE;
- короткоживущий access token и сериализованный refresh/session flow;
- refresh/session material только в Keychain / Android Keystore;
- login/logout, session expiry, account switch и lost-network сценарии;
- owner-scoped очистка read cache и command outbox;
- повтор pending-команд после refresh без изменения idempotency key;
- production build запрещает development identity mode.

До store build остаются внешние gates:

- выбрать и настроить production OIDC client и владение аккаунтом;
- включить стандартный `auth_time` в подписанный access token и проверить
  server-side окно свежей аутентификации;
- проверить login/refresh/logout/reinstall/upgrade на физических устройствах;
- зафиксировать provider-side revocation и account-deletion policy.

### A3. Account settings и удаление данных

Account data controls — `CODE_COMPLETE`:

- экран настроек аккаунта;
- JSON export через системный share sheet без постоянной staging-копии;
- два подтверждения удаления и fresh OIDC login той же identity;
- `prompt=login` + `max_age=0` и server-side проверка подписанного `auth_time`;
- idempotent deletion request и durable receipt;
- очистка local command store, read cache и secure session только после
  подтверждённого удаления backend-ом;
- обработка partial failure, повтор запроса и stale-token `410`.

До submission остаётся:

- подготовить публичную web-страницу / форму запроса удаления для Google Play;
- указать support contact для пользователя, потерявшего доступ к приложению;
- production IdP decision: удаление внешней учётной записи или документированное
  отсутствие аккаунта, принадлежащего Walking RPG.

### A4. Production configuration и backend operations

#### A4a. Profile/provider isolation — `CODE_COMPLETE`

- явное разделение development `local`/`test` и protected `stage`/`prod`;
- запрет смешанного profile set и fail-closed проверка JWT/demo settings;
- обязательная явная PostgreSQL configuration с verified TLS в protected
  profile;
- sandbox payment и development push доступны только при explicit opt-in в
  `local`/`test`;
- disabled providers в `stage`/`prod`, отказ до новой state mutation;
- Flyway V12 выключает sandbox-payment/background-health flags во всех
  существующих remote-config snapshots;
- backend маскирует sandbox capability при disabled provider;
- mobile скрывает purchase action в release build, при effective `false` и для
  cached snapshot.

#### A4b. Operations hardening — `CODE_COMPLETE`

- release API base URL проверяется как TLS-only, а cleartext остаётся только в
  debug host configuration;
- anonymous diagnostics/telemetry имеют проверяемые per-process
  client/global rate, body и DTO limits; reject не пишет state;
- liveness/readiness разделены, Prometheus защищён, а management listener
  `stage`/`prod` по умолчанию привязан к loopback;
- HTTP/database/shutdown timeouts закреплены protected-profile guard;
- synthetic PostgreSQL 17 backup/restore pack проверяет archive checksum и
  exact schema/data/sequence round-trip без production data или secret;
- operational runbook фиксирует безопасный rollback backend/content/config,
  incidents и восстановление без публикации новой mobile-версии;
- durable result handoff активируется только после drain старых backend
  instances; rollback сначала выключает activation gate и дренирует pending
  receipts до нуля.

Эти controls являются code-level defense in depth. Per-process limiter не
является WAF или distributed quota; synthetic restore не является production
restore evidence.

#### A4 external gates — `EXTERNAL_VALIDATION_REQUIRED`

- secrets только из фактического protected environment / secret store;
- production database, least-privilege role и реальный TLS endpoint;
- production remote config и content release;
- deployment, management network isolation, WAF/distributed abuse policy,
  monitoring/alerting и rollback drill;
- backup scheduling/encryption/retention, PITR/RPO/RTO policy и датированный
  restore реального backup в изолированной среде.

## 3. Gate B — физическая Health-валидация

Обязательная evidence-матрица:

- iPhone без Apple Watch;
- iPhone + Apple Watch;
- Android с Health Connect;
- несколько Android data providers;
- отказ и отзыв разрешения;
- ручной ввод, удаление и коррекция записи;
- переход через полночь и смена timezone;
- отсутствие двойного учёта между источниками;
- foreground/resume fallback;
- airplane mode / кратковременная потеря сети;
- расход батареи и длительность sync;
- upgrade приложения без потери command/read stores.

Любой найденный дефект закрывается отдельным PR и повторной проверкой затронутых устройств. Результат фиксируется в `docs/evidence/` с датой, версией build-а и моделью устройства.

## 4. Gate C — developer accounts, signing и требования SDK

### Apple

До загрузки первого build-а:

- активный Apple Developer Program account;
- App Store Connect app record;
- окончательный Bundle ID;
- сборка Xcode 26 или новее с iOS 26 SDK или новее;
- HealthKit capability и корректные entitlements;
- Distribution certificate / App Store provisioning profile в protected environment;
- production archive и upload в TestFlight;
- проверка version/build-number policy;
- App Review contact и reviewer flow.

### Google Play

До production submission:

- верифицированный Play Console account и app record;
- окончательный `applicationId`;
- явная проверка, что release candidate target-ит Android 16 / API 36;
- Play App Signing;
- защищённый upload key вне репозитория;
- подписанный production AAB;
- проверка install / update / uninstall на нескольких API/ABI.

Для personal Play Console account, созданного после 13 ноября 2023 года, заранее заложить closed-test gate: не менее 12 opted-in тестировщиков в течение минимум 14 дней перед запросом production access. Для organization account этот специальный gate обычно не применяется, но verification account-а всё равно обязателен.

## 5. Gate D — privacy, health и store declarations

- опубликовать постоянную Privacy Policy по публичному HTTPS URL;
- показать ссылку на Privacy Policy внутри приложения;
- указать юридическое наименование оператора, адрес, email и сроки хранения;
- Apple App Privacy questionnaire;
- Google Data Safety form;
- Apple HealthKit review notes с точным описанием чтения шагов;
- Google Health Apps / Health Connect declarations только для фактически используемых permission-ов;
- подтвердить отсутствие рекламы, профилирования и таргетинга по health data;
- account deletion URL для Google Play;
- age-rating questionnaires;
- export compliance;
- content rights;
- support URL и support email;
- regional compliance fields, которые потребует выбранная география распространения.

Декларации должны совпадать с фактическим кодом, SDK dependencies, backend retention и privacy policy. Добавление нового analytics/crash/push/payment SDK требует повторного аудита деклараций.

## 6. Gate E — карточки приложений

Подготовить и проверить:

- финальное название;
- App Store subtitle и Google Play short description;
- полное описание и ключевые слова;
- category / tags;
- финальные app icon и Android adaptive icon;
- iPhone / iPad / Android phone screenshots нужных размеров;
- feature graphic Google Play;
- privacy / support / deletion URLs;
- review notes;
- тестовый аккаунт или воспроизводимый reviewer flow;
- первая волна локализаций;
- отсутствие обещаний функций, отключённых в production remote config.

## 7. Gate F — beta

### TestFlight

- internal testing;
- external testing после Beta App Review;
- проверка чистой установки и upgrade поверх предыдущего build-а;
- проверка HealthKit permission flow;
- сбор crash/feedback и release-blocking issues.

### Google Play

- internal testing;
- closed testing;
- выполнение 12-testers / 14-days gate, если он применим к типу и возрасту account-а;
- проверка install/update/uninstall;
- проверка Health Connect permission flow;
- pre-launch report и device compatibility review.

Минимальные критерии выхода из beta:

- нет release-blocking crash;
- успешно пройден непрерывный первый путь: permission, activity sync, первая
  ENERGY, выбор питомца, первый узел и событие;
- export/delete проходят end-to-end;
- подтверждена корректность шагов на device matrix;
- понятны support/privacy/deletion flows;
- rollback-процедура проверена;
- owner продукта подписал release checklist.

Целевой продуктовый gate проекта остаётся 50–500 фактических тестировщиков. Первая техническая store submission может начаться на меньшей контролируемой когорте, но публичный rollout не должен опережать подтверждение основных метрик и стабильности.

## 8. Gate G — submission и rollout

- финальный release checklist;
- release tag, notes, build metadata и SHA-256 digests;
- загрузка build-а;
- заполнение обязательной metadata и выбор конкретного build-а;
- отправка в review;
- ответы reviewer-ам и исправление замечаний;
- staged / phased rollout;
- мониторинг crash/error/latency после публикации;
- возможность остановить rollout;
- возможность откатить backend/content/remote config;
- post-release review через 24 часа, 72 часа и 7 дней.

## 9. Push и платежи

Они не должны блокировать первую публикацию, если одновременно выполнены условия:

- функции отключены production remote config;
- UI не предлагает неработающие действия;
- карточка приложения не обещает push/payment-функции;
- sandbox providers недоступны production-пользователю.

Если включаем их в первый релиз, дополнительно требуются:

- APNs / FCM credentials, token lifecycle и test-send на физических устройствах;
- store products;
- server-side purchase verification;
- restore purchases;
- refunds / cancellations / subscription lifecycle;
- отдельные декларации и review notes.

## 10. Рекомендуемая последовательность PR

1. `offline read cache`;
2. `production identity/authentication boundary`;
3. `account settings + export/delete UI + local cleanup`;
4. `production environment/config/operations hardening`;
5. `target API 36 + production signing scaffolding`;
6. `device-validation fixes`;
7. `store metadata/declarations pack`;
8. `signed TestFlight / Play internal and closed-beta candidates`;
9. `submission fixes`.

Пункты 1–3 и A4a–A4b имеют автономную реализацию в коде. Для пункта 3 до загрузки
в магазины остаются end-to-end проверка с production IdP и решение о судьбе
внешней identity-provider учётной записи. A4b не закрывает и не валидирует
никакой A4 external gate.

Параллельно с PR 2–5 владелец продукта должен начать создание и верификацию developer accounts, подготовку публичных URL и набор beta-тестировщиков: эти процессы имеют внешнее время ожидания и не ускоряются кодом.

## 11. Definition of ready to upload

Build можно загружать в магазины, когда одновременно выполнены:

- standard CI и Release quality зелёные;
- production signing настроен вне репозитория;
- target API / Apple SDK соответствуют действующим требованиям;
- privacy, support и deletion URL опубликованы;
- App Privacy, Data Safety и Health declarations подготовлены;
- production authentication и logout/session-expiry работают end-to-end;
- account deletion работает end-to-end;
- physical Health matrix пройдена;
- TestFlight / Play internal candidate не имеет release-blocking дефектов;
- production backend, monitoring, backup и rollback готовы;
- владелец продукта подписал release checklist.

## 12. Definition of ready to publish

Публичный rollout разрешён только после того, как:

- соответствующий store review пройден;
- обязательный closed-testing gate Google Play выполнен, если применим;
- beta feedback разобран;
- release-blocking issues отсутствуют;
- staged/phased rollout и мониторинг подготовлены;
- owner продукта отдельно подтвердил публикацию.
