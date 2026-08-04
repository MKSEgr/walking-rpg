# ADR 0032 — Server-authoritative cosmetic slots

- Status: Accepted
- Date: 2026-08-04

## Context

The platform catalog already assigns every cosmetic to `PILOT`, `PET` or
`PROFILE`, but persistent user state exposes only one `activeCosmeticId`.
Equipping a pet cosmetic therefore replaces the compatibility pointer to a
pilot cosmetic even though the items belong to independent visual slots.

The illustrated mobile widgets can accept a set of equipped cosmetic IDs. A
client-local set would create a second source of truth, would not survive a new
device and could not resolve concurrent commands or account deletion safely.

## Decision

- Flyway V17 creates `platform_cosmetic_slot_state` with one row per
  `(user_id, slot)` and at most one row for the same cosmetic and user.
- The allowed slots are database-checked `PILOT`, `PET` and `PROFILE`; the
  request supplies only `cosmeticId`, while the server catalog owns its slot.
- `EQUIP_COSMETIC` materializes the previous legacy selection and then upserts
  only the target slot in the same user-serialized transaction as platform
  state, event and processed-command persistence.
- `userState.equippedCosmetics` is an additive `slot -> cosmeticId` projection.
  Values must still be owned and present in the current server catalog.
- `activeCosmeticId` remains the last selected compatibility pointer for old
  clients. A fresh read overlays that pointer on its catalog slot, so an old
  backend instance can participate in a rolling deployment without deleting
  independent V17 rows.
- V17 backfills the known pre-V17 active item into its catalog slot. Unknown
  legacy IDs are not guessed.
- Cosmetic slot rows are included in account export, cascade deletion and the
  synthetic backup/restore manifest.

## Consequences

Old clients continue to render one selected cosmetic and can keep sending the
unchanged command payload. New clients may treat `equippedCosmetics` as
optional during rollout and render all returned values after their separate UI
integration. Replaying a response committed before V17 remains exact and may
omit the additive field; the next platform GET returns the current projection.

No `mobile/**` code or visual asset is changed by this backend slice.

## Revisit when

- a cosmetic can occupy more than one slot;
- loadouts or saved presets are introduced;
- store entitlements require a separate ownership source;
- unequip semantics need to distinguish an empty slot from a server default.
