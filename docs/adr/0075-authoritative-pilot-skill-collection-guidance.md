# ADR 0075: authoritative pilot skill collection guidance

- **Статус:** Accepted
- **Дата:** 2026-08-22
- **Связанная задача:** [issue #419](https://github.com/MKSEgr/walking-rpg/issues/419)

## Контекст

Platform уже возвращает accepted skill catalog и unlocked IDs, но раздел
навыков показывал только отдельные карточки. Игроку приходилось вручную считать
общий прогресс, а unlocked set может совместимо содержать retired или будущие
non-catalog IDs.

## Решение

1. Mobile считает unlocked catalog count только как пересечение accepted
   catalog IDs и accepted unlocked IDs.
2. Exact RU/EN progress получает remaining или спокойное complete state.
3. Aggregate copy объявляется одной semantics summary; карточки сохраняют
   собственные thresholds, состояния и действия.
4. Non-catalog unlocked IDs игнорируются агрегатом, но не делают snapshot
   невалидным.
5. Backend, API, persistence, skill thresholds, unlock command и rewards не
   меняются.

## Последствия

- прогресс развития пилота понятен без ручного подсчёта;
- совместимые retired/future IDs не искажают число;
- eligibility и unlock boundaries остаются server-owned.

## Откат

Удалить derived counts, aggregate RU/EN presentation, tests и documentation.
Wire contract и persisted data не затрагиваются.
