# ADR 0085: authoritative discovered route node count

- **Статус:** Accepted
- **Дата:** 2026-08-23
- **Связанная задача:** [issue #440](https://github.com/MKSEgr/walking-rpg/issues/440)

## Контекст

Home уже возвращает accepted `routeTrail` только для текущего похода и
показывает его code-native картой. Accessibility summary сообщает число
открытых узлов, но sighted игроку приходится считать видимые точки вручную.

## Решение

1. Mobile считает открытыми ровно элементы accepted `routeTrail`.
2. Count показывается только вместе с непустой секцией текущего trail.
3. Mobile не выводит future topology, total узлов, процент, следующий узел и
   не пересчитывает route state из content, node ID или decision log.
4. Видимая RU/EN строка исключается из semantics: существующий route summary
   остаётся единственным объявлением count и дополнительно называет последнюю
   принятую точку.
5. Home API, backend, persistence, ordering и literal node states не меняются.

## Последствия

- длина уже принятого следа одинаково доступна sighted игрокам и скринридеру;
- legacy/empty snapshots не получают ложный progress;
- будущая структура маршрута остаётся скрытой.

## Откат

Удалить derived count, RU/EN presentation, tests и documentation. Wire contract
и persisted data не затрагиваются.
