# ADR 0095: authoritative current-journey READY event

- **Статус:** Accepted
- **Дата:** 2026-08-23
- **Связанная задача:** [issue #460](https://github.com/MKSEgr/walking-rpg/issues/460)

## Контекст

Journal уже показывает authoritative phase, position и ENERGY progress, но при
готовом событии игрок не видит его название. Выбор события из phase, node,
route trail, choices или последнего решения создал бы client-owned state.

## Решение

1. Journal показывает только `unlockedEvent` со status exact `READY`.
2. Known mutable title локализуется существующим catalog по stable `eventId`.
3. Unknown future event ID сохраняет literal server title.
4. Absent, `RESOLVED` и unknown status fail-closed не создают event label.
5. Phase, node, progress, route trail, choices и decision log не выбирают и не
   восстанавливают current event.
6. Одна visible RU/EN label и одна semantics node показывают тот же факт.

## Последствия

- готовое событие видно в текущем journal context;
- mutable current copy меняет locale без переписывания persisted history;
- resolved и future-status state не создают ложную готовность.

## Откат

Удалить current-event label, tests и documentation. Existing Home event,
content catalog, commands и event resolution останутся без изменений.
