# ADR 0082: authoritative equippable inventory item count

- **Статус:** Accepted
- **Дата:** 2026-08-23
- **Связанная задача:** [issue #434](https://github.com/MKSEgr/walking-rpg/issues/434)

## Контекст

Home уже возвращает accepted inventory items с nullable `itemInstanceId`,
`equippableSlotId` и `equippedSlotId`. Существующая mobile projection
`isEquippable` определяет, появляется ли equip action, а `isEquipped` — активно
ли оно. При смешанном инвентаре игроку приходится вручную искать доступные
действия среди материалов и уже экипированных предметов.

## Решение

1. Mobile считает ready только accepted inventory items, для которых
   `isEquippable == true` и `isEquipped == false`.
2. Materials/non-equippable и equipped items не входят в count.
3. Mobile не пересчитывает availability по equipment slot state, kind, rarity,
   level или собственным ownership rules.
4. Положительный count получает exact RU/EN singular/plural guidance; zero не
   создаёт отдельного сообщения.
5. Visible guidance объявляется одной semantics node.
6. Equipment slots, route requirements и equip command сохраняются без
   изменений; backend, Home API и persistence не меняются.

## Последствия

- доступные equip actions видны без просмотра каждой inventory entry;
- mobile повторно использует уже принятую action projection;
- equipment authority и command semantics остаются server-owned.

## Откат

Удалить derived count, RU/EN presentation, tests и documentation. Wire contract
и persisted data не затрагиваются.
