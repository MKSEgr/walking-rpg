# ADR 0069: authoritative quest remaining guidance

- **Статус:** Accepted
- **Дата:** 2026-08-21
- **Связанная задача:** [issue #405](https://github.com/MKSEgr/walking-rpg/issues/405)

## Контекст

Platform уже возвращает accepted `progress`, server-authored `target`, metric,
ready и claimed для каждого задания. Карточка показывала только дробь, поэтому
для незавершённого шагового или событийного задания игроку приходилось самому
вычислять остаток.

## Решение

1. Mobile вычисляет только non-negative разность `target - progress` внутри
   принятой модели задания.
2. Incomplete `TOTAL_ACCEPTED_STEPS` и `RESOLVED_EVENTS` получают короткую
   exact RU/EN строку с единицей, выбранной только по exact server metric.
3. Existing progress semantics дополняется той же строкой, а visual children
   исключены из semantics, поэтому значение объявляется ровно один раз.
4. Ready и claimed состояния не получают remaining и сохраняют badges,
   reward copy и claim action.
5. `SQUAD_MEMBERSHIP` и неизвестные будущие метрики сохраняют literal
   progress fallback: mobile не придумывает для них единицу или правило.
6. Backend, Platform API/schema, catalog, persistence, targets, aggregation,
   rewards, claim command и economy не меняются.

## Последствия

- близость выполнения понятна без ручного вычитания;
- plural forms корректны в RU/EN и остаются короткими на compact large text;
- assistive technologies слышат current, target и remaining одной summary;
- новые метрики не получают ошибочную client-owned интерпретацию;
- server-owned состояние готовности и получения остаётся неизменным.

## Откат

Удалить derived remaining getter, metric-specific RU/EN guidance, coverage и
documentation additions. API, persisted data и migrations не затрагиваются.
