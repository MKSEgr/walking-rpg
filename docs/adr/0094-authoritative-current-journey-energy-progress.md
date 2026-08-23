# ADR 0094: authoritative current-journey ENERGY progress

- **Статус:** Accepted
- **Дата:** 2026-08-23
- **Связанная задача:** [issue #458](https://github.com/MKSEgr/walking-rpg/issues/458)

## Контекст

Home уже публикует ENERGY progress и target текущего похода, но Platform
journal показывает только phase и position. Повторный вывод status, command
availability или rewards из отношения этих чисел создал бы client-owned state.

## Решение

1. Journal читает только `expedition.progress/requiredEnergy`.
2. RU/EN copy сохраняет literal accepted integers.
3. Только декоративный progress indicator ограничивается диапазоном `0..1`.
4. Phase, decision availability, completion, rewards, spendability и command
   eligibility из чисел не выводятся.
5. Одна semantics node объявляет literal progress; visual indicator исключён
   из отдельного screen-reader output.

## Последствия

- ENERGY progress виден рядом с phase, position и start time;
- accepted over-target values остаются диагностируемыми в copy;
- command и gameplay authority остаются на сервере.

## Откат

Удалить ENERGY-progress block, tests и documentation. Existing Home fields,
status, actions, persistence и commands останутся без изменений.
