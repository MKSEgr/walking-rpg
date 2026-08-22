# ADR 0075: authoritative skill collection guidance

- **Статус:** Accepted
- **Дата:** 2026-08-22
- **Связанная задача:** [issue #419](https://github.com/MKSEgr/walking-rpg/issues/419)

## Контекст

Platform уже возвращает accepted skill catalog и unlocked IDs. Раздел навыков
показывал порог и состояние каждой карточки, но не общий прогресс коллекции.
Unlocked set может совместимо содержать retired или будущие non-catalog IDs.

## Решение

1. Mobile считает unlocked catalog count только как пересечение accepted
   catalog IDs и accepted unlocked IDs.
2. Exact RU/EN progress получает remaining или спокойное complete state.
3. Aggregate copy объявляется одной semantics summary; карточки сохраняют
   собственные пороги, действия и состояния.
4. Non-catalog unlocked IDs игнорируются агрегатом, но не делают snapshot
   невалидным.
5. Backend, API, persistence, thresholds, unlock command и rewards не меняются.

## Последствия

- прогресс навыков понятен без ручного подсчёта;
- совместимые retired/future IDs не искажают число;
- unlock rules остаются server-owned.

## Откат

Удалить derived counts, aggregate RU/EN presentation, tests и documentation.
Wire contract и persisted data не затрагиваются.
