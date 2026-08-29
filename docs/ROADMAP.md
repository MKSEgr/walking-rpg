# Roadmap

Этот файл сохраняет историческую декомпозицию выполненного software scope.
Порядок дальнейшей delivery-программы от alpha baseline до release и live
operations находится в [Forward roadmap](FORWARD_ROADMAP.md).

Roadmap отражает снижение рисков. Статусы:

- `[x] CODE_COMPLETE` — реализовано и проверяется CI;
- `[ ] CODE_PENDING` — остаётся автономная программная работа;
- `[ ] EXTERNAL_VALIDATION_REQUIRED` — нужен девайс, credential, магазин или реальные пользователи;
- `VALIDATED` ставится только при наличии датированного evidence.

## Milestone 0 — Repository baseline

- [x] Концепция, Java backend, Flutter shell, PostgreSQL/Flyway и ADR
- [x] Standard CI: backend, Flutter, Android debug, iOS Simulator
- [x] CODEOWNERS и активные ruleset для `master`
- [x] Release-quality CI, deterministic metadata и release checklist
- [x] Store launch gates зафиксированы в `STORE_LAUNCH_PLAN.md`

## Milestone 1 — Platform Health API

### CODE_COMPLETE

- [x] iOS 14 / Android minSdk 26
- [x] HealthKit и Health Connect foreground adapters
- [x] Только `STEPS READ`, IANA timezone и aggregated total
- [x] Durable foreground outbox и safe resume fallback
- [x] Device validation protocol и evidence template
- [x] Internal-only `ValidationCenterScreen`: fail-closed release policy,
      owner-bound in-memory per-launch journal и exact source/build metadata
- [x] Redacted `walking-rpg-device-validation-evidence-v1` JSON export с
      checksum, temporary share/delete и границами 64 entries / 64 KiB

### EXTERNAL_VALIDATION_REQUIRED

- [ ] iPhone без Apple Watch
- [ ] iPhone + Apple Watch
- [ ] Android + несколько Health Connect providers
- [ ] Ручной ввод, удаление/коррекция и отзыв разрешения
- [ ] Timezone/midnight
- [ ] Battery/background evidence
- [ ] Проверить schema-v1 JSON, redaction и checksum для каждого фактического
      прогона; готовность Validation Center сама по себе не является device
      evidence

## Milestone 2 — Activity sync vertical slice

- [x] `/api/v1/activity/sync`, user/device/state
- [x] Persistent idempotency и multi-device serialization
- [x] Positive delta → ENERGY wallet/ledger
- [x] Retention processed sync
- [x] Attestation/risk score, audit trail и admin read model в shadow mode
- [x] Unit/API/PostgreSQL tests

## Milestone 3 — First playable

- [x] Production home, economy, expedition, progression и inventory
- [x] Два первоначальных узла и события
- [x] Durable mobile gameplay commands
- [x] Server-authoritative rewards и exact replay
- [x] Durable event-result receipt, home pending projection и owner-scoped ACK

## Milestone 4 — MVP content loop

- [x] 18 content-driven узлов первой главы и versioned content delivery
- [x] Три питомца, active selection, две эволюции и adult-pet route до
      `constellation-sanctuary`
- [x] Навыки, задания, достижения и onboarding
- [x] «Чтение сигналов» как authoritative prerequisite скрытого исхода
      `constellation-sanctuary` в staged `chapter-1-v13`
- [x] Продолжение skill-gated исхода в 27-й узел
      `hidden-signal-observatory` в staged `chapter-1-v14`
- [x] «Память маршрута» как authoritative prerequisite продолжения в 28-й
      узел `memory-constellation` в staged `chapter-1-v15`
- [x] «Дисциплина энергии» как authoritative prerequisite продолжения в 29-й
      узел `dawn-meridian` в staged `chapter-1-v16`
- [x] «Ровный шаг» как authoritative prerequisite продолжения в 30-й узел
      `first-light-causeway` в staged `chapter-1-v17`
- [x] Push provider boundary + development implementation
- [x] Remote config и базовый admin content API
- [x] Flutter «Путевой журнал» для platform state/commands
- [x] Read-only offline cache валидированных home/platform snapshots

## Milestone 5 — Closed beta technical readiness

- [x] Onboarding/product analytics и D1/D7/D30 read model
- [x] Crash-reporting boundary и diagnostics ingestion
- [x] Anti-fraud admin read model
- [x] Economy simulation/tests
- [x] Backend export/delete account
- [x] Mobile «Аккаунт и данные»: JSON export/share, повторная OIDC-проверка,
      двухэтапное подтверждение, idempotent deletion receipt и локальная очистка
- [x] Backend OIDC/JWT boundary: issuer/audience validation, canonical `sub`, user/admin authorization и dev-header isolation
- [x] Privacy/store declarations draft
- [x] Tester cohort/admin support и closed-beta runbook
- [ ] 50–500 фактических тестировщиков — EXTERNAL_VALIDATION_REQUIRED

## Milestone 6 — Soft-launch technical readiness

- [x] Season, weekly routes и squads
- [x] Cosmetic catalog/shop и server-authoritative `PILOT`/`PET`/`PROFILE`
      equipment slots с legacy read compatibility
- [x] Payment-provider boundary + sandbox provider
- [x] A/B assignment и exposure logging
- [x] Release candidate CI и store review checklist
- [x] Mobile OIDC Authorization Code + PKCE, secure session storage, refresh и logout
- [x] Telegram OIDC connection contract через Auth0 Universal Login с S256,
      минимальными scopes и secret-free CI checks
- [ ] Production identity-provider client/redirect configuration — EXTERNAL_VALIDATION_REQUIRED
- [ ] Telegram bot/callback/Auth0 connection и physical iOS/Android evidence —
      EXTERNAL_VALIDATION_REQUIRED
- [ ] Production APNs/FCM — EXTERNAL_VALIDATION_REQUIRED
- [ ] App Store / Google Play billing — EXTERNAL_VALIDATION_REQUIRED
- [ ] Production signing/submission/review — EXTERNAL_VALIDATION_REQUIRED

## Milestone 7 — Alpha first journey

### CODE_COMPLETE

- [x] Один guided flow: вход → разрешение шагов → первая ENERGY → выбор
      питомца → первый узел → первое событие
- [x] Шесть onboarding milestones отмечаются реальными действиями, а не
      отдельными кнопками «завершить»
- [x] «Продолжить позже», restart-safe command replay и восстановление
      milestones из authoritative home/platform facts
- [x] Выбранный питомец используется в home и получает собственный bond за
      события; progression разных питомцев не смешивается
- [x] Неблокирующая reward/haptic feedback и read-only поведение cached state
- [x] Restart-visible result card и persist-before-send acknowledgement перед
      следующим advance/resolution
- [x] Capability + cluster activation gate: V10/new backend/new mobile
      выкатываются при disabled gate, durable mode включается после drain
      старых instances, exact replay сохраняет исходный delivery mode
- [x] Domain/widget/backend regression tests первого пути
- [x] Durable server-authoritative milestones первого пути с exact-once временем
- [x] Cohort funnel и p50/p90 time-to-value без смешивания legacy backfill
- [x] Explicit result-ACK как финальный delivery milestone; legacy auto-ACK
      участвует только в backfilled conversion без ложного timing
- [x] Owner-scoped mobile recovery center: безопасный повтор `PENDING`,
      подтверждённый dismiss только terminal `FAILED` и fail-closed corruption
- [x] Отдельная `TELEMETRY` lane для experiment exposure, ordered
      `ACTIVITY → GAMEPLAY` replay с retryable barrier и единственный startup
      replay owner

### EXTERNAL_VALIDATION_REQUIRED

- [ ] Пройти первые 10 минут на чистой установке iOS и Android
- [ ] Проверить понятность Health permission, отказ, повторный запрос и отзыв
- [ ] Собрать фактические time-to-first-ENERGY, time-to-first-node и
      time-to-result-ACK на alpha cohort и принять продуктовые пороги
- [ ] Проверить тексты, темп и эмоциональную ценность выбора питомца на alpha
      cohort

## Milestone 8 — Production environment/config/operations hardening

### A4a — CODE_COMPLETE

- [x] `local`/`test` отделены от защищённых `stage`/`prod`; смешанные профили
      и небезопасная datasource configuration отклоняются fail-closed
- [x] `stage`/`prod` требуют явную PostgreSQL configuration с проверяемым TLS
- [x] Sandbox payment и development push регистрируются только при явном
      opt-in в `local`/`test`; защищённые профили используют disabled
      providers
- [x] Новая недоступная покупка отклоняется до state mutation; replay
      сохранённой команды сохраняет outcome/state без provider call, но
      capability fields заново проецируются из текущего deployment
- [x] Flyway V12 выключает sandbox-payment/background-health flags во всех
      существующих remote-config snapshots
- [x] Platform snapshot маскирует sandbox flag при disabled provider; mobile
      не показывает purchase action в release build, при `false` или cached
      state
- [x] Release-quality checks закрепляют provider/effective-capability boundary

### A4b — CODE_COMPLETE

- [x] Ограничить публичный diagnostics/telemetry ingress проверяемыми
      per-process client/global rate и body/DTO limits; distributed ingress
      policy остаётся внешней
- [x] Разделить liveness/readiness/metrics exposure, изолировать management
      listener защищённых профилей и закрепить operational timeouts
- [x] Добавить проверяемый synthetic backup/restore-drill pack без production
      данных или secrets и с machine-verifiable evidence

### EXTERNAL_VALIDATION_REQUIRED

- [ ] Передать production OIDC/database secrets через protected environment и
      проверить least-privilege role на реальном TLS endpoint
- [ ] Выполнить фактический deployment, management network isolation,
      WAF/distributed abuse controls, monitoring/alerting и rollback drill
- [ ] Утвердить backup policy/RPO/RTO/PITR и выполнить датированный restore
      реального backup в изолированной среде

## Milestone 9 — Store candidate packaging

### CODE_COMPLETE

- [x] Android `compileSdk` и `targetSdk` явно закреплены на API 36 при
      сохранении `minSdk = 26`
- [x] Release metadata и release-policy проверяют явный SDK contract, а
      release artifacts собираются из exact PR head
- [x] Обычный CI остаётся unsigned/no-codesign и не использует debug signing
- [x] Android protected signing включается только явным external
      properties-file contract; неполные, лишние и repository-local inputs
      отклоняются fail-closed
- [x] Synthetic signing rehearsal использует одноразовый внешний keystore, не
      сохраняет подписанный artifact и не выдаётся за production validation
- [x] CI selector gate закрепляет каждый backend `*Test` ровно за одним
      штатным job, кроме отдельного synthetic restore drill

### EXTERNAL_VALIDATION_REQUIRED

- [ ] Утвердить окончательные Android application ID, iOS Bundle ID и
      соответствующие production OIDC clients/redirects
- [ ] Настроить Apple/Google developer accounts, Play App Signing, upload key,
      Distribution identity и App Store provisioning profile
- [ ] Собрать, проверить и установить подписанные TestFlight / Play internal
      candidates из проверенного post-merge `master` SHA, tree которого
      совпадает с CODEOWNER-approved PR

## Milestone 10 — Server-authoritative crafting

### CODE_COMPLETE

- [x] Versioned starter recipe `resonance-compass-v1` с server-owned
      ingredients и unique result
- [x] Атомарное debit двух material stacks, append-only audit и запрет
      отрицательного inventory balance
- [x] Persistent unique item instance и exact idempotent crafting response
- [x] Additive crafting projection в `GET /home` и Flutter **«Мастерская»**
- [x] Persist-before-send `CRAFTING` в GAMEPLAY outbox и authoritative reload
- [x] V12→V13 upgrade, concurrency, API/widget, account export/delete и
      synthetic backup/restore tests

### EXTERNAL_VALIDATION_REQUIRED

- [ ] Проверить понятность стоимости/ценности первого unique item на beta
      cohort
- [ ] Настроить следующие recipes и баланс material sinks по фактической
      экономике, не по synthetic данным

## Milestone 11 — Equipment and resonance route

### CODE_COMPLETE

- [x] Versioned `equipment-v1` и persistent slot `NAVIGATION` только для
      принадлежащего пользователю unique item
- [x] Desired-state equip/unequip API с exact replay, fingerprint conflict и
      атомарным slot state/processed response
- [x] Общие account-deletion и expedition serialization boundaries; новая
      equipment mutation запрещена при pending event receipt, exact replay
      остаётся доступен
- [x] Additive equipment/availability projection в `GET /home`, Flutter
      **«Снаряжение»** и restart-safe `EQUIPMENT` в GAMEPLAY outbox
- [x] `chapter-1-v2`: 18 основных узлов и опциональный
      `resonance-pocket`, доступный из `mirror-delta-v1` только с
      экипированным `resonance-compass`
- [x] V13→V14 upgrade, ownership/uniqueness constraints, unit/API/PostgreSQL/
      widget tests, account export/delete и synthetic backup/restore coverage

### EXTERNAL_VALIDATION_REQUIRED

- [ ] Проверить, что beta-пользователь понимает разницу между созданием и
      экипировкой компаса и замечает недоступный маршрут без подсказки
- [ ] Проверить ценность и баланс наград опционального маршрута по фактическим
      прохождениям, не по synthetic данным

## Milestone 12 — Visual foundation

### CODE_COMPLETE

- [x] Семантическая light/dark тема с lumen, ENERGY и resonance accent roles
- [x] Общие атмосферный фон, field panel, badge, progress ring и section title
- [x] Игровая иерархия главного экрана: путь → шаги → ENERGY → действие →
      событие → команда → полевой комплект
- [x] Плавающая нижняя навигация с сохранением существующего shell lifecycle
- [x] Единый визуальный язык главной экспедиции и guided **«Первого пути»**
- [x] Exact-ID маршрутный сигнал onboarding по server-owned порядку этапов и
      фактическому completed-набору без предсказания следующего шага
- [x] Вход в экспедицию в общем визуальном языке без изменения OIDC lifecycle
- [x] Иллюстрированные сцены четырёх ключевых событий с exact-`eventId`
      mapping, доступными semantics и нейтральным fallback
- [x] Exact-ID сигилы навыков и достижений с явным состоянием и нейтральным
      fallback для будущего серверного контента
- [x] Metric-driven знаки и маршрутная шкала заданий с буквальным прогрессом и
      нейтральным fallback для будущих типов целей
- [x] Exact-ID маяк недельного маршрута с принятым ENERGY-прогрессом и
      нейтральным fallback без выдуманной топологии главы
- [x] Server-owned сигнал формации отряда с точным составом, доступным summary
      и компактным состоянием создания/вступления без выдуманных ролей
- [x] Design rules, accessibility boundaries и следующие срезы зафиксированы в
      `docs/DESIGN_SYSTEM.md`

### PRODUCT_VALIDATION_REQUIRED

- [ ] Утвердить art direction первой главы и трёх starter pets
- [ ] Проверить на alpha cohort, что экран читается как RPG, а основной следующий
      шаг находится без подсказки
- [ ] Проверить светлую/тёмную тему, увеличенный системный шрифт и контраст на
      физических iOS/Android устройствах
- [ ] Утвердить motion, app icon, splash и store artwork после выбора финального
      визуального направления

## Milestone 13 — Compass beta funnel

### CODE_COMPLETE

- [x] Idempotent `RECORD_COMPASS_IMPRESSION` с server-canonical recipe/route
      attributes и запретом route telemetry до cluster activation v2
- [x] Network-only viewport instrumentation для `MISSING_MATERIALS`, `READY`,
      `CRAFTED`, locked и available states; cached/offscreen/covered/background
      snapshot не создаёт показ
- [x] Отдельная mobile `TELEMETRY` lane и cache-neutral platform command:
      потеря telemetry не задерживает ACTIVITY/GAMEPLAY и не меняет UI state
- [x] Cohort-filtered admin read model двух funnel-ов:
      recipe → craft → equip и mirror → route choice → completion
- [x] Craft/equip/reach/choice/completion считаются только по существующим
      server-authoritative receipts; client impression явно помечен отдельно
- [x] Route denominator привязан к cluster activation v2: ожидавшие стартуют
      в immutable V15 activation time, same-version republish его не меняет,
      а resolved legacy Mirror Delta исключены
- [x] Repeatable-read snapshot, ordered p50/p90 и data-quality counters для
      out-of-order пар и authoritative target без instrumented baseline
- [x] Unit/API/PostgreSQL snapshot/widget/outbox/cache regression tests и
      обязательный CI selector

### EXTERNAL_VALIDATION_REQUIRED

- [ ] Собрать funnel по реальному beta cohort/build и проверить достаточную
      instrumentation rate до продуктовых выводов
- [ ] Проверить фактический drop-off recipe → craft → equip и понять причину
      каждого разрыва через интервью/support evidence
- [ ] Проверить обнаружение, выбор и завершение resonance route; только после
      этого принимать решение о copy, наградах и следующих recipes/routes
- [ ] Зафиксировать cohort, build, период и принятые пороги в beta evidence;
      code-complete analytics сама по себе не считается `VALIDATED`

## Milestone 14 — Repeatable expedition journeys

### CODE_COMPLETE

- [x] `POST /expeditions/{id}/journeys` с exact replay и stale
      `expectedJourneyNumber` guard
- [x] Сброс только route state на первый узел active content без
      сброса pilot/pet/skills/inventory/equipment progression
- [x] Persistent Home `journeyNumber` и per-journey uniqueness награды
      за event
- [x] Restart-safe `EXPEDITION_JOURNEY_START` в GAMEPLAY outbox, authoritative
      Home reload и read-only cached/pending-result guards
- [x] Flyway V34 backfill, account export/delete, synthetic backup/restore и
      unit/API/PostgreSQL/migration/parser/outbox/widget tests

### EXTERNAL_VALIDATION_REQUIRED

- [ ] Проверить заметность кнопки нового похода и понимание того, что
      постоянная прогрессия сохранилась, на beta cohort
- [ ] Оценить economy/retention повторных наград до изменения баланса

## Milestone 15 — Current journey route trail

### CODE_COMPLETE

- [x] Additive Home `routeTrail` из durable event results только текущего
      `journeyNumber`
- [x] Literal `VISITED`, `CURRENT`, `COMPLETED` state без публикации будущей
      topology и без mobile inference
- [x] Code-native scrollable Home map с RU/EN semantics и legacy parser
      fallback
- [x] Unit/API/PostgreSQL/parser/widget coverage, включая сброс trail для
      нового похода

## Milestone 16 — Current journey decision log

### CODE_COMPLETE

- [x] Additive Home `decisionLog` из durable event results только текущего
      `journeyNumber`
- [x] Persisted event/choice/outcome copy и `resolvedAt`, устойчивые к content
      republish/rollback
- [x] Code-native journal card, ordered entries, accessible empty state и
      legacy parser fallback
- [x] Unit/API/PostgreSQL/parser/widget coverage, включая пустой журнал нового
      похода и Home-unavailable fallback

## Milestone 17 — Current journey decision rewards

### CODE_COMPLETE

- [x] Additive persisted XP, companion bond identity и nullable material reward
      в каждой записи Home `decisionLog`
- [x] Reward projection из immutable `processed_event_resolution` текущего
      `journeyNumber` без content lookup или delta по текущим totals
- [x] Compact reward chips и единая accessibility summary без client inference
- [x] Unit/API/PostgreSQL/parser/widget coverage и legacy reward-field fallback

## Milestone 18 — Completed journey recap

### CODE_COMPLETE

- [x] Additive nullable Home `completionRecap` только для `COMPLETED` и exact
      current `journeyNumber`
- [x] Суммы persisted XP/companion bond и ordered material totals из immutable
      event resolutions без content lookup или mobile aggregation
- [x] Code-native completion card и единая accessibility summary перед
      decision log; in-progress/new/legacy snapshots не получают ложных totals
- [x] Unit/API/PostgreSQL/parser/widget coverage completed, in-progress,
      legacy, invalid и grouped-material cases

## Milestone 19 — Recent completed journey archive

### CODE_COMPLETE

- [x] Additive Home `recentJourneyRecaps` максимум для пяти предыдущих
      завершённых `journeyNumber`, ordered newest-first
- [x] Completion proof из immutable receipt старта следующего похода без
      доверия historical `expedition_status=COMPLETED`
- [x] Exact persisted reward aggregation и code-native accessible archive
      после decision log; текущий поход остаётся отдельным
- [x] Unit/PostgreSQL/parser/widget coverage limit, order, legacy fallback и
      исключения ложного current completion

## Milestone 20 — Journey companion bond breakdown

### CODE_COMPLETE

- [x] Additive ordered `petBondRewards[]` в current и recent journey recap из
      persisted pet identity/name и фактически выданной связи
- [x] First-appearance grouping с exact sum к совместимому `petBondGained` без
      current-content, current-pet или total-delta inference
- [x] Named companion chips и единая accessibility summary с legacy fallback
      на общий итог при отсутствии additive массива
- [x] Unit/API/PostgreSQL/parser/widget coverage aggregation, order, invalid
      sum, duplicate identity и legacy response

## Milestone 21 — Completed journey finale

### CODE_COMPLETE

- [x] Additive nullable `finalDecision` в current и recent journey recaps из
      последней ordered immutable event resolution exact-похода
- [x] Persisted event/choice/outcome copy и `resolvedAt` без current-content,
      node-ID или status inference
- [x] Compact finale block перед наградами и тот же текст в единой recap
      accessibility summary с legacy omission
- [x] Unit/API/PostgreSQL/parser/widget coverage current, recent, exact copy,
      invalid timestamp и legacy response

## Milestone 22 — Decisions on the current journey route

### CODE_COMPLETE

- [x] Additive nullable `routeTrail[].decision` из той же ordered immutable
      event resolution exact текущего `journeyNumber`
- [x] Persisted choice identity/title и outcome title без mobile join,
      current-content lookup или topology inference
- [x] Compact `choice → outcome` у разрешённых точек и тот же ordered текст в
      единой RU/EN accessibility summary
- [x] Unit/API/PostgreSQL/parser/widget/Home coverage visited, current,
      completed, persisted copy, long text и legacy omission

## Milestone 23 — Full decision history in the journey archive

### CODE_COMPLETE

- [x] Additive ordered `decisions[]` в current и recent recap из immutable
      resolutions exact `journeyNumber`
- [x] Persisted event/choice/outcome copy, resolution time и reward facts без
      current-content, totals или topology inference
- [x] Compact-by-default archive с accessible show/hide control и повторным
      использованием numbered decision entries только после раскрытия
- [x] Unit/API/PostgreSQL/parser/widget coverage order, exact copy, rewards,
      count/finale consistency, large text и legacy omission

## Milestone 24 — Lifetime journey chronicle

### CODE_COMPLETE

- [x] Additive nullable Home `journeyChronicle` с lifetime completed journey,
      decision, pilot XP и companion bond totals
- [x] Completion proof прошлых походов из immutable next-journey receipts и
      current `COMPLETED` inclusion без double count или archive-limit coupling
- [x] Code-native accessible card между decision log и recent archive с
      wrapping totals для compact large text
- [x] Unit/API/PostgreSQL/parser/widget coverage current + previous totals,
      history длиннее пяти, invalid shape и legacy omission

## Milestone 25 — Canonical Navigator companion

### CODE_COMPLETE

- [x] Current catalog, progression and pet-gated route copy present stable
      `rune-v1` as «Навигатор», «Навигатор потоков» and «Навигатор созвездий»
- [x] RU/EN mandatory-flow localization resolves the stable ID without
      changing internal enums or `companion_rune_*` assets
- [x] Paired crew copy uses the neutral pilot role while `navigator-v1`
      retains «Навигатор» in portrait and dossier contexts
- [x] Backend, Flutter and accessibility coverage protects current copy and
      stable-ID compatibility; historical migrations and receipts stay intact

This milestone starts the post-alpha code-only gameplay track approved in
ADR 0039. The immutable `alpha-rc1` baseline and all external validation gates
remain separate and unchanged.

## Milestone 26 — Full RU/EN game localization

### CODE_COMPLETE — expedition shell slice

- [x] Selected device locale continues through compact/wide navigation and
      the full client-authored Home chrome after the guided first journey
- [x] Loading, error, offline, journey action, feedback, event reward,
      equipment, inventory, crafting and upgrade copy comes from generated ARB
- [x] Dynamic values use typed placeholders; companion growth, motion and
      saved-action entry semantics follow RU/EN at large text
- [x] Resource parity, source audit and compact/wide widget coverage protect
      both locales without changing backend payloads or persisted history

### CODE_COMPLETE — current identity catalog slice

- [x] Current expedition, all known route nodes, pilot/companion, inventory,
      equipment, recipes and upgrades resolve RU/EN copy by stable ID
- [x] Home exposes additive `pilotId`; legacy cached snapshots accept omission
      and retain their literal pilot name
- [x] Unknown IDs and content from newer backends retain literal fallback;
      display text is never used to infer identity
- [x] Event decisions, outcomes, durable receipts, decision logs and current or
      archived recaps remain immutable persisted copy
- [x] Backend contract tests, exhaustive RU/EN catalog tests, compact large-text
      widgets and accessibility assertions protect the boundary

### CODE_COMPLETE — current event narrative slice

- [x] All 30 known READY event titles/summaries and 78 exact event/choice pairs
      resolve through generated RU/EN copy by stable identity
- [x] All 16 gated choice requirements and event-unlock feedback use the same
      exact-ID resolver; unknown content retains literal server fallback
- [x] Resolved event copy, selected decisions, outcomes, pending results,
      durable receipts and current or archived recaps remain persisted literal
- [x] Backend inventory counts, exhaustive RU/EN resolver tests, compact
      text-scale 1.6 widgets and accessibility semantics protect the boundary

### CODE_COMPLETE — Platform journal slice

- [x] Complete Platform journal chrome, loading/error states, journey history,
      progression/catalog actions and semantics use generated RU/EN resources
- [x] Six onboarding steps, four skills, five quests, eight achievements, four
      cosmetics, current season and two experiment descriptions resolve only
      by stable backend identity; unknown content retains literal fallback
- [x] Known Platform command feedback resolves by command type without exposing
      Russian backend messages in the English player surface
- [x] Weekly route, quest progress and companion bond signals share the same
      locale at compact text scale 1.6, while immutable decisions and recaps
      remain persisted literal history

### CODE_COMPLETE — remaining boundary surfaces

- [x] Account, destructive confirmation, recovery journal, activity sync,
      Validation Center and shared launch/design-system boundaries use the
      selected generated RU/EN resources
- [x] Stable command/error categories map to privacy-safe localized feedback;
      filenames, receipts, timestamps, wire values and server-owned IDs remain
      literal while raw runtime/backend diagnostics never become player copy
- [x] Locale-specific account deletion requires exact `УДАЛИТЬ` / `DELETE`
      confirmation without changing the idempotent deletion contract
- [x] Source audit covers all mobile app, presentation and shared boundary
      surfaces; RU/EN compact text-scale 1.6 and accessibility widgets protect
      the completed client-authored localization boundary

The incremental identity and persistence boundary is fixed by ADR 0040.
Milestone 26 is code-complete. It does not change any external validation gate
or the immutable `alpha-rc1` baseline.

## Milestone 27 — Lifetime companion bond breakdown

### CODE_COMPLETE

- [x] Additive ordered `journeyChronicle.petBondRewards[]` из persisted
      companion identity/name и фактически выданной связи всех receipt-proven
      завершённых походов
- [x] First-appearance grouping и authoritative current `COMPLETED` merge
      ровно один раз с exact sum к совместимому `petBondGained`, без
      current-content, progression-total или archive-limit inference
- [x] Именные RU/EN reward chips и единая accessibility summary с legacy
      fallback на общий итог при отсутствии additive массива
- [x] Backend unit/API/PostgreSQL, Flutter parser/widget и compact large-text
      coverage проверяют порядок, сумму, identity, omission и invalid data

Milestone 27 продолжает post-alpha code-only gameplay track из ADR 0039 и не
меняет immutable `alpha-rc1`, экономику, topology или external validation
gates.

## Milestone 28 — Lifetime material reward breakdown

### CODE_COMPLETE

- [x] Additive ordered `journeyChronicle.materials[]` из persisted material
      identity/name и фактически выданного quantity всех receipt-proven
      завершённых походов
- [x] First-appearance grouping и authoritative current `COMPLETED` merge
      ровно один раз без inventory, current-content или archive-limit
      inference
- [x] Ordered RU/EN material chips и единая accessibility summary с legacy
      omission как пустой breakdown
- [x] Backend unit/API/PostgreSQL, Flutter parser/widget и compact large-text
      coverage проверяют persisted copy, порядок, current merge и invalid data

Milestone 28 продолжает post-alpha code-only gameplay track из ADR 0039 и не
меняет immutable `alpha-rc1`, экономику, topology или external validation
gates.

## Milestone 29 — Lifetime route finale breakdown

### CODE_COMPLETE

- [x] Additive ordered `journeyChronicle.finaleOutcomes[]` из последней
      immutable resolution каждого receipt-proven завершённого похода
- [x] Grouping по persisted event/choice/outcome copy, first-appearance order
      и authoritative current `COMPLETED` merge ровно один раз без lookup
      current content или recent archive inference
- [x] Exact count invariant с legacy omission, отдельные RU/EN finale chips и
      единая полная accessibility summary
- [x] Backend unit/API/PostgreSQL, Flutter parser/widget и compact text-scale
      1.6 coverage проверяют persisted copy, порядок, current merge,
      unconfirmed exclusion и invalid data

Milestone 29 продолжает post-alpha code-only gameplay track из ADR 0039 и не
меняет immutable `alpha-rc1`, schema, economy, topology или external
validation gates.

## Milestone 30 — Lifetime route decision breakdown

### CODE_COMPLETE

- [x] Additive ordered `journeyChronicle.decisionOutcomes[]` из всех immutable
      resolutions receipt-proven завершённых походов
- [x] Grouping по persisted event/choice/outcome copy, first-appearance order
      и authoritative current `COMPLETED` merge всех решений ровно один раз
      без lookup current content или recent archive inference
- [x] Exact sum к совместимому `decisionCount` с legacy omission, отдельные
      RU/EN decision chips и единая полная accessibility summary
- [x] Backend unit/API/PostgreSQL, Flutter parser/widget и compact text-scale
      1.6 coverage проверяют persisted copy, порядок, current merge,
      unconfirmed exclusion и invalid data

Milestone 30 продолжает post-alpha code-only gameplay track из ADR 0039 и не
меняет immutable `alpha-rc1`, schema, economy, topology или external
validation gates.

## Milestone 31 — Lifetime pilot experience breakdown

### CODE_COMPLETE

- [x] Additive ordered `journeyChronicle.pilotExperienceRewards[]` из
      persisted pilot identity/name и фактически выданного XP всех
      receipt-proven завершённых походов
- [x] First-appearance grouping и authoritative current `COMPLETED` merge
      ровно один раз с exact sum к совместимому `pilotExperienceGained`, без
      current-content, progression-total или archive-limit inference
- [x] Именные RU/EN XP chips и единая accessibility summary с legacy fallback
      на общий итог при отсутствии additive массива
- [x] Backend unit/API/PostgreSQL, Flutter parser/widget и compact text-scale
      1.6 coverage проверяют persisted copy, порядок, current merge, omission
      и invalid data

Milestone 31 продолжает post-alpha code-only gameplay track из ADR 0039 и не
меняет immutable `alpha-rc1`, schema, XP economy, topology или external
validation gates.

## Milestone 32 — Journey recap pilot experience breakdown

### CODE_COMPLETE

- [x] Additive ordered `pilotExperienceRewards[]` в current и recent journey
      recap из положительных persisted reward facts exact journey
- [x] First-appearance grouping по persisted `pilotId + pilotName` с exact sum
      к совместимому `pilotExperienceGained`
- [x] Полное omission при неполной historical identity, legacy generic
      fallback и fail-closed mobile validation additive данных
- [x] Именные RU/EN XP chips и единая accessibility summary в current и
      archived recap с compact text-scale 1.6 coverage
- [x] Backend unit/API/PostgreSQL и Flutter parser/widget/localization tests
      проверяют persisted copy, порядок, сумму, omission и invalid data

Milestone 32 продолжает post-alpha code-only gameplay track из ADR 0039 и не
меняет immutable `alpha-rc1`, schema, XP economy, progression, topology или
external validation gates.

## Milestone 33 — Journey recap completion time

### CODE_COMPLETE

- [x] Current и recent journey recap показывают completion time только из
      immutable `finalDecision.resolvedAt`, без client clock или current
      content inference
- [x] UTC instant переводится в локальную timezone устройства исключительно
      для presentation и форматируется по выбранной RU/EN locale
- [x] Видимый label и полная accessibility summary используют один текст, а
      legacy recap без финала не получает выдуманного timestamp
- [x] RU/EN widget и compact text-scale 1.6 coverage проверяют current,
      archived и legacy presentation без layout overflow

Milestone 33 продолжает post-alpha code-only gameplay track из ADR 0039 и не
меняет immutable `alpha-rc1`, backend/API/schema, rewards, topology, archive
limit или external validation gates.

## Milestone 34 — Saved decision times in journey logs

### CODE_COMPLETE

- [x] Каждая запись current decision log и раскрытой recent archive history
      показывает время только из immutable `decision.resolvedAt`
- [x] Persisted UTC instant переводится в локальную timezone устройства
      исключительно для presentation и форматируется по RU/EN locale
- [x] Видимый label и полная accessibility summary используют один текст без
      client clock, cache/Home-response time или duration inference
- [x] RU/EN widget и compact text-scale 1.6 coverage проверяют current и
      expanded archived decision entries без layout overflow

Milestone 34 продолжает post-alpha code-only gameplay track из ADR 0039 и не
меняет immutable `alpha-rc1`, backend/API/schema, persisted history, rewards,
topology, archive limit или external validation gates.

## Milestone 35 — Authoritative journey duration

### CODE_COMPLETE

- [x] Current и recent journey recap получают additive nullable
      `durationSeconds` как целые секунды между persisted start exact
      journey и immutable `finalDecision.resolvedAt`
- [x] Старт journey 1 берётся из initial cycle/progress creation,
      а journey 2+ — из immutable journey-start receipt `server_time`, без
      client clock, cache/Home-response time или current-content inference
- [x] Backend опускает duration при отсутствующем или более
      позднем старте; mobile принимает legacy omission и fail-closed
      отклоняет malformed, negative и duration без final decision
- [x] RU/EN current/archive labels и полные accessibility summaries
      переиспользуют одну строку; backend unit/API/PostgreSQL и
      Flutter parser/widget/localization coverage включают compact text 1.6

Milestone 35 продолжает post-alpha code-only gameplay track из ADR 0039 и не
меняет immutable `alpha-rc1`, schema, rewards/economy, progression,
topology, archive limit или external validation gates.

## Milestone 36 — Authoritative lifetime journey duration

### CODE_COMPLETE

- [x] Additive nullable `journeyChronicle.totalDurationSeconds` суммирует
      полную receipt-proven completed history без зависимости от пяти recent
      recaps
- [x] Journey 1 использует initial cycle/progress creation, journey 2+ — exact
      journey-start receipt, а final — последнюю immutable resolution exact
      journey; current authoritative `COMPLETED` объединяется ровно один раз
- [x] Любая missing или обратная included boundary опускает всё поле без
      partial total; mobile принимает legacy omission и fail-closed отклоняет
      malformed/negative value
- [x] RU/EN lifetime chip и полная accessibility summary переиспользуют один
      duration formatter; backend unit/API/PostgreSQL и Flutter
      parser/widget/localization coverage включают compact text 1.6

Milestone 36 продолжает post-alpha code-only gameplay track из ADR 0039 и не
меняет immutable `alpha-rc1`, schema, rewards/economy, progression, topology,
archive limit или external validation gates.

## Milestone 37 — Authoritative longest journey duration

### CODE_COMPLETE

- [x] Additive nullable `journeyChronicle.longestDurationSeconds` выбирает
      maximum полной receipt-proven completed history без зависимости от пяти
      recent recaps
- [x] Exact journey boundaries совпадают с lifetime total, а current
      authoritative `COMPLETED` сравнивается ровно один раз до следующего
      journey-start receipt
- [x] Любая missing или обратная included boundary опускает longest без
      partial maximum; поле публикуется только вместе с total, не превышает
      его и fail-closed валидируется mobile
- [x] RU/EN record chip и полная accessibility summary переиспользуют один
      duration formatter; backend unit/API/PostgreSQL и Flutter
      parser/widget/localization coverage включают compact text 1.6

Milestone 37 продолжает post-alpha code-only gameplay track из ADR 0039 и не
меняет immutable `alpha-rc1`, schema, rewards/economy, progression, topology,
archive limit или external validation gates.

## Milestone 38 — Authoritative average journey duration

### CODE_COMPLETE

- [x] Additive nullable `journeyChronicle.averageDurationSeconds` выводится из
      полной receipt-proven completed history без зависимости от пяти recent
      recaps
- [x] Service вычисляет floor `totalDurationSeconds / completedJourneyCount`
      после authoritative current `COMPLETED` merge, учитывая каждый путь
      ровно один раз
- [x] Omission lifetime total опускает average без partial/recent fallback;
      mobile принимает legacy omission и fail-closed валидирует exact
      floor-result
- [x] RU/EN average chip и полная accessibility summary переиспользуют один
      duration formatter; backend unit/API/PostgreSQL и Flutter
      parser/widget/localization coverage включают rounding и compact text 1.6

Milestone 38 продолжает post-alpha code-only gameplay track из ADR 0039 и не
меняет immutable `alpha-rc1`, schema, rewards/economy, progression, topology,
archive limit или external validation gates.

## Milestone 39 — Authoritative longest journey identity

### CODE_COMPLETE

- [x] Additive nullable `journeyChronicle.longestJourneyNumber` связывает
      lifetime duration record с конкретным receipt-proven journey
- [x] Historical winner выбирается по duration DESC, journey number ASC на
      полных exact boundaries без зависимости от пяти recent recaps
- [x] Current authoritative `COMPLETED` учитывается ровно один раз и заменяет
      record identity только при строго большей duration; incomplete boundary
      опускает identity вместе с duration fields
- [x] Mobile принимает legacy omission, fail-closed проверяет supplied
      identity, а RU/EN chip и accessibility называют journey и выдерживают
      compact text scale 1.6; backend unit/API/PostgreSQL и Flutter coverage
      фиксируют tie-break и current merge

Milestone 39 продолжает post-alpha code-only gameplay track из ADR 0039 и не
меняет immutable `alpha-rc1`, schema, rewards/economy, progression, topology,
archive limit или external validation gates.

## Milestone 40 — Authoritative longest journey completion time

### CODE_COMPLETE

- [x] Additive nullable `journeyChronicle.longestJourneyCompletedAt` связывает
      duration record с immutable final resolution exact winning journey
- [x] Historical timestamp выбирается одновременно с winner по duration DESC,
      journey number ASC на полной receipt-proven history
- [x] Current authoritative `COMPLETED` учитывается ровно один раз и заменяет
      record timestamp только при строго большей duration; incomplete boundary
      опускает timestamp вместе с duration fields и identity
- [x] Mobile принимает legacy omission, fail-closed проверяет supplied instant,
      а RU/EN chip и accessibility форматируют его в timezone устройства и
      выдерживают compact text scale 1.6; backend unit/API/PostgreSQL и Flutter
      coverage фиксируют tie-break, current merge и invalid data

Milestone 40 продолжает post-alpha code-only gameplay track из ADR 0039 и не
меняет immutable `alpha-rc1`, schema, rewards/economy, progression, topology,
archive limit или external validation gates.

## Milestone 41 — Authoritative shortest journey duration

### CODE_COMPLETE

- [x] Additive nullable `journeyChronicle.shortestDurationSeconds` выбирает
      minimum полной receipt-proven completed history без зависимости от пяти
      recent recaps
- [x] Exact boundaries совпадают с lifetime total, а current authoritative
      `COMPLETED` сравнивается ровно один раз до следующего journey-start receipt
- [x] Missing/reversed included boundary опускает shortest вместе с остальными
      lifetime duration fields; значение требует total и не превышает
      average/longest, когда они присутствуют
- [x] Mobile принимает legacy omission, fail-closed проверяет invalid data, а
      RU/EN chip и accessibility переиспользуют duration formatter и
      выдерживают compact text scale 1.6; backend unit/API/PostgreSQL и Flutter
      coverage фиксируют full history и current merge

Milestone 41 продолжает post-alpha code-only gameplay track из ADR 0039 и не
меняет immutable `alpha-rc1`, schema, rewards/economy, progression, topology,
archive limit или external validation gates.

## Milestone 42 — Authoritative shortest journey identity

### CODE_COMPLETE

- [x] Additive nullable `journeyChronicle.shortestJourneyNumber` связывает
      authoritative minimum duration с конкретным подтверждённым походом
- [x] Historical winner выбирается по duration ASC, journey number ASC на
      полной receipt-proven history с теми же exact boundaries
- [x] Current authoritative `COMPLETED` учитывается ровно один раз и заменяет
      shortest identity только при строго меньшей duration; tie сохраняет
      более ранний historical journey
- [x] Mobile принимает legacy omission, fail-closed проверяет paired positive
      identity в completed range, а RU/EN journey-aware chip и accessibility
      выдерживают compact text scale 1.6; backend unit/API/PostgreSQL и Flutter
      coverage фиксируют tie-break, current merge и invalid data

Milestone 42 продолжает post-alpha code-only gameplay track из ADR 0039 и не
меняет immutable `alpha-rc1`, schema, rewards/economy, progression, topology,
archive limit или external validation gates.

## Milestone 43 — Authoritative shortest journey completion time

### CODE_COMPLETE

- [x] Additive nullable `journeyChronicle.shortestJourneyCompletedAt`
      связывает minimum duration с immutable final resolution exact winner
- [x] Historical timestamp выбирается одновременно с winner по duration ASC,
      journey number ASC на полной receipt-proven history
- [x] Current authoritative `COMPLETED` учитывается ровно один раз и заменяет
      shortest timestamp только при строго меньшей duration; tie сохраняет
      historical winner, а incomplete boundary опускает всю duration family
- [x] Mobile принимает legacy omission, fail-closed проверяет paired UTC
      instant, а RU/EN chip и accessibility форматируют его в timezone
      устройства и выдерживают compact text scale 1.6; backend
      unit/API/PostgreSQL и Flutter coverage фиксируют winner и invalid data

Milestone 43 продолжает post-alpha code-only gameplay track из ADR 0039 и не
меняет immutable `alpha-rc1`, schema, rewards/economy, progression, topology,
archive limit или external validation gates.

## Milestone 44 — Non-punitive weekly activity rhythm

### CODE_COMPLETE

- [x] Additive `weeklyActivityRhythm` считает positive accepted activity на
      target local date и шести предыдущих датах без client/Health inference
- [x] Мягкая цель v1 равна четырём дням из семи; derived `targetReached`
      проверяется fail-closed, а пропуск дня не создаёт streak reset или penalty
- [x] Ритм не выдаёт ENERGY/rewards и не меняет daily goal, progression,
      topology, persistence schema или external validation status
- [x] Mobile принимает legacy omission, показывает RU/EN visible copy и одну
      accessibility summary, а compact text scale 1.6 остаётся без overflow;
      backend unit/API/PostgreSQL и Flutter parser/widget/localization coverage
      фиксируют authoritative window и invalid data

Milestone 44 продолжает post-alpha code-only gameplay track из ADR 0039 и
реализует раздел «Прогресс без наказания» product canon без изменения
immutable `alpha-rc1` или внешних gates.

## Milestone 45 — Authoritative weekly activity day trail

### CODE_COMPLETE

- [x] Additive `weeklyActivityRhythm.days` проецирует все семь локальных дат
      от target `localDate - 6` до target date в хронологическом порядке
- [x] Active marker выводится только из persisted positive accepted total;
      явный rest marker нейтрален и не создаёт streak reset, penalty или reward
- [x] Mobile принимает legacy weekly object без trail и fail-closed проверяет
      supplied length, даты, continuity, endpoint и соответствие `activeDays`
- [x] RU/EN markers объединены в одну accessibility summary и выдерживают
      compact text scale 1.6; backend unit/API/PostgreSQL и Flutter
      parser/widget/localization coverage фиксируют authoritative ряд

Milestone 45 продолжает non-punitive rhythm из ADR 0058 и post-alpha code-only
gameplay track из ADR 0039 без изменения schema, daily goal, rewards/economy,
progression, immutable `alpha-rc1` или внешних gates.

## Milestone 46 — Gentle weekly rhythm guidance

### CODE_COMPLETE

- [x] До достижения цели Home показывает остаток
      `max(targetActiveDays - activeDays, 0)` только из уже принятого
      server-authoritative weekly snapshot
- [x] RU/EN copy корректно различает singular/plural формы и сохраняет явную
      нормальность дней отдыха без streak, дедлайна или reward claim
- [x] После достижения цели остаётся reached/rest-normal copy без нулевой
      remaining-подсказки; legacy Home без weekly object не меняется
- [x] Видимый detail входит в одну полную accessibility summary, а RU/EN
      widget и compact text-scale 1.6 coverage фиксируют guidance и reflow

Milestone 46 завершает presentation feedback мягкого ритма из ADR 0060 без
изменения Home API, schema, Health history, daily goal, rewards/economy,
progression, immutable `alpha-rc1` или внешних gates.

## Milestone 47 — Authoritative today status in weekly rhythm

### CODE_COMPLETE

- [x] Mobile связывает today только с exact Home `localDate`, уже проверенной
      как endpoint authoritative seven-day trail, без device clock inference
- [x] RU/EN visible copy называет server-owned formatted date и active/rest
      status; rest остаётся нейтральным и не создаёт deadline или failure
- [x] Exact today marker получает тонкую non-warning primary outline, сохраняя
      исходный walking/rest glyph и tone
- [x] Today status входит в полную weekly semantics summary ровно один раз;
      legacy object без trail его не получает, а active/rest RU/EN и compact
      text-scale 1.6 widget coverage фиксируют presentation contract

Milestone 47 продолжает non-punitive rhythm из ADR 0061 без изменения Home
API, schema, Health history, daily goal, rewards/economy, progression,
immutable `alpha-rc1` или внешних gates.

## Milestone 48 — Authoritative weekly rhythm window range

### CODE_COMPLETE

- [x] Mobile показывает localized first/last dates только из уже
      валидированного complete `weeklyActivityRhythm.days`, без device clock
- [x] RU/EN line объясняет exact counted window и не превращает lower boundary
      в дедлайн, streak reset или future-state prediction
- [x] Legacy weekly object без trail не получает inferred range; Home API,
      backend и persistence schema не меняются
- [x] Range входит в единую weekly semantics summary ровно один раз, а RU/EN,
      legacy и compact text-scale 1.6 widget coverage фиксируют presentation

Milestone 48 продолжает non-punitive rhythm из ADR 0062 без изменения daily
goal, rewards/economy, progression, topology, immutable `alpha-rc1` или
внешних gates.

## Milestone 49 — Authoritative daily goal feedback

### CODE_COMPLETE

- [x] Mobile показывает non-negative remaining steps только из accepted Home
      `dailySteps` и `dailyGoal`, без Health history или client clock
- [x] RU/EN copy корректно различает step plural forms до цели и спокойное
      reached-состояние при равенстве или превышении без reward claim
- [x] Exact daily total и feedback объединены в одну semantics summary без
      duplicate visual announcement
- [x] Domain и widget coverage фиксируют below/exact/above goal и compact
      text-scale 1.6 без изменения Home API, backend или persistence

Milestone 49 продолжает post-alpha code-only gameplay track из ADR 0039 и
personal-goal boundary из ADR 0063 без изменения daily-goal calculation,
ENERGY/rewards, progression, immutable `alpha-rc1` или внешних gates.

## Milestone 50 — Weekly active-day qualification

### CODE_COMPLETE

- [x] RU/EN weekly copy явно отделяет любую accepted activity, которая делает
      день активным, от достижения personal daily goal
- [x] Clarification входит в существующую weekly semantics summary ровно один
      раз и не создаёт duplicate visual announcement
- [x] Legacy aggregate-only weekly object получает правило без inferred trail,
      dates или today status; Home без weekly object не меняется
- [x] RU/EN, semantics, legacy/absence и compact text-scale 1.6 widget coverage
      фиксируют no-client-inference и no-reward boundary

Milestone 50 продолжает non-punitive rhythm из ADR 0064 и post-alpha code-only
track из ADR 0039 без изменения API, persisted qualification rule, daily goal,
ENERGY/rewards, progression, immutable `alpha-rc1` или внешних gates.

## Milestone 51 — Daily-goal stability clarification

### CODE_COMPLETE

- [x] RU/EN copy для explicit DEFAULT/ADAPTIVE policy объясняет, что accepted
      steps текущей server-owned даты не повышают цель этой даты и могут
      учитываться в будущих целях
- [x] Clarification входит в существующую daily-goal semantics summary ровно
      один раз и не создаёт duplicate visual announcement
- [x] Legacy snapshot без policy metadata не получает inferred stability rule
- [x] Adaptive/default, RU/EN, semantics, legacy omission и compact text-scale
      1.6 widget coverage фиксируют no-client-calculation boundary

Milestone 51 продолжает adaptive-goal transparency из ADR 0065 и post-alpha
code-only track из ADR 0039 без изменения API, goal formula/configuration,
Health history, ENERGY/rewards, progression, immutable `alpha-rc1` или внешних
gates.

## Milestone 52 — Authoritative pilot level guidance

### CODE_COMPLETE

- [x] Mobile fail-closed валидирует accepted pilot level/current/next XP и
      выводит exact remaining с bounded `0...1` progress
- [x] RU/EN карточка объединяет current, target и remaining в одну нейтральную
      строку без client-owned threshold, level-up или reward promise
- [x] Visual progress исключён из semantics; exact state объявляется один раз,
      а legacy/internal invalid direct snapshot сохраняет literal fallback
- [x] Domain, RU/EN, semantics и compact text-scale 1.6 coverage фиксируют
      authoritative presentation boundary

Milestone 52 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative progression из ADR 0009 через ADR 0066 без изменения
Home API, backend, persistence, progression thresholds/rewards, immutable
`alpha-rc1` или внешних gates.

## Milestone 53 — Authoritative companion evolution guidance

### CODE_COMPLETE

- [x] Mobile выводит exact non-negative remaining bond только из accepted
      Platform pet state и server-authored evolution target
- [x] RU/EN guidance меняется только для growing state; ready и fully evolved
      сохраняют существующие состояния без fake next target
- [x] Companion bond semantics объявляет exact remaining один раз, а
      повторяющая visual line исключена из accessibility tree
- [x] Domain, RU/EN, semantics и compact text-scale 1.6 coverage фиксируют
      authoritative presentation boundary

Milestone 53 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative pet progression из ADR 0009 через ADR 0067 без изменения
Platform API, backend, persistence, evolution thresholds/commands/rewards,
immutable `alpha-rc1` или внешних gates.

## Milestone 54 — Authoritative skill unlock guidance

### CODE_COMPLETE

- [x] Mobile fail-closed валидирует non-negative server-authored skill XP
      requirement и выводит exact remaining только из accepted season XP
- [x] RU/EN remaining используется только для locked unavailable state;
      ready-to-unlock и unlocked copy/actions сохраняются
- [x] Exact visible guidance доступна assistive technologies один раз без
      client-owned threshold, progress indicator или reward promise
- [x] Domain, RU/EN, reached/unlocked и compact text-scale 1.6 coverage
      фиксируют authoritative presentation boundary

Milestone 54 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative Platform progression из ADR 0009 через ADR 0068 без
изменения Platform API, backend catalog, persistence, skill thresholds,
unlock commands/rewards, immutable `alpha-rc1` или внешних gates.

## Milestone 55 — Authoritative quest remaining guidance

### CODE_COMPLETE

- [x] Mobile выводит exact non-negative remaining только из accepted quest
      progress и server-authored target
- [x] RU/EN guidance используется для incomplete step/event metrics; ready и
      claimed состояния сохраняют прежние badges, rewards и actions
- [x] Squad и unknown metrics сохраняют literal progress без client-inferred
      units или completion rules
- [x] Exact remaining входит в одну semantics summary; domain, RU/EN,
      ready/fallback и compact text-scale 1.6 coverage фиксируют boundary

Milestone 55 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative Platform progression из ADR 0009 через ADR 0069 без
изменения Platform API, backend catalog, persistence, quest targets,
aggregation, rewards/claim commands, immutable `alpha-rc1` или внешних gates.

## Milestone 56 — Authoritative season reward guidance

### CODE_COMPLETE

- [x] Platform catalog публикует positive `season.xpPerLevel`, а backend
      reward validation, season level и milestone achievement используют один
      authoritative cadence
- [x] Mobile fail-closed принимает новый порог и выводит exact next reward
      level/remaining только из accepted season XP и catalog limits
- [x] RU/EN guidance не обещает reward contents; final level и legacy cached
      snapshot без поля не получают fake next target
- [x] Catalog/service, domain, RU/EN, semantics, legacy/final и compact
      text-scale 1.6 coverage фиксируют additive contract

Milestone 56 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative Platform progression из ADR 0009 через ADR 0070 без
изменения persistence, reward payload/command, immutable `alpha-rc1` или
внешних gates.

## Milestone 57 — Authoritative achievement collection guidance

### CODE_COMPLETE

- [x] Mobile считает открытыми только stable IDs из accepted achievement
      catalog, присутствующие в accepted user achievement set
- [x] Dynamic season-reward receipt IDs и будущие non-catalog IDs не искажают
      catalog collection count и не отклоняются как malformed state
- [x] RU/EN guidance показывает exact remaining или спокойное complete state
      без unlock-rule, срока или reward promise
- [x] Aggregate progress и guidance объявляются одной semantics summary;
      domain, RU/EN и compact text-scale 1.6 coverage фиксируют boundary

Milestone 57 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative Platform projection из ADR 0009 через ADR 0071 без
изменения Platform API, backend catalog, achievement rules/rewards,
immutable `alpha-rc1` или внешних gates.

## Milestone 58 — Authoritative first-journey remaining guidance

### CODE_COMPLETE

- [x] Mobile считает завершёнными только accepted onboarding catalog IDs,
      присутствующие в accepted completed set
- [x] Retired и будущие non-catalog IDs не искажают progress
- [x] RU/EN guidance показывает exact remaining или спокойное complete state
      без срока, unlock-rule или reward promise
- [x] Progress и guidance объявляются одной route semantics summary; domain,
      RU/EN и compact text-scale 1.6 coverage фиксируют boundary

Milestone 58 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative Platform projection из ADR 0009 через ADR 0072 без
изменения Platform API, backend, onboarding order/rules, resume command,
immutable `alpha-rc1` или внешних gates.

## Milestone 59 — Authoritative claimable season reward count

### CODE_COMPLETE

- [x] Mobile получает earned boundary только из accepted season XP, positive
      catalog `xpPerLevel` и final level
- [x] Accepted `season-reward-N` receipts исключают полученные уровни, а
      unrelated achievement IDs не искажают count
- [x] Положительный count получает RU/EN singular/plural guidance; zero и
      legacy cadence-absent states не получают fake guidance
- [x] Existing first-unclaimed claim action сохраняется; domain, semantics,
      RU/EN и compact text-scale 1.6 coverage фиксируют boundary

Milestone 59 продолжает post-alpha code-only gameplay track из ADR 0039 и
authoritative season cadence из ADR 0070 через ADR 0073 без изменения Platform
API, backend, persistence, reward payload/order, claim command, immutable
`alpha-rc1` или внешних gates.

## Milestone 60 — Authoritative cosmetic collection guidance

### CODE_COMPLETE

- [x] Mobile считает owned только как пересечение accepted cosmetic catalog и
      accepted owned IDs
- [x] RU/EN guidance показывает exact remaining или спокойный complete state
- [x] Aggregate progress объявляется одной semantics summary
- [x] Domain, RU/EN и compact large-text coverage фиксируют boundary без
      изменения prices, purchase/equip commands или ownership rules

Milestone 60 продолжает post-alpha code-only gameplay track из ADR 0039 без
изменения Platform API, backend, persistence, commerce, immutable `alpha-rc1`
или внешних gates.

## Milestone 61 — Authoritative pilot skill collection guidance

### CODE_COMPLETE

- [x] Mobile считает unlocked только как пересечение accepted skill catalog и
      accepted unlocked IDs
- [x] RU/EN guidance показывает exact remaining или спокойный complete state
- [x] Aggregate progress объявляется одной semantics summary
- [x] Domain, RU/EN и compact large-text coverage фиксируют boundary без
      изменения thresholds, availability, unlock command или rewards

Milestone 61 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative Platform progression из ADR 0009 через ADR 0075 без
изменения Platform API, backend, persistence, immutable `alpha-rc1` или
внешних gates.

## Milestone 62 — Authoritative claimable quest reward count

### CODE_COMPLETE

- [x] Mobile считает claimable только accepted quests с ready и без claimed
- [x] Positive count получает RU/EN singular/plural guidance, zero не создаёт
      отдельного сообщения
- [x] Visible aggregate объявляется одной semantics node
- [x] Domain, RU/EN и compact large-text coverage фиксируют boundary без
      изменения progress, targets, rewards/order или claim command

Milestone 62 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative quest projection из ADR 0009 через ADR 0076 без изменения
Platform API, backend, persistence, immutable `alpha-rc1` или внешних gates.

## Milestone 63 — Authoritative unlockable pilot skill count

### CODE_COMPLETE

- [x] Mobile считает unlockable только accepted catalog skills, которых нет в
      accepted unlocked set и чей server-authored XP threshold уже достигнут
- [x] Positive count получает RU/EN singular/plural guidance, zero не создаёт
      отдельного сообщения
- [x] Visible aggregate объявляется одной semantics node
- [x] Domain, RU/EN и compact large-text coverage фиксируют boundary без
      изменения thresholds, availability rules, unlock command или rewards

Milestone 63 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative skill projection из ADR 0009 через ADR 0077 без изменения
Platform API, backend, persistence, immutable `alpha-rc1` или внешних gates.

## Milestone 64 — Authoritative evolvable companion count

### CODE_COMPLETE

- [x] Mobile считает ready только accepted pets, для которых существующая
      domain-проекция `canEvolve` истинна
- [x] Growing и fully evolved pets не входят в count
- [x] Positive count получает RU/EN singular/plural guidance и одну semantics
      node, zero не создаёт отдельного сообщения
- [x] Domain, RU/EN и compact large-text coverage фиксируют boundary без
      изменения bond thresholds, stages, evolution command или rewards

Milestone 64 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative companion progression из ADR 0009 через ADR 0078 без
изменения Platform API, backend, persistence, immutable `alpha-rc1` или
внешних gates.

## Milestone 65 — Authoritative equippable cosmetic count

### CODE_COMPLETE

- [x] Mobile считает ready только accepted catalog cosmetics, которые есть в
      accepted owned set и отсутствуют в accepted equipped IDs
- [x] Equipped, unowned и retired/non-catalog cosmetics не входят в count
- [x] Positive count получает RU/EN singular/plural guidance и одну semantics
      node, zero не создаёт отдельного сообщения
- [x] Domain, RU/EN и compact large-text coverage фиксируют boundary без
      изменения prices, purchase availability, slots или equip command

Milestone 65 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative cosmetic slots из ADR 0032 через ADR 0079 без изменения
Platform API, backend, persistence, commerce, immutable `alpha-rc1` или
внешних gates.

## Milestone 66 — Authoritative craftable recipe count

### CODE_COMPLETE

- [x] Mobile считает ready только accepted crafting recipes с server-authored
      `status == READY`
- [x] `MISSING_MATERIALS` и `CRAFTED` не входят в count; client material
      quantities не используются для повторного вывода availability
- [x] Positive count получает RU/EN singular/plural guidance и одну semantics
      node, zero не создаёт отдельного сообщения
- [x] Domain, RU/EN и compact large-text coverage фиксируют boundary без
      изменения recipes, material costs, rewards или craft command

Milestone 66 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative crafting из ADR 0029 через ADR 0080 без изменения Home
API, backend, persistence, crafting economy, immutable `alpha-rc1` или внешних
gates.

## Milestone 67 — Authoritative ready item upgrade count

### CODE_COMPLETE

- [x] Mobile считает ready только accepted item upgrades с server-authored
      `status == READY`
- [x] `LOCKED`, `MISSING_MATERIALS` и `COMPLETED` не входят в count; item,
      level, rarity и ingredient quantities не используются для повторного
      вывода availability
- [x] Positive count получает RU/EN singular/plural guidance и одну semantics
      node, zero не создаёт отдельного сообщения
- [x] Domain, RU/EN, post-upgrade и compact large-text coverage фиксируют
      boundary без изменения upgrades, material costs или apply command

Milestone 67 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative item upgrades из ADR 0029 через ADR 0081 без изменения
Home API, backend, persistence, upgrade economy, immutable `alpha-rc1` или
внешних gates.

## Milestone 68 — Authoritative equippable inventory item count

### CODE_COMPLETE

- [x] Mobile считает ready только accepted inventory items, для которых
      существующая projection `isEquippable` истинна, а `isEquipped` ложна
- [x] Materials/non-equippable и equipped items не входят в count; slot state,
      kind, rarity и level не используются для повторного вывода availability
- [x] Positive count получает RU/EN singular/plural guidance и одну semantics
      node, zero не создаёт отдельного сообщения
- [x] Domain, RU/EN, post-equip и compact large-text coverage фиксируют
      boundary без изменения equipment slots, routes или equip command

Milestone 68 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative equipment из ADR 0030 через ADR 0082 без изменения Home
API, backend, persistence, route requirements, immutable `alpha-rc1` или
внешних gates.

## Milestone 69 — Authoritative available expedition choice count

### CODE_COMPLETE

- [x] Mobile считает available только accepted choices текущего unresolved
      event с существующим `availability == AVAILABLE`
- [x] `LOCKED` choices не входят в count; equipment, item level, active pet,
      evolution stage и unlocked skills не используются для повторного вывода
      availability
- [x] Positive count получает RU/EN singular/plural guidance и одну semantics
      node, zero и resolved event не создают отдельного сообщения
- [x] Domain, RU/EN, mixed availability и compact large-text coverage фиксируют
      boundary без изменения event topology, requirements или resolve command

Milestone 69 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative event availability из ADR 0030 через ADR 0083 без
изменения Home API, backend, persistence, rewards, immutable `alpha-rc1` или
внешних gates.

## Milestone 70 — Authoritative equipped slot progress

### CODE_COMPLETE

- [x] Mobile считает equipped только accepted equipment slots с существующим
      `status == EQUIPPED`, а total — длиной accepted equipment list
- [x] Inventory, item kind, compatibility, route requirements и client
      ownership rules не используются для повторного вывода occupancy
- [x] RU/EN guidance показывает exact `equipped / total`, включая zero, и
      объявляется одной semantics node
- [x] Domain, RU/EN, equip/unequip и compact large-text coverage фиксируют
      boundary без изменения slot catalog, compatibility или equip command

Milestone 70 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative equipment из ADR 0030 через ADR 0084 без изменения Home
API, backend, persistence, route requirements, immutable `alpha-rc1` или
внешних gates.

## Milestone 71 — Authoritative discovered route node count

### CODE_COMPLETE

- [x] Mobile считает открытыми ровно accepted элементы текущего `routeTrail`
- [x] Future topology, total узлов, проценты и route requirements не выводятся
- [x] Непустой trail получает видимую RU/EN строку, а существующая route
      semantics остаётся единственным accessibility summary
- [x] Domain, legacy-empty, RU/EN и compact large-text coverage фиксируют
      boundary без изменения Home API, backend или route state

Milestone 71 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative current-journey state из ADR 0038 через ADR 0085 без
изменения Home API, backend, persistence, future topology, immutable
`alpha-rc1` или внешних gates.

## Milestone 72 — Authoritative current-journey decision count

### CODE_COMPLETE

- [x] Mobile считает решениями ровно accepted элементы текущего `decisionLog`
- [x] Route trail, event state, rewards и completion не используются для
      повторного вывода решений
- [x] Непустой журнал получает видимую RU/EN строку; legacy/empty state
      сохраняет существующую подсказку без zero-count шума
- [x] Domain, RU, legacy-empty и compact English large-text coverage фиксируют
      boundary без изменения Home API, backend или event resolution

Milestone 72 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative current-journey state из ADR 0038 через ADR 0086 без
изменения Home API, backend, persistence, event ordering, immutable
`alpha-rc1` или внешних gates.

## Milestone 73 — Latest accepted current-journey decision

### CODE_COMPLETE

- [x] Mobile выбирает только последний элемент accepted `decisionLog`
- [x] Server list ordering сохраняется без сортировки по `resolvedAt`, join с
      `routeTrail` или вывода event completion
- [x] Непустой журнал показывает literal event/outcome и accepted save time в
      RU/EN; legacy/empty state не создаёт fake latest summary
- [x] Domain, RU/EN semantics и compact large-text coverage фиксируют boundary
      без изменения Home API, backend, persistence или event resolution

Milestone 73 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative current-journey state из ADR 0038 через ADR 0087 без
изменения rewards, immutable `alpha-rc1` или внешних gates.

## Milestone 74 — Latest accepted current-journey choice

### CODE_COMPLETE

- [x] Summary использует literal `choiceTitle` только из последнего элемента
      accepted `decisionLog`
- [x] Mobile не выводит choice availability, correctness или consequences и не
      соединяет запись с `routeTrail` или текущим event state
- [x] RU/EN summary и единая semantics node показывают accepted choice рядом с
      event/outcome/save time
- [x] Domain, legacy-empty и compact large-text coverage фиксируют boundary без
      изменения Home API, backend, persistence, rewards или event resolution

Milestone 74 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative current-journey state из ADR 0038 через ADR 0088 без
изменения immutable `alpha-rc1` или внешних gates.

## Milestone 75 — Latest accepted current-journey outcome summary

### CODE_COMPLETE

- [x] Summary использует literal `outcomeSummary` только из последнего
      элемента accepted `decisionLog`
- [x] Mobile не интерпретирует последствия, не агрегирует rewards и не
      соединяет запись с `routeTrail` или текущим event state
- [x] RU/EN summary и единая semantics node показывают accepted description
      рядом с event/choice/outcome/save time
- [x] Domain, legacy-empty и compact large-text coverage фиксируют boundary без
      изменения Home API, backend, persistence или event resolution

Milestone 75 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative current-journey state из ADR 0038 через ADR 0089 без
изменения rewards, immutable `alpha-rc1` или внешних gates.

## Milestone 76 — Latest accepted current-journey rewards

### CODE_COMPLETE

- [x] Summary использует persisted reward fields только последнего элемента
      accepted `decisionLog`
- [x] Mobile не агрегирует rewards между решениями, не пересчитывает economy и
      не соединяет запись с текущим state
- [x] RU/EN summary и единая semantics node показывают pilot XP, pet bond и
      material reward существующими reward labels
- [x] Domain, legacy/no-reward и compact large-text coverage фиксируют boundary
      без изменения Home API, backend, persistence или event resolution

Milestone 76 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative current-journey state из ADR 0038 через ADR 0090 без
изменения immutable `alpha-rc1` или внешних gates.

## Milestone 77 — Authoritative current-journey start time

### CODE_COMPLETE

- [x] Home публикует additive nullable `expedition.startedAt` из persisted
      journey-start source exact текущего `journeyNumber`
- [x] Backend не выводит start из decisions, content или request/response time
- [x] RU/EN journal форматирует server timestamp как locale-aware date/time без
      client elapsed-duration calculation
- [x] API/domain/legacy/malformed и compact large-text coverage фиксируют
      boundary без изменения persistence, rewards или event resolution

Milestone 77 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative journey history из ADR 0038 через ADR 0091 без изменения
immutable `alpha-rc1` или внешних gates.

## Milestone 78 — Authoritative current-journey phase

### CODE_COMPLETE

- [x] Mobile принимает literal `expedition.status` только из accepted набора
      `IN_PROGRESS`, `EVENT_READY`, `COMPLETED`
- [x] Energy, route trail, decision log, unlocked event и completion recap не
      используются для повторного вывода phase
- [x] RU/EN journal показывает одну visible phase label и одну semantics node
- [x] Domain, три status state и compact large-text coverage фиксируют boundary
      без изменения Home API, backend, persistence или commands

Milestone 78 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative current-journey state из ADR 0038 через ADR 0092 без
изменения immutable `alpha-rc1` или внешних gates.

## Milestone 79 — Authoritative current-journey position

### CODE_COMPLETE

- [x] Journal использует accepted `currentNodeId/currentNode` как единственный
      source текущей position
- [x] Known mutable node локализуется по stable ID, unknown future node
      сохраняет literal server fallback
- [x] Route trail, decision log, phase и unlocked event не используются для
      повторного выбора position
- [x] RU/EN semantics, future fallback и compact large-text coverage фиксируют
      boundary без изменения Home API, backend, persistence или commands

Milestone 79 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative current-journey state из ADR 0038 через ADR 0093 без
изменения immutable `alpha-rc1` или внешних gates.

## Milestone 80 — Authoritative current-journey ENERGY progress

### CODE_COMPLETE

- [x] Journal использует accepted `expedition.progress/requiredEnergy` как
      единственный source ENERGY progress текущего похода
- [x] RU/EN copy сохраняет literal accepted integers, а только visual
      indicator ограничивается диапазоном `0..1`
- [x] Phase, decision availability, completion, rewards, spendability и
      command eligibility не выводятся из отношения progress/target
- [x] Domain, semantics, over-target и compact large-text coverage фиксируют
      boundary без изменения Home API, backend, persistence или commands

Milestone 80 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative current-journey state из ADR 0038 через ADR 0094 без
изменения immutable `alpha-rc1` или внешних gates.

## Milestone 81 — Authoritative current-journey READY event

### CODE_COMPLETE

- [x] Journal показывает только accepted `unlockedEvent` со status exact
      `READY`
- [x] Known mutable event title локализуется по stable `eventId`, unknown
      future ID сохраняет literal server fallback
- [x] Absent, `RESOLVED` и unknown status fail-closed не создают event label;
      соседние journey facts не подменяют event
- [x] RU/EN semantics, known/future/non-ready и compact large-text coverage
      фиксируют boundary без изменения Home API, backend или commands

Milestone 81 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative current-journey state из ADR 0038 через ADR 0095 без
изменения immutable `alpha-rc1` или внешних gates.

## Milestone 82 — Authoritative current-journey READY event summary

### CODE_COMPLETE

- [x] Journal показывает summary только accepted `unlockedEvent` со status
      exact `READY`
- [x] Known mutable summary локализуется по stable `eventId`, unknown future ID
      сохраняет literal server fallback
- [x] Absent, `RESOLVED` и unknown status fail-closed не создают event block;
      соседние journey facts не подменяют summary
- [x] RU/EN title и summary принадлежат одной semantics node; known/future,
      non-ready и compact large-text coverage фиксируют boundary

Milestone 82 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative current-journey state из ADR 0038 через ADR 0096 без
изменения immutable `alpha-rc1` или внешних gates.

## Milestone 83 — Authoritative current-journey READY choice count

### CODE_COMPLETE

- [x] Journal показывает positive available-choice count только accepted
      `unlockedEvent` со status exact `READY`
- [x] Count использует server-owned choice `availability`, исключает locked
      choices и не проверяет requirements повторно
- [x] Legacy/empty, locked-only, absent, `RESOLVED` и unknown status не создают
      count; соседние journey facts и catalog rules не восстанавливают choices
- [x] RU/EN plurals, одна event semantics node и compact large-text coverage
      фиксируют boundary без journal actions, API/backend или command changes

Milestone 83 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative current-journey state из ADR 0038 через ADR 0097 без
изменения immutable `alpha-rc1` или внешних gates.

## Milestone 84 — Authoritative current-journey READY choice titles

### CODE_COMPLETE

- [x] Journal показывает accepted available choice titles только для
      `unlockedEvent` со status exact `READY`
- [x] Mobile сохраняет server ordering, исключает locked choices и не
      проверяет requirements повторно
- [x] Known mutable title локализуется по stable event/choice IDs, unknown
      future ID сохраняет literal server fallback
- [x] RU/EN, ordering, future fallback, non-ready и compact large-text coverage
      фиксируют одну event semantics node без journal actions или API changes

Milestone 84 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative current-journey state из ADR 0038 через ADR 0098 без
изменения immutable `alpha-rc1` или внешних gates.

## Milestone 85 — Authoritative current-journey READY choice descriptions

### CODE_COMPLETE

- [x] Journal показывает accepted description рядом с title каждого available
      choice только для `unlockedEvent` со status exact `READY`
- [x] Mobile сохраняет pairing и server ordering, исключает locked choices и
      не проверяет requirements повторно
- [x] Known mutable description локализуется по stable event/choice IDs,
      unknown future ID сохраняет literal server fallback
- [x] RU/EN, ordering, future fallback, non-ready и compact large-text coverage
      фиксируют одну event semantics node без rewards, requirements или actions

Milestone 85 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative current-journey state из ADR 0038 через ADR 0099 без
изменения immutable `alpha-rc1` или внешних gates.

## Milestone 86 — Authoritative current-journey READY choice rewards

### CODE_COMPLETE

- [x] Journal показывает accepted XP пилота, связь спутника и optional
      material рядом с каждой available READY choice
- [x] Mobile сохраняет pairing и server ordering, исключает locked choices,
      не проверяет requirements и не агрегирует rewards между choices
- [x] Accepted integers и material quantity сохраняются буквально; known item
      name локализуется по stable ID, unknown future ID сохраняет fallback
- [x] RU/EN, zero values, ordering, material fallback, non-ready и compact
      large-text coverage фиксируют одну semantics node без actions/outcomes

Milestone 86 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative current-journey state из ADR 0038 через ADR 0100 без
изменения immutable `alpha-rc1` или внешних gates.

## Milestone 87 — Authoritative current-journey READY choice requirements

### CODE_COMPLETE

- [x] Journal показывает optional accepted requirement description рядом с
      каждой available READY choice
- [x] Mobile сохраняет pairing и server ordering, исключает locked choices и
      не вычисляет eligibility или requirement satisfaction повторно
- [x] Known mutable requirement локализуется по stable event/choice IDs,
      unknown future ID сохраняет literal server fallback
- [x] RU/EN, optional, ordering, future fallback, locked/non-ready и compact
      large-text coverage фиксируют одну semantics node без actions/outcomes

Milestone 87 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative current-journey state из ADR 0038 через ADR 0101 без
изменения immutable `alpha-rc1` или внешних gates.

## Milestone 88 — Authoritative current-journey expedition identity

### CODE_COMPLETE

- [x] Journal показывает имя экспедиции только из accepted
      `expeditionId/expeditionName` текущего Home snapshot
- [x] Known `starter-expedition-v1` локализуется через existing RU/EN stable-ID
      resolver, unknown future ID сохраняет literal server fallback
- [x] Route trail, current node, READY event и local catalog не подменяют
      accepted expedition identity
- [x] Одна visible label и dedicated semantics node имеют RU/EN и compact
      large-text coverage без API/backend/persistence/command changes

Milestone 88 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative current-journey state из ADR 0038 через ADR 0102 без
изменения immutable `alpha-rc1` или внешних gates.

## Milestone 89 — Authoritative current-journey active companion

### CODE_COMPLETE

- [x] Journal показывает active companion только из accepted Home
      `petId/petName`
- [x] Known companion ID локализуется через existing RU/EN stable-ID resolver,
      legacy missing ID и unknown future ID сохраняют literal server fallback
- [x] Platform active pet, route trail, READY requirement, decision reward и
      local catalog state не подменяют accepted Home companion identity
- [x] Одна visible label и dedicated semantics node имеют RU/EN и compact
      large-text coverage без API/backend/persistence/command changes

Milestone 89 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative current-journey state из ADR 0038 через ADR 0103 без
изменения immutable `alpha-rc1` или внешних gates.

## Milestone 90 — Authoritative current-journey pilot identity

### CODE_COMPLETE

- [x] Journal показывает пилота только из accepted Home `pilotId/pilotName`
- [x] Known pilot ID локализуется через existing RU/EN stable-ID resolver,
      legacy missing ID и unknown future ID сохраняют literal server fallback
- [x] Platform hero, route/event/requirement/reward facts, completion history и
      local catalog state не подменяют accepted Home pilot identity
- [x] Одна visible label и dedicated semantics node имеют RU/EN и compact
      large-text coverage без API/backend/persistence/command changes

Milestone 90 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative current-journey state из ADR 0038 через ADR 0104 без
изменения immutable `alpha-rc1` или внешних gates.

## Milestone 91 — Authoritative current-journey pilot progression

### CODE_COMPLETE

- [x] Journal показывает pilot level/current/target только из accepted Home
      progression и remaining из existing Home getter
- [x] Platform season XP, decision rewards, completion/chronicle totals и local
      content не подменяют accepted Home progression
- [x] Legacy direct snapshot без valid progression не показывает ложные
      значения `0 / 0`
- [x] Одна optional visible label и dedicated semantics node имеют RU/EN и
      compact large-text coverage без API/backend/persistence/command changes

Milestone 91 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative current-journey state из ADR 0038 через ADR 0105 без
изменения immutable `alpha-rc1` или внешних gates.

## Milestone 92 — Authoritative current-journey companion progression

### CODE_COMPLETE

- [x] Journal показывает companion level/bond только из accepted Home active
      companion state
- [x] Platform pet progression, decision rewards, completion/chronicle totals и
      local catalog state не подменяют accepted Home facts
- [x] Label не агрегирует rewards и не прогнозирует level/evolution
- [x] Одна visible label и dedicated semantics node имеют RU/EN и compact
      large-text coverage без API/backend/persistence/command changes

Milestone 92 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative current-journey state из ADR 0038 через ADR 0106 без
изменения immutable `alpha-rc1` или внешних gates.

## Milestone 93 — Authoritative current-journey companion form

### CODE_COMPLETE

- [x] Journal показывает species/evolution form только из optional accepted
      Home active companion state и fail-closed скрывает неполную пару
- [x] Known pet ID локализует species, legacy/unknown ID сохраняет literal
      Home fallback, а accepted stage использует existing RU/EN form resolver
- [x] Platform active pet, local catalog и evolution thresholds/forecasts не
      подменяют accepted Home facts
- [x] Одна optional visible label и dedicated semantics node имеют RU/EN,
      future fallback, legacy omission и compact large-text coverage без
      API/backend/persistence/command changes

Milestone 93 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative current-journey state из ADR 0038 через ADR 0107 без
изменения immutable `alpha-rc1` или внешних gates.

## Milestone 94 — Authoritative current-journey companion portrait

### CODE_COMPLETE

- [x] Journal показывает stage-aware portrait только из полной accepted Home
      группы `petId/name/species/evolutionStage` и fail-closed скрывает его при
      отсутствии любого portrait input
- [x] Known pet ID выбирает existing illustrated stage asset, unknown future ID
      сохраняет design-system fallback без нового content mapping
- [x] Platform active pet, cosmetics, rewards, local catalog и evolution
      thresholds/forecasts не подменяют accepted Home portrait
- [x] Одна dedicated image semantics node использует RU/EN current-content
      name/species/form, исключает duplicate child semantics и выдерживает
      compact large-text layout без API/backend/persistence/command changes

Milestone 94 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative current-journey state из ADR 0038 через ADR 0108 без
изменения immutable `alpha-rc1` или внешних gates.

## Milestone 95 — Authoritative current-journey pilot portrait

### CODE_COMPLETE

- [x] Journal показывает existing illustrated pilot portrait только для exact
      accepted Home `pilotId == navigator-v1` и локализует accepted name через
      current-content RU/EN resolver
- [x] Legacy missing ID и unknown future ID сохраняют literal text fallback,
      но fail-closed не получают ложный Navigator artwork
- [x] Platform hero progression, cosmetics, rewards, history и local catalog не
      подменяют accepted Home pilot portrait
- [x] Pilot и companion portraits образуют compact wrapping crew row с двумя
      независимыми dedicated image semantics nodes без duplicate child
      semantics или API/backend/persistence/command changes

Milestone 95 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative current-journey state из ADR 0038 через ADR 0109 без
изменения immutable `alpha-rc1` или внешних gates.

## Milestone 96 — Authoritative current-journey route trail

### CODE_COMPLETE

- [x] Journal показывает existing code-native route map только из ordered
      accepted Home `routeTrail`, сохраняя literal node state и optional
      decision pairing
- [x] Known node ID локализует mutable name через existing RU/EN resolver,
      unknown future ID сохраняет literal Home fallback
- [x] Persisted choice/outcome copy остаётся literal; journal не соединяет
      trail с `decisionLog`, READY event, Platform weekly route, history или
      local catalog и fail-closed скрывает empty/legacy trail
- [x] Видимый accepted discovered-node count не дублирует одну localized route
      semantics summary, а horizontal map выдерживает compact large text без
      API/backend/persistence/command changes

Milestone 96 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative current-journey state из ADR 0038 через ADR 0110 без
изменения immutable `alpha-rc1` или внешних gates.

## Milestone 97 — Authoritative current-journey node landmark

### CODE_COMPLETE

- [x] Journal показывает existing code-native node landmark только из accepted
      Home `currentNodeId/currentNode` и локализует known mutable name через
      existing RU/EN stable-ID resolver
- [x] Exact known ID выбирает landmark artwork, unknown future ID сохраняет
      literal Home name и использует existing neutral fallback
- [x] Completed styling следует только accepted expedition `COMPLETED`; route
      terminal, READY event, Platform progression/history и local catalog не
      подменяют identity или status
- [x] Landmark и visible current-position label остаются внутри одной existing
      semantics node без duplicate announcement и выдерживают compact large
      text без API/backend/persistence/command changes

Milestone 97 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative current-journey state из ADR 0038 через ADR 0111 без
изменения immutable `alpha-rc1` или внешних gates.

## Milestone 98 — Authoritative current-journey expedition progress signal

### CODE_COMPLETE

- [x] Journal показывает existing code-native progress trace только из
      accepted Home `expeditionId/progress/requiredEnergy`
- [x] Exact known expedition ID выбирает reviewed contour, unknown future ID
      использует existing neutral field без mapping по display name
- [x] Literal ENERGY copy сохраняет accepted integers, включая over-target;
      clamp применяется только к painted trace без вывода gameplay state
- [x] Platform weekly route, route/current-node, READY event, decisions,
      history и catalog не подменяют identity или progress, а existing ENERGY
      semantics остаётся единственной и выдерживает compact large text без
      API/backend/persistence/command changes

Milestone 98 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative current-journey state из ADR 0038 через ADR 0112 без
изменения immutable `alpha-rc1` или внешних gates.

## Milestone 99 — Authoritative current-journey READY event scene

### CODE_COMPLETE

- [x] Journal показывает existing expedition scene только из accepted Home
      `unlockedEvent` со status exact `READY`
- [x] Known event ID и localized current title выбирают reviewed illustration;
      unknown future ID сохраняет literal copy и neutral code-native fallback
- [x] Expedition phase, current node, route trail, ENERGY, decisions, Platform
      event/progression, history и catalog не подменяют identity или readiness,
      а non-READY event fail-closed не показывает scene
- [x] Scene остаётся внутри одной existing event semantics node без duplicate
      image announcement и выдерживает RU/EN compact large text без
      API/backend/persistence/command/asset changes

Milestone 99 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative current-journey state из ADR 0038 через ADR 0113 без
изменения immutable `alpha-rc1` или внешних gates.

## Milestone 100 — Authoritative current-journey READY choice signals

### CODE_COMPLETE

- [x] Journal показывает existing choice signal для каждого accepted available
      choice только внутри accepted Home event со status exact `READY`
- [x] Только exact reviewed pair `eventId + choiceId` выбирает known mark;
      unknown future pair, включая знакомый choice ID другого event, остаётся
      neutral без dispatch по copy
- [x] Signals сохраняют accepted server ordering и pairing title, description,
      optional requirement и reward; locked/non-READY choice state, Platform,
      route, history и catalog не подменяют identity или availability
- [x] Signals остаются внутри одной existing READY-event semantics node без
      duplicate announcement или actions и выдерживают RU/EN compact large
      text без API/backend/persistence/command/asset changes

Milestone 100 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative current-journey state из ADR 0038 через ADR 0114 без
изменения immutable `alpha-rc1` или внешних gates.

## Milestone 101 — Authoritative current-journey READY choice material art

### CODE_COMPLETE

- [x] Journal показывает existing item emblem только для accepted optional
      material preview каждого available choice accepted Home READY event
- [x] Exact reviewed `materialReward.itemId` выбирает known asset/code-native
      art, unknown future ID использует neutral fallback без dispatch по name,
      quantity, reward copy или catalog
- [x] Emblem остаётся paired trailing visual того же choice signal в accepted
      server order; absent material, locked/non-READY state, Platform inventory,
      route и history не подменяют presence или identity
- [x] Material art остаётся внутри одной existing READY-event semantics node
      без duplicate image announcement или actions и выдерживает RU/EN compact
      large text без API/backend/persistence/command/asset changes

Milestone 101 продолжает post-alpha code-only gameplay track из ADR 0039 и
server-authoritative current-journey state из ADR 0038 через ADR 0115 без
изменения immutable `alpha-rc1` или внешних gates.

## Exit criteria autonomous scope

- standard CI и Release quality зелёные;
- migrations/upgrade tests зелёные;
- документация и API соответствуют коду;
- временных transport-файлов нет;
- внешние gates имеют protocol/checklist/evidence и не отмечены ложным `VALIDATED`.

### Mobile OIDC session lifecycle

- [x] Authorization Code + PKCE boundary and secure token storage.
- [x] Bearer-only same-origin transport with one refresh/retry after 401.
- [x] Reauthentication, account switching and owner-scoped local cleanup.
- [x] Runtime shutdown barrier before logout cleanup.
- [x] Fresh OIDC login for destructive account actions with same-owner
      validation and server-side signed `auth_time` enforcement.
- [x] Mobile export/share and idempotent account-deletion receipt flow.
- [ ] Configure the production identity provider, client, issuer, audience and
      signed `device_id` claim in the deployment environment.
- [ ] Validate login, refresh and logout on physical Android/iOS devices.
