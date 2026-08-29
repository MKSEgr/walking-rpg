# ADR 0109: authoritative current-journey pilot portrait

- **Статус:** Accepted
- **Дата:** 2026-08-29
- **Связанная задача:** [issue #509](https://github.com/MKSEgr/walking-rpg/issues/509)

## Контекст

Current-journey journal уже показывает accepted Home pilot identity и
progression, а после ADR 0108 визуально показывает активного спутника. Existing
`PilotPortrait` содержит только illustrated Navigator artwork и cosmetic scarf
variant. Platform snapshot одновременно располагает hero progression и
equipped cosmetics, но эти данные не доказывают identity пилота accepted Home
похода и не должны менять его journal portrait.

## Решение

1. Journal показывает existing `PilotPortrait` только для exact accepted Home
   `pilotId == navigator-v1`.
2. Portrait name проходит existing current-content RU/EN resolver. Literal
   server name известного ID не заменяет mutable localized copy.
3. Legacy missing ID и unknown future ID сохраняют существующий literal text
   fallback, но fail-closed не получают Navigator artwork.
4. Platform hero progression, equipped/owned cosmetics, rewards, history и
   local catalog не участвуют; journal portrait использует base asset без
   cosmetic variant.
5. Pilot и companion portraits располагаются в compact wrapping crew row, но
   сохраняют независимые authoritative inputs и semantics nodes.
6. Внутренняя `PilotPortrait` semantics исключается, а journal публикует одну
   dedicated localized image semantics node без duplicate announcement.
7. Home API, backend, persistence, commands, assets, external validation и
   immutable `alpha-rc1` не меняются.

## Последствия

- current-journey crew получает paired pilot/companion visual identity;
- известный Navigator локализуется и визуализируется одним existing asset;
- future/legacy identity не маскируется под Navigator;
- Platform cosmetic state не проникает в accepted Home projection;
- изменение полностью обратимо на mobile presentation уровне.

## Откат

Удалить optional pilot portrait, вернуть companion portrait в одиночный layout,
удалить widget coverage и этот record. Текстовые pilot identity/progression и
Home contract останутся без изменений.
