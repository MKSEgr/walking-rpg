# ADR 0117: authoritative current-journey READY choice requirement art

- **Статус:** Accepted
- **Дата:** 2026-08-29
- **Связанная задача:** [issue #525](https://github.com/MKSEgr/walking-rpg/issues/525)

## Контекст

Current-journey journal уже сохраняет accepted optional requirement description
каждого available READY choice. Home contract различает три canonical channels:
equipped navigation item, active companion и unlocked pilot skill. Для их
stable identities существуют `ExpeditionItemEmblem`, `CompanionPortrait` и
`ProgressionSigil`, но journal оставляет requirement только текстом.

Requirement art не должен становиться вторым eligibility engine. Choice уже
содержит accepted server-owned `availability`; повторная проверка Platform
equipment, skill или pet state может расходиться с этим snapshot. Dispatch по
name, description или знакомому item ID внутри unknown type/slot также присвоил
бы future contract ложную семантику.

## Решение

1. Art читается только для accepted available choices `unlockedEvent` со
   status exact `READY` в принятом server order.
2. Requirement channel выбирается только по exact canonical pair:
   - `UNLOCKED_SKILL + PILOT_SKILL` использует `ProgressionSigil`;
   - `EQUIPPED_ITEM + NAVIGATION` использует `ExpeditionItemEmblem`;
   - `ACTIVE_PET + ACTIVE_PET` использует `CompanionPortrait`.
3. Каждый component получает exact paired requirement `itemId`. Pet portrait
   дополнительно получает только accepted `minimumEvolutionStage`; item/slot
   names нужны constructor-у portrait, но не участвуют в visual dispatch.
4. Known reviewed IDs выбирают existing art, unknown future IDs используют
   established component fallback. Unknown, legacy и wrong-slot type pairs
   остаются text-only даже при known item ID.
5. Journal не проверяет requirement повторно и не читает для art Platform
   equipment/skills/pets, names, description, progression, route, decision
   history, catalog, event phase или соседний choice.
6. Requirement art не меняет accepted title, description, requirement, reward,
   optional material, progression signals или ordering. Choice остаётся
   read-only.
7. Art находится внутри existing event `ExcludeSemantics`; combined localized
   requirement label остаётся единственным accessibility источником без
   duplicate image announcement или action semantics.
8. Home API, backend, persistence, commands, content, assets, external
   validation и immutable `alpha-rc1` не меняются.

## Последствия

- accepted canonical requirements получили established visual identity рядом
  с literal requirement copy;
- future subject IDs остаются на component fallback, а future contract shape
  не маскируется под известный channel;
- journal не спорит с server-owned availability и не зависит от Platform
  snapshot;
- material/reward visuals, server ordering и single semantics сохраняются;
- изменение обратимо на mobile presentation уровне.

## Откат

Удалить journal requirement art, integration coverage и этот record. Existing
READY choice signal, title/description/requirement/reward copy, material and
progression visuals, Home actions и backend contract останутся без изменений.
