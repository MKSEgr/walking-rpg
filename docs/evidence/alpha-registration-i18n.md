# Alpha registration i18n evidence

## Решение

- Product Owner: `@MKSEgr`.
- Decision date: `2026-08-08`.
- Product name in the entry flow: **Step Beyond / «Шаг за пределы»**.
- Initial geography: Russia.
- Supported alpha entry locales: `ru`, `en`; Russian is presented first.
- The choice is explicit. The app does not infer it from system locale,
  identity, health, location or authentication data.

## Граница хранения

`AppLocaleController` persists exactly `ru` or `en` in platform secure storage
under `step_beyond_locale_v1`. The preference is device-scoped and intentionally
outside:

- the OIDC token/session envelope;
- the owner marker and session generation;
- owner-scoped read cache and durable command outbox;
- backend requests and server-authoritative gameplay state.

Therefore the locale is available before registration, survives process restart,
logout and owner change, and cannot weaken owner isolation. Changing the locale
only rebuilds presentation resources; command IDs, idempotency keys, content IDs,
auth handoff and server reads remain unchanged.

## Migration and fallback

| Stored value | Effective locale | Explicit gate |
|---|---:|---:|
| `ru` | Russian | no |
| `en` | English | no |
| missing | Russian | yes |
| unknown, blank or unreadable | Russian | yes |

The migration is reversible through language actions on auth, first journey and
account entry points. A failed write does not publish an uncommitted in-memory
locale.

## Audited mandatory-flow inventory

The source-of-truth inventory is the equal key set in:

- `mobile/lib/l10n/app_ru.arb`;
- `mobile/lib/l10n/app_en.arb`.

It covers:

1. initial language choice, persistence errors and the reversible picker;
2. configuration, session restore, sign-in and reauthentication presentation;
3. first-journey loading, cached/error states and recovery actions;
4. welcome, step permission/sync, reward, pet selection, first expedition,
   first event, result handoff and completed states;
5. accessibility semantics for route, step intake, companion portrait, chapter,
   node and event artwork;
6. presentation-only translations for stable starter IDs (`spark-v1`,
   `moss-v1`, `rune-v1`, `outer-beacon`, `lumen-gate`, `signal-source-v1`,
   `analyze-signal`, `trust-companion`).

Unknown server-owned content deliberately falls back to its literal server value
instead of deriving a translation from display text. That preserves forward
compatibility and the server authority boundary.

## Automated evidence

- `app_locale_controller_test.dart`: missing/invalid/read-failure fallback,
  explicit persistence, restart restore, reversal and failed-write behavior;
- `localization_resource_test.dart`: exact RU/EN key parity, non-empty values
  and placeholder presence;
- `app_locale_choice_screen_test.dart`: Russian-first order, explicit English
  choice, compact enlarged-text layout and reversible picker;
- `mandatory_localization_widget_test.dart`: Russian and English auth entry plus
  every mandatory first-journey panel, including reward and event-result states,
  at a compact viewport with enlarged text;
- existing auth/onboarding/widget suites remain regression coverage for the
  Russian migration default.

Physical-device captures for both locales remain separate evidence under
`#149`/`#21`. Whole-app/store localization and production rollout remain out of
scope for this alpha-flow change.
