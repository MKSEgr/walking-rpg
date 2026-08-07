# Walking RPG: текущее состояние проекта

Стратегическая оценка готовности к alpha и closed beta: разрывы, критический
путь и план дальнейших действий.

| Поле | Значение |
|---|---|
| Репозиторий | `MKSEgr/walking-rpg` |
| Снимок | `master@6708dec1f4599a937b343a1992e7c68f604d17a0` |
| Дата анализа | 7 августа 2026 |
| Назначение | Основа для декомпозиции на эпики, задачи и evidence-gates |

Операционный слой: [validation backlog](VALIDATION_BACKLOG.md) и
[prompt «следующая задача → PR»](NEXT_TASK_TO_PR_PROMPT.md).

> [!IMPORTANT]
> **Главный вывод.** Проект уже вышел из фазы разработки MVP. Автономный
> программный scope roadmap реализован; текущая стадия — технически готовый
> alpha-кандидат перед внешней валидацией. Следующая ценность создаётся не
> новыми механиками, а доказательствами на физических устройствах и реальных
> пользователях, production-конфигурацией и подготовкой закрытой beta.

## Краткое резюме

- Сквозной игровой цикл работает: шаги → ENERGY → питомец → 18 узлов первой главы → события → материалы → crafting → equipment → опциональный resonance route → durable result/ACK.

- Архитектура и экономика server-authoritative; state-changing команды идемпотентны, сериализованы и восстанавливаются через durable mobile outbox.

- Все Milestone 0–13 имеют завершённый программный scope. В roadmap осталось 36 незакрытых пунктов, и все они относятся к external/product validation, production credentials, устройствам, beta или магазинам — не к обычной автономной разработке.

- Открытых PR нет. Открыто три issue: #21 остаётся актуальным; #26 фактически выполнен; #29 исчерпал автономный scope и требует закрытия либо преобразования в validation epic.

- Последний exact-head набор проверок для PR #146 зелёный: CI #576, Release quality #457 и finalizer #346. Перед alpha-фиксацией нужен отдельный release dossier для объединённого master SHA.

- Рекомендуется ввести feature freeze для широких продуктовых и визуальных расширений до первых alpha-данных. Допустимы только release blockers, device fixes, production wiring и улучшения, подтверждённые наблюдением пользователей.

## 1. Объём и метод анализа

Анализ выполнен по текущему master, актуальному состоянию PR/issues, истории последних объединений, CI/release workflow и основным проектным документам. Это не аудит каждой строки кода и не security pentest; это оценка зрелости продукта и поставки для принятия следующего управленческого решения.

**Использованные классы evidence:**

- реализованный продуктовый цикл и границы из README / PROJECT_VISION;

- статусы Milestone 0–13 и 36 внешних пунктов из ROADMAP;

- архитектурные инварианты, модули и release model;

- store, device, closed-beta и operations протоколы;

- live-состояние GitHub: master, PR, issues и exact-head Actions;

- последние design/backend срезы и их изоляция.

> [!NOTE]
> **Граница статуса.** `CODE_COMPLETE` означает «реализовано и проверяется
> автоматикой». `VALIDATED` означает «есть датированное evidence с устройства,
> production-like окружения, магазина или реальной когорты». Эти статусы нельзя
> взаимозаменять.

## 2. Что уже построено

Walking RPG сейчас — не прототип одного API, а связный modular-monolith продукт с мобильным клиентом, server-authoritative экономикой и первой полноценной главой. Техническая глубина заметно выше уровня рыночной валидации: система хорошо защищает корректность, но ещё почти не доказала пользовательскую ценность вне CI.

| **Область**      | **Фактическое состояние**                                               | **Оценка**                                                |
|------------------|-------------------------------------------------------------------------|-----------------------------------------------------------|
| Core loop        | Шаги, персональная цель, ENERGY, питомец, экспедиция, события, награды  | CODE_COMPLETE                                             |
| Контент          | chapter-1-v2: 18 основных узлов + optional resonance-pocket             | CODE_COMPLETE                                             |
| Прогресс         | Pilot XP, pet bond/evolution, inventory, crafting, equipment            | CODE_COMPLETE                                             |
| Надёжность       | Idempotency, ledger, locks, durable receipts, outbox, read-only cache   | CODE_COMPLETE                                             |
| Identity/privacy | OIDC/JWT boundary, export/delete, owner-scoped cleanup                  | Код готов; production wiring не пройден                   |
| Release          | Backend JAR, unsigned AAB, iOS no-codesign, metadata, restore rehearsal | Кандидаты воспроизводимы; signing/store не пройдены       |
| Analytics        | First-journey, retention, compass funnels, risk shadow mode             | Инструменты готовы; реальных cohort-данных нет            |
| Дизайн           | Light/dark foundation, route/event/pet signals, adaptive navigation     | Система готова; art direction и usability не валидированы |

### Архитектурная зрелость

- Монорепозиторий, Flutter, Java 21 / Spring Boot, PostgreSQL / Flyway, modular monolith.

- Server-authoritative economy/content/progression; клиент не рассчитывает награды и не меняет баланс оптимистично.

- ACTIVITY → GAMEPLAY ordering и отдельная TELEMETRY lane снижают риск блокировки игрового состояния.

- Repeatable-read read models, append-only ledgers и exact replay дают сильную основу для разбора инцидентов.

- Production providers и sandbox/dev providers разведены fail-closed; release CI не хранит signing material.

## 3. На каком этапе находится проект

> [!IMPORTANT]
> **Текущая стадия:** code-complete technical alpha candidate / pre-closed-beta
> validation. Это уже больше, чем MVP implementation, но ещё меньше, чем
> beta-ready и существенно меньше, чем production-ready.

| **Группа Milestone**                      | **Программный статус** | **Что удерживает переход**                                    |
|-------------------------------------------|------------------------|---------------------------------------------------------------|
| 0\. Repository baseline                   | Завершён               | Нет программного blocker                                      |
| 1\. Health API                            | Завершён               | Физические iPhone/Watch/Android, timezone, battery evidence   |
| 2–4. Vertical slice / playable / MVP loop | Завершён               | Нужно доказать понятность и ценность цикла                    |
| 5–6. Closed beta / soft launch tech       | Завершён               | IdP, push/billing decision, real testers, signing             |
| 7\. Alpha first journey                   | Завершён               | Чистая установка, 10 минут, реальные TTF metrics и интервью   |
| 8–9. Operations / store packaging         | Code-level завершён    | Deployment, secrets, monitoring, restore, developer accounts  |
| 10–11. Crafting / equipment route         | Завершён               | Beta usability и balance validation                           |
| 12\. Visual foundation                    | Завершён               | Art direction, accessibility on devices, motion/store assets  |
| 13\. Compass funnel                       | Завершён               | Реальная cohort, instrumentation coverage и product decisions |

### Почему это важно

Главный риск теперь не «система потеряет начисление» — этот класс рисков хорошо покрыт архитектурой. Главный риск — пользователь не поймёт, зачем возвращаться, не доверит доступ к шагам, не почувствует связь прогулки с RPG или застрянет в первом 10-минутном пути. Эти вопросы нельзя закрыть очередным PR без наблюдения и evidence.

## 4. Качество и release baseline

Последние design и backend изменения объединены в master. На exact PR head #146 подтверждены CI #576, Release quality #457 и Release PR finalizer #346. Проверены Java 21 compile, unit/API/PostgreSQL, Flutter format/analyze/tests, Android debug, iOS simulator, backend package, unsigned Android AAB, iOS no-codesign, deterministic metadata и synthetic backup/restore.

- PR #145 добавил design-навигацию и прошёл полный mobile suite, включая 390 Flutter tests на своём exact head.

- PR #146 добавил exact integer request boundary и сообщил 442 backend unit/API tests плюс PostgreSQL integration на своём exact head.

- CI и Release quality настроены также на push в master, но alpha release dossier должен явно привязать итоговый run, SHA, tree и artifacts к одному объединённому master baseline.

- Synthetic signing/restore — проверка инструментов, а не evidence production signing или restore реального backup.

> [!IMPORTANT]
> **Release-решение.** Перед началом alpha следует объявить один `master` SHA
> как `alpha-rc1`, собрать из него интеграционный пакет и не продолжать
> параллельные feature-срезы без release-blocking причины.

## 5. Незакрытые разрывы и риски

| **Риск**                       | **Почему критичен**                                                                                 | **Нужная реакция**                                                       |
|--------------------------------|-----------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------|
| Health на реальных устройствах | CI не доказывает агрегацию телефона/часов, permission lifecycle и midnight/timezone                 | Выполнить issue #21 по матрице и приложить schema-v1 evidence           |
| Production identity            | Работоспособность PKCE/refresh/logout/delete зависит от реального IdP и signed claims               | Выбрать IdP, настроить client/redirect/claims, пройти physical E2E       |
| Production operations          | Нет фактического deployment, WAF, monitoring, dated restore и rollback drill                        | Развернуть stage/prod-like контур и закрыть ops evidence                 |
| Store access/signing           | Без developer accounts, финальных IDs и protected signing нельзя получить устанавливаемый candidate | Запустить Apple/Google процессы немедленно; они имеют внешнее ожидание   |
| Product comprehension          | Техническая полнота не доказывает, что RPG-цикл понятен и эмоционально ценен                        | Наблюдаемый first-journey alpha + интервью + продуктовые пороги          |
| Visual direction               | Система компонентов есть, но art direction питомцев/главы и store art не утверждены                 | Принять направление после physical capture и alpha feedback              |
| Beta analytics without data    | Funnel code не равен validated conversion                                                           | Собрать cohort/build/period evidence и проверить instrumentation rate    |
| Scope creep                    | Система уже шире доказанного core loop                                                              | Feature freeze; новые routes/recipes/push/payment только после evidence  |
| Backlog drift                  | Открытые #26/#29 описывают уже выполненный scope                                                   | Закрыть/переписать issues и сделать validation backlog источником истины |

### Что не должно блокировать первую публикацию

Production push и billing могут оставаться отключёнными, если capability и UI скрыты, store metadata не обещает эти функции, а sandbox providers недоступны production-пользователю. Их включение в первый релиз создаёт отдельный большой контур credentials, verification, restore purchases/refunds и деклараций; сейчас это не рекомендуется.

## 6. Состояние backlog

| **Item**   | **Фактическое состояние**                                                                              | **Рекомендация**                                                                |
|------------|--------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------|
| Issue #21 | Актуален: physical HealthKit / Health Connect validation                                               | Сделать P0 validation epic; расширить evidence, не закрывать кодом              |
| Issue #26 | Второй узел, событие и persistent inventory уже реализованы и расширены до 18 узлов/crafting/equipment | Закрыть как выполненный со ссылками на merged PR/roadmap                        |
| Issue #29 | Автономный software scope roadmap выполнен; внешние gates остаются                                     | Закрыть как software-complete или заменить на новый external validation program |
| Open PR    | 0                                                                                                      | Следующий PR — только release blocker или evidence/tooling gap                  |

> [!WARNING]
> **Управленческий дефект.** На момент снимка roadmap точнее GitHub Issues.
> Операционным источником истины должен стать один актуальный validation
> backlog, а roadmap — сводкой этапов.

## 7. Рекомендуемая стратегия

Стратегический переход: от «строить больше» к «доказывать готовность».

1.  Зафиксировать alpha-rc1 и ограничить изменения release blockers.

2.  Вести CODE_COMPLETE и VALIDATED раздельно во всех issue и отчетах.

3.  Запустить внешние процессы с длинным ожиданием сразу: developer accounts, IdP, public URLs, signing, tester recruitment.

4.  Параллелить три дорожки: devices, production environment, product validation.

5.  Собирать evidence как артефакт задачи: build/SHA, устройство/окружение, дата, результат, отклонения, решение.

6.  Не добавлять новые визуальные и gameplay-срезы без конкретного пользовательского сигнала или release blocker.

7.  После каждой alpha/beta волны принимать решение: исправить, расширить cohort, отложить функцию или остановить rollout.

### Критический путь

| **Шаг**                   | **Выход**                                                               | **Следующий gate**                                |
|---------------------------|-------------------------------------------------------------------------|---------------------------------------------------|
| 1\. Baseline              | alpha-rc1 SHA + green integrated release dossier                        | Можно начинать контролируемую physical validation |
| 2\. Devices + IdP + stage | Physical evidence, real auth, deployed observability/restore            | Можно собирать signed internal candidates         |
| 3\. Internal alpha        | 10-minute journey evidence, blockers closed, product thresholds adopted | Можно расширять cohort                            |
| 4\. Closed beta           | Stability, retention/funnel, support/rollback evidence                  | Можно готовить submission                         |
| 5\. Store                 | Signed build, declarations, review, staged rollout                      | Публичный запуск                                  |

## 8. Поэтапный план

### Фаза 0 — Reset и alpha baseline

Цель: остановить дрейф scope и создать один проверяемый стартовый кандидат.

- Закрыть или переоформить #26 и #29; сохранить #21 как активный device epic.

- Объявить feature freeze и разрешённые категории изменений.

- Зафиксировать alpha-rc1 на post-merge master: SHA, tree, CI, release artifacts, build metadata и changelog.

- Создать validation backlog с owner, dependency, evidence и status model.

- Принять обязательные продуктовые/операционные решения из раздела 11.

**Выход:** один воспроизводимый alpha baseline и чистый backlog.

### Фаза 1 — External readiness в трёх параллельных дорожках

**Дорожка A — устройства:**

- iPhone без Watch, iPhone + Watch, Android с одним и несколькими providers;

- permission deny/revoke, manual correction/delete, timezone/midnight, network/restart, upgrade;

- battery/runtime measurement и schema-v1 redacted evidence.

**Дорожка B — identity/operations:**

- production IdP client/redirect/issuer/audience/auth_time/device claim;

- stage/prod-like PostgreSQL TLS, least privilege, secrets, management isolation;

- monitoring/alerting, WAF/distributed limits, real backup restore и rollback drill.

**Дорожка C — product/store foundation:**

- финальные app IDs, developer accounts, distribution geography/language;

- public Privacy Policy, support и deletion URLs;

- art direction первого мира и трёх питомцев; beta cohort/support channel.

**Выход:** ready-to-build signed internal candidate.

### Фаза 2 — Internal alpha: первые 10 минут

- Чистая установка iOS и Android; наблюдение без подсказок разработчика.

- Проверка входа, разрешения шагов, sync, первой ENERGY, выбора питомца, узла, события и result ACK.

- Сбор authoritative time-to-first-ENERGY/node/event/ACK и crash/sync/retry evidence.

- Короткое интервью: что произошло, зачем гулять, что делать дальше, запомнился ли питомец.

- Исправление только подтверждённых blockers/major friction; повторный прогон затронутых сценариев.

**Выход:** core journey понятен, стабилен и имеет принятые alpha thresholds.

### Фаза 3 — Closed beta

- Signed TestFlight / Play internal/closed candidates из exact baseline.

- Ступенчатое расширение cohort с заранее зафиксированными stop conditions.

- D1/D7/D30, crash-free, sync error/retry, risk distribution, first-journey и compass funnel.

- Проверка instrumentation rate и причин drop-off через support/interview evidence.

- Проверка crafting → equip → resonance route и балансировки только на фактических прохождениях.

- Движение к целевым 50–500 фактическим тестировщикам; отдельный 12 testers / 14 days gate Google Play — если применим к account.

**Выход:** beta evidence подтверждает стабильность и ценность либо даёт список обязательных изменений.

### Фаза 4 — Store submission и staged rollout

- Финальные icons/screenshots/descriptions/declarations/review notes и reviewer flow.

- Production signing в protected environment, digest/provenance и owner approval.

- App Store / Google Play review, исправления отдельными PR/build numbers.

- Staged/phased rollout с возможностью остановки и backend/content/config rollback.

- Review после 24 часов, 72 часов и 7 дней.

**Выход:** контролируемая первая публикация.

## 9. Каталог эпиков для будущей нарезки

Ниже — уровень между стратегией и GitHub issue. Каждый эпик можно нарезать на независимые CODE, CONFIG, MANUAL_VALIDATION, PRODUCT_RESEARCH и STORE/EXTERNAL задачи, не смешивая разные типы доказательств в одном тикете.

### E0. Governance, backlog и alpha baseline

**Результат:** Есть один источник истины и один exact alpha-rc1.

**Включает:**

- закрытие/переформулировка #26 и #29;

- feature-freeze policy и правила исключений;

- post-merge master CI/release dossier;

- единая схема статусов CODE_COMPLETE / VALIDATED / BLOCKED.

**Зависимости:** нет

**Критерий выхода:** alpha-rc1 зафиксирован; backlog не содержит выполненных эпиков как открытых работ.

**Evidence:** SHA/tree, workflow runs, artifact digests, changelog, issue decisions.

### E1. Physical Health validation

**Результат:** Доказано корректное чтение и синхронизация шагов на заявленной device matrix.

**Включает:**

- issue #21 device/scenario matrix;

- permission lifecycle, phone/watch/providers, corrections, midnight/timezone;

- network/restart/upgrade и battery measurement;

- дефекты как отдельные issues и rerun affected matrix.

**Зависимости:** E0 alpha-rc1, доступ к устройствам

**Критерий выхода:** все обязательные сценарии имеют датированное pass evidence; blockers закрыты.

**Evidence:** redacted schema-v1 JSON, build/device metadata, result log, defect links.

### E2. Production identity и account lifecycle

**Результат:** Реальный OIDC и пользовательский lifecycle работают end-to-end на iOS/Android.

**Включает:**

- выбор IdP и конфигурация client/redirect/issuer/audience/scopes;

- signed auth_time и stable device claim;

- login/refresh/expiry/logout/reinstall/upgrade/account switch;

- export/delete, IdP account policy, public deletion/support flow.

**Зависимости:** E0, production domain/URLs, IdP owner

**Критерий выхода:** physical E2E пройден; stale tokens и local owner data очищаются по политике.

**Evidence:** IdP configuration record без secrets, physical test log, export/delete receipts.

### E3. Stage/production operations

**Результат:** Существует управляемое production-like окружение с наблюдаемостью и восстановлением.

**Включает:**

- PostgreSQL TLS и least-privilege role; secret delivery;

- deployment, management isolation, WAF/distributed limits;

- monitoring/alerting/log retention/redaction;

- real backup schedule, dated restore, PITR/RPO/RTO и rollback drill.

**Зависимости:** E0, hosting decision, protected environment

**Критерий выхода:** release owner может обнаружить сбой, остановить rollout и восстановить service/data по проверенному runbook.

**Evidence:** deployment record, dashboards/alerts, restore evidence, rollback timestamps.

### E4. Product и visual validation

**Результат:** Основной цикл читается как RPG, а визуальное направление первой главы и питомцев принято.

**Включает:**

- first-journey comprehension test;

- эмоциональная ценность выбора питомца;

- light/dark, large text, contrast на устройствах;

- решение по art direction, motion, app icon/splash/store artwork.

**Зависимости:** E0, частично E1, физические captures

**Критерий выхода:** есть решение owner-а и список подтверждённых UX changes, а не бесконечный polish queue.

**Evidence:** наблюдения, interview notes, captures, decision record.

### E5. Internal alpha first journey

**Результат:** Первые 10 минут проходят стабильно и без объяснений разработчика.

**Включает:**

- чистые установки iOS/Android;

- authoritative TTF ENERGY/node/event/ACK;

- crash/sync/recovery/support сценарии;

- alpha thresholds и stop conditions.

**Зависимости:** E1–E4 minimum ready state

**Критерий выхода:** нет release blocker; команда принимает expand/fix/stop решение по evidence.

**Evidence:** cohort/build/period, analytics snapshot, interview notes, issue outcomes.

### E6. Closed beta и product analytics

**Результат:** Реальная cohort подтверждает стабильность, retention и ключевые funnel-ы.

**Включает:**

- ступенчатый cohort rollout и support process;

- D1/D7/D30, crash-free, sync/error, risk false-positive review;

- first-journey и compass funnel с instrumentation quality;

- craft/equip/resonance route usability и economy review.

**Зависимости:** E5, signed candidates, E3 operations

**Критерий выхода:** приняты beta thresholds и отсутствуют stop conditions; решение о public rollout документировано.

**Evidence:** analytics JSON/snapshots, cohort registry, incidents, interview/support evidence.

### E7. Store accounts, compliance и signed packaging

**Результат:** Есть устанавливаемые signed candidates и полный store metadata/declarations pack.

**Включает:**

- Apple/Google accounts и app records; финальные IDs;

- protected signing, provisioning, Play App Signing;

- Privacy Policy, support/deletion URLs, App Privacy/Data Safety/Health declarations;

- icons, screenshots, descriptions, reviewer flow и localization decision.

**Зависимости:** E2, E3, E4; внешнее время verification

**Критерий выхода:** Definition of ready to upload из STORE_LAUNCH_PLAN выполнен и подписан owner-ом.

**Evidence:** signed artifact provenance, store forms/URLs, install/upgrade evidence.

### E8. Submission, review и rollout

**Результат:** Приложение прошло review и выкатывается контролируемо.

**Включает:**

- submission и ответы reviewer-ам;

- исправления с новым build number;

- staged/phased rollout и stop/rollback authority;

- 24h/72h/7d post-release review.

**Зависимости:** E6 и E7

**Критерий выхода:** store review пройден, rollout наблюдаем, release owner подтвердил публикацию.

**Evidence:** store status, release checklist, dashboards/incidents, post-release notes.

### E9. Post-beta feature queue

**Результат:** Новые функции добавляются только по доказанному product signal.

**Включает:**

- visual route map только из authoritative topology/read model;

- дополнительные event scenes после валидации core illustrated loop;

- journal tabs только при доказанной content-density проблеме;

- новые recipes/routes, blocking anti-fraud, push и billing — отдельные решения после beta.

**Зависимости:** E6 product evidence

**Критерий выхода:** каждая новая ставка имеет проблему, метрику, expected outcome и kill criterion.

**Evidence:** product decision record и experiment/rollout plan.

## 10. Приоритеты и параллельность

| **Приоритет**                | **Эпики**      | **Правило**                                          |
|------------------------------|----------------|------------------------------------------------------|
| P0 — начать сейчас           | E0, E1, E2, E3 | Baseline и внешние процессы с длинным ожиданием      |
| P1 — после minimum readiness | E4, E5         | Физическая alpha и продуктовая понятность            |
| P2 — после alpha gate        | E6, E7         | Closed beta и store candidate могут идти параллельно |
| P3 — после beta decision     | E8             | Submission только при подписанном go                 |
| Deferred                     | E9             | Не превращать в текущий backlog без evidence         |

### Допустимая параллельность

- Device validation, IdP configuration, stage operations и developer-account verification можно вести параллельно.

- Design и backend code по-прежнему изолируются по путям/контрактам, но только когда изменение привязано к release blocker или alpha finding.

- Store metadata/assets можно готовить параллельно, но финализировать только после принятого visual direction и physical captures.

- Push/payment не следует открывать параллельной дорожкой до отдельного go/no-go.

## 11. Решения, которые нужны от владельца продукта

| **Решение**                        | **Почему сейчас**                                    | **Рекомендуемый default**                                           |
|------------------------------------|------------------------------------------------------|---------------------------------------------------------------------|
| Рабочее название и главная эмоция  | Определяет store identity, copy и art direction      | Зафиксировать для alpha; допускается change до public launch        |
| Art direction главы и 3 pets       | Нужно для physical captures и store assets           | Один direction, без расширения контента                             |
| География и языки первой beta      | Влияет на compliance, support и localization         | Одна управляемая география/язык на первый cohort                    |
| Production IdP                     | Блокирует auth, account lifecycle и signed candidate | Выбрать одного provider и owner-а конфигурации                      |
| Hosting / protected environment    | Блокирует stage, secrets, monitoring и restore       | Один простой managed контур; без микросервисов                      |
| Apple/Google account type          | Определяет verification и возможный 12/14 Play gate  | Проверить немедленно                                                |
| Юридический оператор и public URLs | Нужны Privacy Policy, support, deletion              | Опубликовать до beta invitation                                     |
| Push/payment в v1                  | Сильно расширяет внешний scope                       | Оставить disabled в первой публикации                               |
| Beta cohort и support owner        | Нужны recruitment, incident window и evidence        | Назначить owner и канал до E5                                       |
| Alpha/beta thresholds              | Без порогов analytics не ведёт к решению             | Использовать vision-гипотезы как старт, затем явно принять/изменить |

### Стартовые продуктовые ориентиры из vision

- \>70% завершивших onboarding дают разрешение на шаги;

- \>55% получают первую награду в первые сутки;

- D7 \>25%, D30 \>10%;

- crash-free sessions \>99,5%; sync error \<1%;

- Meaningful Active Week: личная цель ≥3 дней + ≥1 expedition node + ≥1 progression action.

*Эти значения — гипотезы, а не обещания. До закрытой beta они должны быть формально приняты как decision thresholds либо заменены более реалистичными порогами.*

## 12. Правила последующей нарезки на задачи

Каждая будущая задача должна содержать:

- Epic ID и один проверяемый outcome;

- тип: CODE / CONFIG / MANUAL_VALIDATION / PRODUCT_RESEARCH / STORE-EXTERNAL;

- приоритет, owner и явные зависимости;

- scope и out-of-scope;

- acceptance criteria, которые можно однозначно проверить;

- обязательный evidence artifact и место его хранения;

- rollback/stop condition для рискованных изменений;

- финальный статус отдельно для CODE_COMPLETE и VALIDATED.

### Шаблон задачи

| **Поле**        | **Содержание**                                                       |
|-----------------|----------------------------------------------------------------------|
| ID / Epic       | E# / краткое имя                                                     |
| Outcome         | Какое внешне наблюдаемое состояние должно появиться                  |
| Type / Owner    | CODE, CONFIG, MANUAL_VALIDATION, PRODUCT_RESEARCH или STORE-EXTERNAL |
| Dependencies    | Конкретные задачи, credentials, устройства или решения               |
| Scope           | Что делаем; какие пути/системы затрагиваем                           |
| Out of scope    | Что сознательно не включаем                                          |
| Acceptance      | Проверяемые условия pass/fail                                        |
| Evidence        | SHA/build/device/environment/date/log/screenshot/analytics snapshot  |
| Stop / rollback | Когда остановиться и как безопасно вернуться                         |
| Status          | CODE_COMPLETE ≠ VALIDATED                                            |

### Правила размера

- Одна code-задача должна завершаться одним логическим PR и не смешивать backend/design без необходимости.

- Одна validation-задача покрывает одну матрицу или один decision gate, а не «проверить всё приложение».

- Credentials/account verification выделяются отдельно от кода; отсутствие доступа — BLOCKED, а не незавершённая реализация.

- Каждый найденный defect получает отдельную issue и ссылку из validation evidence.

- Эпик закрывается только когда приняты все evidence, а не когда создан последний PR.

## 13. Рекомендуемая первая волна задач

| **Пакет**               | **Результат**                                                     | **Эпик** | **Тип**               |
|-------------------------|-------------------------------------------------------------------|----------|-----------------------|
| W0.1 Backlog reset      | #26/#29 закрыты или преобразованы; validation backlog создан     | E0       | Governance            |
| W0.2 alpha-rc1          | Exact master SHA/tree + green integrated artifacts/digests        | E0       | Release               |
| W1.1 Device inventory   | Назначены устройства, OS/provider matrix и исполнители            | E1       | Manual prep           |
| W1.2 Core Health matrix | Permission/sync/replay/watch/providers имеют evidence             | E1       | Validation            |
| W2.1 IdP decision       | Provider, owner, domains, clients и claims зафиксированы          | E2       | Decision/config       |
| W2.2 Physical auth E2E  | Login/refresh/logout/delete на iOS/Android                        | E2       | Validation            |
| W3.1 Stage environment  | TLS DB, secrets, probes, monitoring доступны                      | E3       | Infrastructure        |
| W3.2 Real restore drill | Датированный backup восстановлен в isolated environment           | E3       | Operations validation |
| W4.1 Visual direction   | Принято одно направление главы/pets и список exclusions           | E4       | Product decision      |
| W5.1 Alpha protocol     | Cohort, build, script, thresholds и stop conditions зафиксированы | E5       | Research ops          |

> [!IMPORTANT]
> **Первый практический шаг.** Не открывать следующий feature PR. Сначала
> провести 60–90-минутную backlog/decision session: принять stage name,
> feature freeze, `alpha-rc1` SHA, владельцев E1–E3 и решения по IdP/developer
> accounts. После этого выполнять первую волну W0–W5 отдельными задачами.

## 14. Definition of ready

### Ready for internal alpha

- alpha-rc1 имеет exact SHA/tree, green integrated CI/release artifacts и changelog;

- device matrix, cohort, support owner и stop conditions назначены;

- критические privacy rationale и data handling понятны;

- есть доступный stage backend и рабочий auth path либо явно ограниченный internal mode;

- нет известных blockers потери экономики, account data или запуска.

### Ready for closed beta

- physical Health matrix имеет evidence;

- production-like OIDC, export/delete, monitoring, backup/restore и rollback пройдены;

- signed TestFlight/Play candidate устанавливается и обновляется;

- public Privacy Policy/support/deletion URLs и store declarations готовы;

- 10-minute first journey понятен и alpha blockers закрыты;

- cohort rollout и support/incident procedure утверждены.

### Ready to upload / publish

Для upload выполняется полный Definition of ready to upload из STORE_LAUNCH_PLAN: signing, SDK, declarations, real auth/account deletion, device matrix, production operations и owner approval. Для public rollout дополнительно нужны store review, применимый closed-testing gate, разобранная beta, отсутствие release blockers и подготовленный staged rollout.

## 15. Итоговая рекомендация

Walking RPG технически готов к переходу в alpha, но не готов к публичному запуску. Проекту больше не нужен ещё один длинный цикл автономной реализации roadmap: он уже выполнен. Нужен управляемый validation program, который превратит сильную инженерную базу в доказанную продуктовую и операционную готовность.

> [!IMPORTANT]
> **Решение на сейчас.** Зафиксировать `alpha-rc1`, очистить backlog, назначить
> владельцев устройств/IdP/operations и начать E1–E3. Следующий большой
> продуктовый backlog формировать только после первых alpha findings.

## Приложение A. Evidence и источники

- [Repository](https://github.com/MKSEgr/walking-rpg)
- [Master snapshot](https://github.com/MKSEgr/walking-rpg/commit/6708dec1f4599a937b343a1992e7c68f604d17a0)
- [README](../README.md)
- [Project vision](../PROJECT_VISION.md)
- [Roadmap](ROADMAP.md)
- [Architecture](ARCHITECTURE.md)
- [API draft](API_DRAFT.md)
- [Design system](DESIGN_SYSTEM.md)
- [Store launch plan](STORE_LAUNCH_PLAN.md)
- [Release checklist](RELEASE_CHECKLIST.md)
- [Device validation protocol](DEVICE_VALIDATION_PROTOCOL.md)
- [Closed beta runbook](CLOSED_BETA_RUNBOOK.md)
- [Issue #21 — physical Health validation](https://github.com/MKSEgr/walking-rpg/issues/21)
- [Issue #26 — second node/inventory](https://github.com/MKSEgr/walking-rpg/issues/26) — фактический scope реализован.
- [Issue #29 — autonomous roadmap batch](https://github.com/MKSEgr/walking-rpg/issues/29) — software scope фактически завершён.
- [PR #145 — navigation glyphs](https://github.com/MKSEgr/walking-rpg/pull/145)
- [PR #146 — exact API integers](https://github.com/MKSEgr/walking-rpg/pull/146)
- [CI #576](https://github.com/MKSEgr/walking-rpg/actions/runs/31170057688)
- [Release quality #457](https://github.com/MKSEgr/walking-rpg/actions/runs/31170057790)
- [Release finalizer #346](https://github.com/MKSEgr/walking-rpg/actions/runs/31170057781)

## Приложение B. Термины статуса

| **Статус**      | **Значение**                                                                                        |
|-----------------|-----------------------------------------------------------------------------------------------------|
| CODE_COMPLETE   | Реализовано, документировано и проверяется автоматическими контрактами/CI.                          |
| VALIDATED       | Есть датированное evidence из требуемого реального контекста: device, deployment, store или cohort. |
| BLOCKED         | Нужен внешний доступ, credential, устройство, account verification или owner decision.              |
| DEFERRED        | Не входит в текущий критический путь; возвращается только по product signal.                        |
| RELEASE_BLOCKER | Нарушает безопасность данных/экономики, запуск, обязательный flow, compliance или rollback.         |
