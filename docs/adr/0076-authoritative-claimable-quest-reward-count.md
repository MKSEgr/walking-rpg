# ADR 0076: authoritative claimable quest reward count

- **Статус:** Accepted
- **Дата:** 2026-08-22
- **Связанная задача:** [issue #422](https://github.com/MKSEgr/walking-rpg/issues/422)

## Контекст

Platform уже возвращает accepted progress, ready и claimed state каждого
задания. Карточки показывают отдельные действия, но игроку приходится вручную
искать задания с уже доступной неполученной наградой.

## Решение

1. Mobile считает claimable только accepted quests с `ready == true` и
   `claimed == false`.
2. Положительный count получает exact RU/EN singular/plural guidance; zero не
   создаёт отдельного сообщения.
3. Visible guidance объявляется одной semantics node.
4. Per-quest progress, targets, ready/claimed state, reward contents/order и
   claim action сохраняются без изменений.
5. Backend, API, persistence, quest aggregation и reward economy не меняются.

## Последствия

- готовые награды видны без просмотра каждой карточки;
- client не выводит eligibility из progress или target;
- quest completion и economy boundaries остаются server-owned.

## Откат

Удалить derived count, RU/EN presentation, tests и documentation. Wire contract
и persisted data не затрагиваются.
