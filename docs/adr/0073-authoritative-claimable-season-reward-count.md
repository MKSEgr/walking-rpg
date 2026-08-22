# ADR 0073: authoritative claimable season reward count

- **Статус:** Accepted
- **Дата:** 2026-08-22
- **Связанная задача:** [issue #413](https://github.com/MKSEgr/walking-rpg/issues/413)

## Контекст

Platform уже возвращает accepted season XP, catalog-owned cadence/final level
и immutable achievement receipts. Журнал предлагал первый claimable level, но
не объяснял, сколько заработанных наград ещё не получено.

## Решение

1. Mobile определяет earned boundary по accepted XP, positive `xpPerLevel` и
   final catalog level.
2. Для каждого earned уровня exact receipt `season-reward-N` означает, что
   награда уже получена; остальные earned уровни образуют ordered unclaimed
   set.
3. Положительный count получает нейтральную RU/EN singular/plural строку.
   Zero и legacy snapshot без cadence остаются без inferred guidance.
4. Visible guidance имеет один explicit semantics container.
5. Существующая кнопка использует первый элемент того же ordered set; claim
   order, command, payload и reward contents не меняются.
6. Backend/API, persistence, cadence, economy и external gates не меняются.

## Последствия

- доступный результат понятен без ручного подсчёта;
- unrelated/future achievement IDs не искажают season count;
- кнопка и пояснение используют одну accepted projection;
- legacy claim compatibility сохраняется без выдуманной подсказки.

## Откат

Удалить derived set/count, RU/EN guidance, tests и documentation additions.
API, persisted data и migrations не затрагиваются.
