# ADR 0111: authoritative current-journey node landmark

- **Статус:** Accepted
- **Дата:** 2026-08-29
- **Связанная задача:** [issue #513](https://github.com/MKSEgr/walking-rpg/issues/513)

## Контекст

Current-journey journal уже показывает accepted Home current-position text и
ordered route trail. Home screen одновременно использует existing code-native
`ExpeditionNodeSignal`, который выбирает landmark по exact stable node ID и
имеет neutral future fallback. Route Journal пока не использует этот visual,
хотя соседние Platform content, route terminal, READY event и history могут
содержать другие node-like facts и не должны подменять accepted current point.

Existing current-position label уже публикует dedicated semantics node. Если
добавить landmark как независимый accessible child, screen reader дважды
объявит одну точку разной формулировкой.

## Решение

1. Journal строит `ExpeditionNodeSignal` только из accepted Home
   `currentNodeId/currentNode`.
2. Known mutable name проходит existing RU/EN stable-ID resolver. Unknown
   future ID сохраняет literal Home name.
3. Только exact known ID выбирает known code-native landmark. Display name не
   участвует в выборе art; unknown ID получает existing neutral fallback.
4. `completed` передаётся только при exact accepted
   `expedition.status == COMPLETED`.
5. Route terminal/state, decision log, READY event, Platform progression,
   history и local catalog не подменяют node identity или completed styling.
6. Landmark и visible position text находятся внутри existing
   current-position `ExcludeSemantics`; прежняя outer semantics node остаётся
   единственным accessibility announcement.
7. Home API, backend, persistence, commands, rewards, assets, external
   validation и immutable `alpha-rc1` не меняются.

## Последствия

- текущая точка получает существующую визуальную identity без нового asset;
- RU/EN known content остаётся актуальным, future content — literal и neutral;
- route/Platform decoys не влияют на landmark;
- accessibility не получает duplicate announcement;
- изменение полностью обратимо на mobile presentation уровне.

## Откат

Удалить nested landmark, integration coverage и этот record. Existing
current-position label/semantics, route map и accepted Home contract останутся
без изменений.
