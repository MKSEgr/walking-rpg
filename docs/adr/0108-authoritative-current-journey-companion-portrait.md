# ADR 0108: authoritative current-journey companion portrait

- **Статус:** Accepted
- **Дата:** 2026-08-29
- **Связанная задача:** [issue #507](https://github.com/MKSEgr/walking-rpg/issues/507)

## Контекст

Current-journey journal уже показывает identity, progression и form активного
спутника из accepted Home snapshot. Existing `CompanionPortrait` умеет
визуализировать known stable pet identity и accepted evolution stage, но другие
Platform surfaces также располагают active-pet state, cosmetics и локальным
catalog context. Journal не должен получать из них более яркий, но ложный
портрет текущего спутника.

## Решение

1. Journal показывает portrait только при наличии полной accepted Home группы
   `petId/name/species/evolutionStage`; неполная optional группа скрывает его.
2. `CompanionPortrait` получает exact Home `petId` и stage. Known identity
   выбирает existing stage-aware asset, unknown future ID сохраняет existing
   code-native fallback без нового content mapping.
3. Name/species передаются через те же current-content RU/EN resolvers, что и
   соседние journal labels; future ID сохраняет literal Home fallback.
4. Portrait отмечается active только как визуализация accepted Home companion.
   Platform active pet, cosmetics, thresholds, rewards, history и forecasts не
   участвуют.
5. Внутренняя semantics design-system portrait исключается, а journal создаёт
   одну dedicated image semantics node с локализованными name/species/form и
   active state без duplicate announcement.
6. Home API, backend, persistence, commands, assets, external validation и
   immutable `alpha-rc1` не меняются.

## Последствия

- current-journey journal получает узнаваемый RPG portrait из уже принятых
  illustrated assets;
- Home identity и form остаются единственным authoritative source;
- legacy/partial snapshot не получает догадок из Platform state;
- future companion остаётся доступным через literal semantics и fallback art;
- изменение полностью обратимо на mobile presentation уровне.

## Откат

Удалить optional journal portrait, его widget coverage и этот documentation
record. Текстовые current-journey companion labels и Home contract останутся без
изменений.
