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

### EXTERNAL_VALIDATION_REQUIRED

- [ ] iPhone без Apple Watch
- [ ] iPhone + Apple Watch
- [ ] Android + несколько Health Connect providers
- [ ] Ручной ввод, удаление/коррекция и отзыв разрешения
- [ ] Timezone/midnight
- [ ] Battery/background evidence

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
- [x] Fresh OIDC login for destructive account actions with same-owner validation.
- [x] Mobile export/share and idempotent account-deletion receipt flow.
- [ ] Configure the production identity provider, client, issuer, audience and
      signed `device_id` claim in the deployment environment.
- [ ] Validate login, refresh and logout on physical Android/iOS devices.
