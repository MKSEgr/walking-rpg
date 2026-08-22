# ADR 0079: authoritative equippable cosmetic count

- **Статус:** Accepted
- **Дата:** 2026-08-22
- **Связанная задача:** [issue #428](https://github.com/MKSEgr/walking-rpg/issues/428)

## Контекст

Platform уже возвращает accepted cosmetic catalog, owned IDs и независимые
server-owned equipped slots. Карточки показывают отдельные действия, но игроку
приходится вручную искать принадлежащие ему образы, которые ещё не надеты.

## Решение

1. Mobile считает ready только accepted catalog cosmetics, присутствующие в
   accepted ownership и отсутствующие в accepted equipped cosmetic IDs.
2. Equipped, unowned и retired/non-catalog cosmetics не входят в count.
3. Положительный count получает exact RU/EN singular/plural guidance; zero не
   создаёт отдельного сообщения.
4. Visible guidance объявляется одной semantics node.
5. Prices, purchase availability, ownership, slot resolution и equip command
   сохраняются без изменений; backend, API и persistence не меняются.

## Последствия

- доступные equip actions видны без просмотра каждой карточки;
- mobile использует только уже accepted server-owned projections;
- cosmetic commerce и equipment boundaries остаются server-owned.

## Откат

Удалить derived count, RU/EN presentation, tests и documentation. Wire contract
и persisted data не затрагиваются.
