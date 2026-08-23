# ADR 0083: authoritative available expedition choice count

- **Статус:** Accepted
- **Дата:** 2026-08-23
- **Связанная задача:** [issue #436](https://github.com/MKSEgr/walking-rpg/issues/436)

## Контекст

Home уже возвращает unresolved expedition event с accepted `choices` и
`lockedChoices`. Mobile объединяет их для отображения, а существующая projection
`HomeEventChoice.isAvailable` определяет, получает ли вариант active resolve
action. При смешанном списке игроку приходится вручную отделять доступные
решения от вариантов с server-authored ограничениями.

## Решение

1. Mobile считает available только accepted event choices, для которых
   `isAvailable == true`, то есть `availability == AVAILABLE`.
2. `LOCKED` choices не входят в count.
3. Mobile не пересчитывает availability по equipment, item level, active pet,
   evolution stage, unlocked skills или другим требованиям.
4. Положительный count unresolved event получает exact RU/EN singular/plural
   guidance; zero и resolved event не создают отдельного сообщения.
5. Visible guidance объявляется одной semantics node.
6. Event topology, requirements, rewards, choice ordering и resolve command
   сохраняются без изменений; backend, Home API и persistence не меняются.

## Последствия

- игрок видит число рабочих решений до просмотра каждой choice card;
- mobile повторно использует уже принятую action projection;
- route authority и event command semantics остаются server-owned.

## Откат

Удалить derived count, RU/EN presentation, tests и documentation. Wire contract
и persisted data не затрагиваются.
