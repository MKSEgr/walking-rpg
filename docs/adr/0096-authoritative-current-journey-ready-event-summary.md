# ADR 0096: authoritative current-journey READY event summary

- **Статус:** Accepted
- **Дата:** 2026-08-23
- **Связанная задача:** [issue #462](https://github.com/MKSEgr/walking-rpg/issues/462)

## Контекст

Journal показывает authoritative title готового события, но не переносит его
описание. Восстановление summary из phase, node, route trail, choices или
decision log создало бы client-owned narrative state.

## Решение

1. Journal читает summary только из `unlockedEvent` со status exact `READY`.
2. Known mutable summary локализуется существующим catalog по stable `eventId`.
3. Unknown future event ID сохраняет literal server summary.
4. Absent, `RESOLVED` и unknown status fail-closed не создают event block.
5. Phase, node, progress, route trail, choices и decision log не выбирают и не
   восстанавливают summary.
6. Visible RU/EN title и summary принадлежат одной semantics node.

## Последствия

- контекст ожидающего решения виден рядом с authoritative event title;
- mutable current copy меняет locale без переписывания persisted history;
- summary не создаёт ложную готовность и не меняет command boundary.

## Откат

Удалить current-event summary, tests и documentation. Existing title, Home
event, content catalog, commands и event resolution останутся без изменений.
