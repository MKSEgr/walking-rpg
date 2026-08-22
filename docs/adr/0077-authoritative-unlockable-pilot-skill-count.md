# ADR 0077: authoritative unlockable pilot skill count

- **Статус:** Accepted
- **Дата:** 2026-08-22
- **Связанная задача:** [issue #424](https://github.com/MKSEgr/walking-rpg/issues/424)

## Контекст

Platform уже возвращает accepted catalog навыков с server-authored XP-порогами,
текущий season XP и множество открытых навыков. Карточки показывают отдельные
действия, но игроку приходится вручную искать навыки, которые уже можно открыть.

## Решение

1. Mobile считает unlockable только accepted catalog skills, отсутствующие в
   accepted `unlockedSkills` и имеющие `requiredSeasonXp <= seasonXp`.
2. Положительный count получает exact RU/EN singular/plural guidance; zero не
   создаёт отдельного сообщения.
3. Visible guidance объявляется одной semantics node.
4. Per-skill thresholds, availability state, copy и unlock action сохраняются
   без изменений.
5. Backend, API, persistence, skill rules и rewards не меняются.

## Последствия

- доступные действия видны без просмотра каждой карточки;
- client не прогнозирует будущие catalog entries или новые thresholds;
- skill eligibility и progression boundaries остаются server-owned.

## Откат

Удалить derived count, RU/EN presentation, tests и documentation. Wire contract
и persisted data не затрагиваются.
