# ADR 0093: authoritative current-journey position

- **Статус:** Accepted
- **Дата:** 2026-08-23
- **Связанная задача:** [issue #456](https://github.com/MKSEgr/walking-rpg/issues/456)

## Контекст

Home уже публикует current node identity и copy, но journal требует искать
position на route trail. Выбор последнего trail element или decision на mobile
мог бы расходиться с accepted current node при новых server states.

## Решение

1. Journal читает только `currentNodeId/currentNode` из Home snapshot.
2. Known mutable node copy локализуется существующим stable-ID catalog.
3. Unknown future node ID сохраняет literal server fallback.
4. Route trail, decision log, phase и unlocked event не выбирают position.
5. Одна visible RU/EN label и одна semantics node показывают тот же факт.

## Последствия

- current position видна рядом с phase и start time;
- localization не определяет identity по display text;
- future content остаётся читаемым без client topology inference.

## Откат

Удалить current-position label, tests и documentation. Existing Home fields,
stable-ID catalog, route trail и commands останутся без изменений.
