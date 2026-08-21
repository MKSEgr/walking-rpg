# ADR 0060: gentle weekly rhythm guidance

- **Статус:** Accepted
- **Дата:** 2026-08-21
- **Связанная задача:** [issue #387](https://github.com/MKSEgr/walking-rpg/issues/387)

## Контекст

Мягкий недельный ритм из ADR 0058 и authoritative day trail из ADR 0059
показывают фактический count, цель 4/7 и форму недели, но до достижения цели
detail сообщает только размер rolling window. Игроку приходится самому
вычитать count из target. Давящая streak-формулировка или дедлайн противоречили
бы product canon, а новое backend-поле дублировало бы уже валидированные числа.

## Решение

1. Mobile вычисляет presentation-only остаток как
   `max(targetActiveDays - activeDays, 0)` после существующей fail-closed
   проверки weekly object.
2. Пока `targetReached=false`, detail называет оставшееся число активных дней и
   повторяет, что отдых не сбрасывает прогресс. RU/EN используют locale-aware
   singular/plural формы.
3. При `targetReached=true` сохраняется существующая success/rest-normal copy;
   нулевой remaining prompt не отображается.
4. Guidance входит в одну semantics summary вместе с headline и day trail, а
   visual children остаются исключены из повторных screen-reader announcements.
5. Mobile не читает Health history, не использует client clock и не создаёт
   streak, penalty, ENERGY, reward, notification или новый persisted state.

## Последствия

- игрок получает ближайший понятный ориентир без ручного вычитания;
- Home API и server-authoritative граница остаются неизменными;
- изменение цели или фактического count автоматически меняет guidance после
  приёма валидного snapshot;
- legacy snapshot без weekly object сохраняет прежний UI.

## Откат

Вернуть generic window copy до достижения цели и удалить localization/tests.
API, persistence schema и migration rollback не затрагиваются.
