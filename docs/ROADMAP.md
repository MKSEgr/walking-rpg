# Roadmap

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
