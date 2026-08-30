# ADR 0119: authoritative saved journey decision reward art

- **Статус:** Accepted
- **Дата:** 2026-08-30
- **Связанная задача:** [issue #529](https://github.com/MKSEgr/walking-rpg/issues/529)

## Контекст

Current `decisionLog` и expanded recent archive history уже показывают literal
persisted reward facts. Companion bond и material reward при этом остаются
generic icon chips, хотя entry переносит exact `petId`, а material — exact
`itemId`, для которых существуют reviewed `ProgressionGainSignal` и
`ExpeditionItemEmblem`.

History нельзя обогащать из current Home или Platform state. Текущий pilot,
active pet, READY preview, route или catalog могут относиться к другому
snapshot. Особенно важно, что pilot XP в decision entry не содержит pilot ID:
current pilot не может безопасно стать historical recipient.

## Решение

1. Shared renderer current и expanded recent decision entries показывает
   companion-bond signal только при positive `petBondGained` и exact non-empty
   persisted `entry.petId` той же записи.
2. Material emblem показывается только при persisted `materialReward` и exact
   non-empty `materialReward.itemId`.
3. Known reviewed subject/item ID выбирает established component art;
   unknown/future ID использует neutral fallback самого component.
4. Missing/empty companion ID оставляет generic heart chip. Pilot XP всегда
   остаётся generic star chip, потому что `decisionLog` не переносит pilot ID.
5. Dispatch не читает names, amounts, current Home pilot/pet, READY preview,
   Platform, route, progression totals, catalog или соседние decisions.
6. Literal reward names, amounts, ordering и combined decision semantics
   остаются authoritative. Art декоративен и остаётся внутри existing entry
   `ExcludeSemantics`; новых actions или image announcements нет.
7. Home API, backend, persistence, commands, content, assets, external
   validation и immutable `alpha-rc1` не меняются.

## Последствия

- immutable companion/material rewards получили reviewed visual identity из
  собственных persisted IDs;
- future rewards остаются neutral, а missing identity не маскируется current
  state;
- pilot XP честно остаётся generic до появления persisted subject identity;
- current и recent history сохраняют один renderer, literal copy и semantics;
- изменение обратимо на mobile presentation уровне.

## Откат

Удалить persisted reward avatars из shared decision chip, integration coverage
и этот record. Existing choice signal, literal journal history, Home contract,
commands и backend останутся без изменений.
