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
- [x] Три питомца, active selection и эволюция
- [x] Навыки, задания, достижения и onboarding
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
- [x] Cosmetic catalog/shop
- [x] Payment-provider boundary + sandbox provider
- [x] A/B assignment и exposure logging
- [x] Release candidate CI и store review checklist
- [x] Mobile OIDC Authorization Code + PKCE, secure session storage, refresh и logout
- [ ] Production identity-provider client/redirect configuration — EXTERNAL_VALIDATION_REQUIRED
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
