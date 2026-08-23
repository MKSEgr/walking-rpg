# ADR 0081: authoritative ready item upgrade count

- **Статус:** Accepted
- **Дата:** 2026-08-23
- **Связанная задача:** [issue #432](https://github.com/MKSEgr/walking-rpg/issues/432)

## Контекст

Home уже возвращает accepted item upgrades с server-authored статусами
`LOCKED`, `MISSING_MATERIALS`, `READY` и `COMPLETED`. Карточки показывают
отдельные действия, но игроку приходится вручную искать улучшения, готовые к
применению.

## Решение

1. Mobile считает ready только accepted upgrades с `status == READY`, повторно
   используя существующую domain-проекцию `canApply`.
2. `LOCKED`, `MISSING_MATERIALS` и `COMPLETED` не входят в count.
3. Mobile не пересчитывает availability по наличию item, level, rarity или
   ingredient quantities.
4. Положительный count получает exact RU/EN singular/plural guidance; zero не
   создаёт отдельного сообщения.
5. Visible guidance объявляется одной semantics node.
6. Upgrades, material costs, resulting level/rarity и apply command
   сохраняются без изменений; backend, Home API и persistence не меняются.

## Последствия

- доступные apply actions видны без просмотра каждого улучшения;
- mobile сохраняет server-authored availability boundary;
- upgrade economy и command semantics остаются server-owned.

## Откат

Удалить derived count, RU/EN presentation, tests и documentation. Wire contract
и persisted data не затрагиваются.
