# ADR 0074: authoritative cosmetic collection guidance

- **Статус:** Accepted
- **Дата:** 2026-08-22
- **Связанная задача:** [issue #415](https://github.com/MKSEgr/walking-rpg/issues/415)

## Контекст

Platform уже возвращает accepted cosmetic catalog и owned IDs, но раздел
косметики показывал только отдельные карточки. Игроку приходилось вручную
считать общий прогресс коллекции, а owned set может совместимо содержать
retired или будущие non-catalog IDs.

## Решение

1. Mobile считает owned catalog count только как пересечение accepted catalog
   IDs и accepted owned IDs.
2. Exact RU/EN progress получает remaining или спокойное complete state.
3. Aggregate copy объявляется одной semantics summary; карточки сохраняют
   собственные действия и состояния.
4. Non-catalog owned IDs игнорируются агрегатом, но не делают snapshot
   невалидным.
5. Backend, API, persistence, prices, purchase/equip commands и ownership
   rules не меняются.

## Последствия

- прогресс коллекции понятен без ручного подсчёта;
- совместимые retired/future IDs не искажают число;
- commerce и equipment boundaries остаются server-owned.

## Откат

Удалить derived counts, aggregate RU/EN presentation, tests и documentation.
Wire contract и persisted data не затрагиваются.
