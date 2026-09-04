# Forward roadmap: от alpha baseline к устойчивому релизу

Этот документ задаёт порядок дальнейшей разработки Step Beyond / «Шаг за
пределы» после завершения автономного code-only roadmap. Выполненные
инженерные milestones остаются в [историческом roadmap](ROADMAP.md), а здесь
фиксируются только будущие этапы, зависимости и доказательства перехода между
ними.

Roadmap не является календарным обещанием. Этап начинается после exit gate
предыдущего этапа, а дата появляется только вместе с владельцем, ресурсами и
подтверждённым окружением.

## Точка старта

Текущий software baseline уже содержит:

- сквозной цикл «шаги → ENERGY → экспедиция → событие → награды → развитие»;
- повторяемые походы, первую главу, server-authoritative economy, inventory,
  crafting, equipment, progression и durable history;
- пилота и три канонических спутника: Искра, Мох и Навигатор;
- RU/EN, accessibility, compact layouts и light/dark presentation;
- HealthKit/Health Connect adapters, durable mobile commands и offline reads;
- OIDC, account export/delete, provider isolation, telemetry и release
  contracts;
- automated backend/mobile/host/release-quality checks и unsigned/no-codesign
  release candidates.

Это `CODE_COMPLETE` baseline, но не доказательство работы на физических
устройствах, реального stage, production identity, подписанной сборки,
магазинной публикации или пользовательской ценности.

Точная текущая engineering-кандидатура зафиксирована в
[`alpha-rc3` release dossier](evidence/alpha-rc3-release-dossier.md):
post-merge anchor, artifact source, одно exact tree, успешные CI/Release
quality runs и независимо проверенные unsigned/no-codesign artifacts.
Предыдущие candidate dossiers остаются неизменяемой историей.

## Статусы и правила перехода

- `CODE_COMPLETE` — код и документация прошли protected CI.
- `OWNER_ACTION_REQUIRED` — нужен выбор, аккаунт, credential, бюджет или
  approval владельца продукта.
- `EXTERNAL_VALIDATION_REQUIRED` — нужен физический девайс, реальный provider,
  deployment, магазин или пользовательская когорта.
- `PRODUCT_DECISION_REQUIRED` — продолжение зависит от измерений или
  исследования, а не от предположения разработчика.
- `VALIDATED` — существует датированное evidence с exact build/source,
  окружением, устройством/когортой, сценарием и результатом.

Общие правила:

1. Не переносить внешний gate в `VALIDATED` по результату unit/widget/CI.
2. Один независимый issue и PR на один bounded outcome от актуального
   `master`; runtime, infrastructure, design assets и roadmap не смешивать без
   явной причины.
3. Любой новый player-facing slice сохраняет RU/EN, accessibility, compact
   large-text coverage, literal future-content fallback и server-authoritative
   границы.
4. Экономика, rewards, eligibility и immutable history не вычисляются mobile.
5. Новая крупная механика или массовое производство контента начинается
   только из alpha/beta finding с владельцем и измеримым ожидаемым эффектом.
6. Подписание, публикация, платные ресурсы и production credentials требуют
   отдельного owner approval.

## Карта этапов

| Этап | Результат | Главный gate |
|---|---|---|
| F0. Baseline и управление | Один exact alpha baseline и очищенный backlog | Approved SHA/tree и владельцы внешних работ |
| F1. Physical activity validation | Доказанная работа Health на поддерживаемых устройствах | Device evidence по обязательной матрице |
| F2. Identity и account lifecycle | Реальный RU/EN вход и полный lifecycle аккаунта | Physical end-to-end evidence |
| F3. Protected stage и operations | Воспроизводимый stage, monitoring, backup и rollback | Deployment/restore/incident evidence |
| F4. Product и visual readiness | Проверяемый discovery-first первый путь | Approved direction и test-ready build |
| F5. Internal alpha | Проверена понятность и техническая устойчивость ядра | Expand/fix/stop решение по данным |
| F6. Closed beta | Проверены retention, activity effect и масштабирование | Beta go/no-go и закрытые blockers |
| F7. Store candidate и soft launch | Подписанный, проверенный и публикуемый продукт | Store approval и staged rollout gate |
| F8. Live operations | Управляемый контент, сезоны и безопасные эксперименты | SLO, cohort metrics и rollback discipline |

Зависимости и допустимая параллельность:

- F1 начинается сразу после F0 и формирует реальную platform-risk baseline;
- F2 и F3 можно вести параллельно разными владельцами после F0;
- подготовка F4 может идти параллельно F1–F3, но test-ready build фиксируется
  только после закрытия найденных release blockers;
- F5 требует exit gates F1–F4;
- F6 начинается только после alpha expand decision;
- F7 требует beta go и не может быть заменён одним успешным store build;
- F8 начинается после staged production rollout и operational handoff.

## F0. Exact baseline и управление работой

Цель — остановить бесконечное добавление мелких code-only milestones и
зафиксировать точку, которую действительно проверяют внешние этапы.

Текущий F0 baseline — `alpha-rc3`. Его dossier закрывает code/evidence часть
этапа; переход к F1–F5 по-прежнему зависит от внешних владельцев, окружений,
устройств и product decisions и не считается `VALIDATED` заранее.

Реализация:

- завершить текущий независимый PR и выбрать post-merge `master` SHA/tree;
- обновить alpha release dossier и связать exact CI/release artifacts;
- разделить backlog на `release blocker`, `validation`, `finding`, `later`;
- назначить владельцев устройств, Auth0, stage/operations, signing/store и
  alpha research;
- сохранить feature freeze для новых крупных mechanics до результата F5;
- разрешать автономные PR только для воспроизводимого blocker, evidence
  tooling gap или заранее утверждённого alpha-preparation outcome.

Exit gate:

- один approved baseline без открытого runtime PR;
- standard CI и Release quality зелёные на exact source;
- у каждого F1–F5 workstream есть владелец, входные данные и evidence template;
- ни один внешний gate не отмечен выполненным заранее.

## F1. Physical Health validation

Цель — доказать, что модель «сначала ходи, потом играй» работает с реальными
источниками шагов и не теряет/не удваивает активность.

Реализация:

- инвентаризировать устройства, OS и providers ([#149](https://github.com/MKSEgr/walking-rpg/issues/149));
- пройти HealthKit/Health Connect protocol ([#21](https://github.com/MKSEgr/walking-rpg/issues/21)) на:
  - iPhone без Apple Watch;
  - iPhone с Apple Watch;
  - Android с поддерживаемыми Health Connect providers;
- проверить first grant, denial, permanent denial, revoke и повторный grant;
- проверить ручную запись, исправление/удаление источником, несколько
  синхронизаций, offline → online и restart;
- проверить timezone, локальную полночь и переход между днями;
- измерить battery impact и фактическое foreground/resume поведение, не
  обещая гарантированный background delivery;
- сохранить redacted evidence из Validation Center с checksum и exact build.

Exit gate:

- обязательная device matrix имеет датированное evidence;
- нет двойного начисления или потери accepted activity в обязательных
  сценариях;
- критические findings закрыты regression tests либо явно блокируют F2/F5;
- поддерживаемые OS/provider границы отражены в UI, support и store copy.

## F2. Production-like identity и account lifecycle

Цель — заменить secret-free contract реальной защищённой конфигурацией и
проверить жизненный цикл одной identity на физических устройствах.

Реализация:

- создать protected Auth0 tenant/application/API и настроить issuer, audience,
  redirects, email OTP, Apple/Google connections;
- завершить Telegram login через Auth0 ([#175](https://github.com/MKSEgr/walking-rpg/issues/175)) только после bot/callback/credential setup;
- проверить RU/EN login, cancel, retry и reauthentication;
- проверить access expiry, refresh, revoke, logout, restart и account switch;
- проверить signed `device_id`/`auth_time`, owner-scoped cache/outbox cleanup;
- пройти export и destructive deletion end-to-end на production-like аккаунте;
- выполнить physical lifecycle validation ([#153](https://github.com/MKSEgr/walking-rpg/issues/153)) без token/PII в evidence.

Exit gate:

- login/refresh/revoke/logout/switch проходят на iOS и Android;
- stale/wrong-owner destructive actions fail closed;
- export/delete и external-IdP deletion policy согласованы и опубликованы;
- secrets находятся только в protected environment.

## F3. Protected stage и operational readiness

Цель — получить среду, в которой можно безопасно проводить alpha, миграции и
recovery drills.

Реализация:

- развернуть protected production-like stage ([#151](https://github.com/MKSEgr/walking-rpg/issues/151)) из immutable image digest и проверить его fail-closed [deployment evidence contract](DIGITALOCEAN_STAGE_RUNBOOK.md), не принимающий repository CI за внешний deployment;
- настроить managed PostgreSQL, verify-full TLS, least-privilege role и
  protected secret delivery;
- проверить `/livez`, `/readyz`, private management/metrics, WAF/rate limits,
  redaction, alerting и log retention;
- выполнить датированный restore фактического backup в isolation ([#154](https://github.com/MKSEgr/walking-rpg/issues/154));
- утвердить scheduling, encryption, retention, PITR и RPO/RTO;
- провести deployment rollback и incident rehearsal ([#155](https://github.com/MKSEgr/walking-rpg/issues/155));
- прогнать supported upgrade path и content activation/drain runbooks;
- зафиксировать cost ceiling и процедуру остановки платного stage.

Exit gate:

- exact source/image/deployment receipt согласованы;
- monitoring видит controlled failure, а public ingress не видит management;
- restore и rollback уложились в утверждённые recovery targets;
- назначены incident, database и deployment owners.

## F4. Product и visual readiness первого пути

Цель — подготовить не просто технически рабочую сборку, а понятную walking-RPG
про исследование мира и связь со спутником, а не экран fitness-метрик.

Реализация:

- утвердить visual direction первого мира и питомцев ([#156](https://github.com/MKSEgr/walking-rpg/issues/156));
  физические снимки и owner decision фиксируются через fail-closed
  [`visual-direction-template.json`](evidence/visual-direction-template.json), а
  пустой шаблон или CI-render не считаются evidence;
- проверить целиком путь: вход → разрешение шагов → ENERGY → спутник → узел →
  событие → решение → награда → развитие;
- провести accessibility audit RU/EN, screen reader, reduced motion, contrast,
  compact large text и отсутствие color-only state;
- измерить startup, Home/journal responsiveness, memory и crash-free baseline;
- проверить, что мир/route и спутник визуально важнее числовых метрик;
- принять отдельное решение по motion и audio scope;
- дорисовывать остальные event/item scenes только после approval направления
  и только для контента, входящего в alpha/beta test plan;
- не добавлять GPS, real-time walking gameplay, PvP или большую social system.

Exit gate:

- approved visual/product direction записана как decision;
- test-ready first journey не требует объяснения разработчика;
- critical accessibility/performance blockers закрыты;
- alpha protocol может ссылаться на один стабильный build и неизменный flow.

## F5. Internal alpha

Цель — получить первые реальные данные о понятности, надёжности и ценности
ядра до расширения контента и аудитории.

Реализация:

- проводить alpha по [versioned internal-alpha protocol](INTERNAL_ALPHA_PROTOCOL.md):
  cohort, consent, first-ten-minutes script, support, thresholds, stop authority
  и evidence policy остаются фиксированными для candidate
  ([#157](https://github.com/MKSEgr/walking-rpg/issues/157));
- проверить developer accounts, application IDs и public URLs ([#152](https://github.com/MKSEgr/walking-rpg/issues/152));
- создать protected signed internal candidates ([#158](https://github.com/MKSEgr/walking-rpg/issues/158));
- проверить install, first launch, upgrade и rollback на internal tracks ([#160](https://github.com/MKSEgr/walking-rpg/issues/160)) по fail-closed [internal-track evidence contract](INTERNAL_TRACK_VALIDATION.md), не принимающему CI за physical run;
- провести first-journey study ([#161](https://github.com/MKSEgr/walking-rpg/issues/161));
- измерить permission funnel, first ENERGY, first decision, first reward,
  time-to-value, errors, battery и qualitative comprehension;
- разделить findings на `stop`, `fix before expand`, `experiment`, `later`;
- записать решение expand/fix/stop ([#162](https://github.com/MKSEgr/walking-rpg/issues/162)).

Exit gate:

- все stop-condition incidents расследованы;
- analytics coverage позволяет делать выводы, а не только собирать события;
- подтверждено, что прогулка ощущается частью приключения, а спутник мотивирует
  вернуться;
- владелец продукта подписал одно из решений: expand, focused fix cycle, stop.

## F6. Closed beta

Цель — проверить удержание, изменение активности, экономику и эксплуатацию на
расширенной, но контролируемой аудитории.

Реализация:

- расширять cohort ступенчато до диапазона, определённого alpha decision;
- повторять signed-track install/upgrade/rollback при каждом изменении
  application identity, migration boundary или distribution channel;
- измерять onboarding completion, D1/D7/D30, Meaningful Active Week,
  first-journey и compass funnel quality;
- сравнить activity effect без streak pressure и наказания за отдых;
- откалибровать ENERGY/rewards/progression только server-side и только по
  согласованным данным;
- проверить fraud/risk operations, support load, deletion SLA, crash-free,
  latency, battery и provider-specific failures;
- выпускать новые event/content slices только для проверяемой beta hypothesis;
- повторить privacy, security и accessibility review перед расширением.

Exit gate:

- нет открытых P0/P1 release blockers;
- retention/activity/economy выводы имеют достаточную instrumentation rate;
- support, incident response и rollback выдерживают beta load;
- принято go/no-go решение для store candidate.

## F7. Store candidate и soft launch

Цель — превратить validated beta build в подписанный, проверенный и безопасно
публикуемый продукт.

Реализация:

- завершить store metadata, declarations и launch assets ([#159](https://github.com/MKSEgr/walking-rpg/issues/159));
- опубликовать privacy, support и account-deletion URLs;
- собрать Android/iOS artifacts в protected signing environment;
- проверить signatures, entitlements, Health declarations, Data Safety/App
  Privacy и bundle metadata;
- подключать APNs/FCM и store billing только если они входят в approved launch
  scope; иначе оставить capabilities выключенными и не обещать их в listing;
- пройти TestFlight/Play internal → closed → staged production tracks;
- подготовить support, incident, rollback и store-review response owners;
- начать staged rollout с заранее заданными health metrics и stop thresholds.

Exit gate:

- store review пройден без расхождения с фактическими permissions/data flows;
- production identity, deletion, monitoring и rollback проверены;
- signed artifacts связаны с approved source SHA/tree и evidence;
- владелец отдельно одобрил публикацию и размер первой rollout cohort.

## F8. Live operations и следующий product cycle

Цель — развивать игру по данным, сохраняя доверие, простоту и управляемость.

Реализация:

- утвердить SLO, on-call/incident cadence и release train;
- выпускать seasons, weekly routes и content packs через versioned activation;
- поддерживать economy simulation, audit и rollback перед balance changes;
- развивать оставшиеся иллюстрации, motion/audio, social и squads только из
  validated demand;
- проверять монетизацию малыми прозрачными экспериментами без pay-to-win;
- пересматривать anti-fraud меры по реальным abuse patterns;
- вести RU/EN parity, accessibility regression и privacy review в каждом
  release;
- ежеквартально пересобирать roadmap из metrics, findings, costs и capacity.

Exit gate первого live cycle:

- соблюдены SLO и rollback discipline;
- контент можно выпускать без client-owned economy/content rules;
- продуктовые изменения улучшают заранее выбранную metric без критического
  ухудшения wellbeing, retention quality или trust;
- следующий roadmap утверждён как отдельный набор outcomes, а не список
  функций без проверяемой цели.

## Приоритет ближайших действий

1. Закрыть текущий runtime PR и зафиксировать exact F0 baseline.
2. Выполнить device inventory #149.
3. Провести physical Health validation #21.
4. Назначить owner и бюджет protected Auth0/stage workstreams.
5. Поднять production-like identity и пройти #153; Telegram #175 вести как
   отдельный provider outcome.
6. Развернуть stage #151 и выполнить restore/incident drills #154/#155.
7. Утвердить visual direction #156 и заморозить test-ready first journey.
8. Утвердить alpha protocol #157, проверить accounts/IDs #152 и создать signed
   candidates #158 с distribution validation #160.
9. Провести study #161 и зафиксировать expand/fix/stop decision #162.
10. Только после alpha decision планировать closed-beta content и store scope.

## Управление изменениями roadmap

- Новый пункт должен описывать outcome, owner, evidence и exit gate.
- Любая смена порядка фиксирует зависимость или новый риск, который её
  обосновывает.
- Закрытый issue не равен завершённому этапу, если отсутствует обязательное
  external evidence.
- Исторические результаты не удаляются: выполненные code milestones остаются
  в `ROADMAP.md`, а решения и компромиссы — в ADR.
- Этот документ обновляется после alpha/beta go/no-go, изменения launch scope
  или появления подтверждённого blocker; косметическая перенумерация сама по
  себе не является roadmap progress.
