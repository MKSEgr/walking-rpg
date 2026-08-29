# ADR 0110: authoritative current-journey route trail

- **Статус:** Accepted
- **Дата:** 2026-08-29
- **Связанная задача:** [issue #511](https://github.com/MKSEgr/walking-rpg/issues/511)

## Контекст

Home уже получает ordered `routeTrail` текущего похода и показывает его через
existing code-native `ExpeditionRouteTrail`. Route Journal показывает accepted
current-journey decisions и основные факты, но без самой карты игрок не видит
порядок уже открытых точек в journal context. Platform одновременно содержит
weekly route, history и local content, а Home располагает соседними
`decisionLog`, READY event и current-node fields; эти данные нельзя использовать
для восстановления или расширения accepted trail.

Route annotation содержит stable `choiceId` и persisted
`choiceTitle/outcomeTitle`, но не содержит `eventId` или stable outcome identity.
Поэтому current-content localization решения была бы неоднозначным join и могла
бы переписать исторически принятый текст.

## Решение

1. Current-journey journal показывает existing `ExpeditionRouteTrail` только
   для non-empty accepted Home `routeTrail`.
2. Mobile сохраняет server order, literal `VISITED/CURRENT/COMPLETED` state и
   optional decision pairing без вычисления topology, branches или progress.
3. Known mutable node name локализуется через existing stable `nodeId` resolver;
   unknown future ID сохраняет literal Home `nodeName`.
4. Persisted decision `choiceTitle/outcomeTitle` остаётся literal. Journal не
   соединяет route annotation с `decisionLog`, READY event или local content.
5. Platform weekly route, history, progression и catalog не подменяют и не
   расширяют Home trail.
6. Empty/legacy trail fail-closed не показывает map, heading или count.
7. Accepted discovered-node count видим, но исключён из semantics вместе с
   heading. Existing route widget публикует одну localized semantics summary с
   accepted order, terminal point и decisions.
8. Home API, backend, persistence, commands, rewards, assets, external
   validation и immutable `alpha-rc1` не меняются.

## Последствия

- journal получает читаемую карту текущего пути без нового transport contract;
- RU/EN mutable node names остаются актуальными, future content — literal;
- persisted decisions не переписываются и не зависят от соседних массивов;
- горизонтальный existing map сохраняет compact large-text layout;
- изменение полностью обратимо на mobile presentation уровне.

## Откат

Удалить journal route projection, integration coverage и этот record. Home map,
accepted snapshot, decision journal и server contracts останутся без изменений.
