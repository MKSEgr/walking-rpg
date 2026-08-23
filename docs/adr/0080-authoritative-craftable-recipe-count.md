# ADR 0080: authoritative craftable recipe count

- **Статус:** Accepted
- **Дата:** 2026-08-22
- **Связанная задача:** [issue #430](https://github.com/MKSEgr/walking-rpg/issues/430)

## Контекст

Home уже возвращает accepted crafting recipes с server-authored статусами
`READY`, `MISSING_MATERIALS` и `CRAFTED`. Карточки показывают отдельные
действия, но игроку приходится вручную искать рецепты, готовые к созданию.

## Решение

1. Mobile считает ready только accepted recipes с `status == READY`, повторно
   используя существующую domain-проекцию `canCraft`.
2. `MISSING_MATERIALS` и `CRAFTED` не входят в count.
3. Mobile не пересчитывает availability по ingredient quantities.
4. Положительный count получает exact RU/EN singular/plural guidance; zero не
   создаёт отдельного сообщения.
5. Visible guidance объявляется одной semantics node.
6. Recipes, material costs, rewards и craft command сохраняются без изменений;
   backend, Home API и persistence не меняются.

## Последствия

- доступные craft actions видны без просмотра каждого рецепта;
- mobile сохраняет server-authored availability boundary;
- crafting economy и command semantics остаются server-owned.

## Откат

Удалить derived count, RU/EN presentation, tests и documentation. Wire contract
и persisted data не затрагиваются.
