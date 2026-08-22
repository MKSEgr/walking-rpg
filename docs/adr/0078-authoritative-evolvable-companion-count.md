# ADR 0078: authoritative evolvable companion count

- **Статус:** Accepted
- **Дата:** 2026-08-22
- **Связанная задача:** [issue #426](https://github.com/MKSEgr/walking-rpg/issues/426)

## Контекст

Platform уже возвращает accepted pet state с bond, evolution threshold,
current stage и maximum stage. Карточки показывают отдельные действия, но
игроку приходится вручную искать питомцев, уже готовых к эволюции.

## Решение

1. Mobile считает ready только accepted pets, для которых существующая
   domain-проекция `canEvolve` истинна.
2. Growing и fully evolved pets не входят в count.
3. Положительный count получает exact RU/EN singular/plural guidance; zero не
   создаёт отдельного сообщения.
4. Visible guidance объявляется одной semantics node.
5. Per-pet bond, thresholds, stages, actions и evolution command сохраняются
   без изменений; backend, API и persistence не меняются.

## Последствия

- доступные evolution actions видны без просмотра каждой карточки;
- mobile повторно использует существующую fail-closed domain semantics;
- companion progression boundaries остаются server-owned.

## Откат

Удалить derived count, RU/EN presentation, tests и documentation. Wire contract
и persisted data не затрагиваются.
