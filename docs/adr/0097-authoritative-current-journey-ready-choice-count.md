# ADR 0097: authoritative current-journey READY choice count

- **Статус:** Accepted
- **Дата:** 2026-08-23
- **Связанная задача:** [issue #464](https://github.com/MKSEgr/walking-rpg/issues/464)

## Контекст

Journal показывает authoritative title и summary готового события, но не
сообщает объём ожидающего решения. Подсчёт из topology, catalog rules или
локальной проверки requirements создал бы client-owned eligibility state.

## Решение

1. Count читается только из `unlockedEvent` со status exact `READY`.
2. Учитываются только choices с accepted `availability=AVAILABLE`.
3. Locked choices не увеличивают count; mobile не проверяет requirements.
4. Показывается только positive count. Legacy/empty, locked-only, absent,
   `RESOLVED` и unknown status не создают count.
5. Phase, node, progress, route trail, decision log, topology и catalog rules
   не выбирают и не восстанавливают choices.
6. Visible RU/EN count присоединяется к существующей event semantics node и не
   создаёт action в journal.

## Последствия

- игрок видит размер доступного решения рядом с event context;
- locked state остаётся server-owned и не превращается в mobile rule engine;
- legacy и неполное состояние не создают ложный нулевой факт.

## Откат

Удалить count, tests и documentation. Existing READY event block, Home choice
actions, backend contract, persistence и commands останутся без изменений.
