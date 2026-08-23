# ADR 0084: authoritative equipped slot progress

- **Статус:** Accepted
- **Дата:** 2026-08-23
- **Связанная задача:** [issue #438](https://github.com/MKSEgr/walking-rpg/issues/438)

## Контекст

Home уже возвращает accepted equipment slot list с server-authored `status` и
согласованным item payload. Карточка показывает каждый слот отдельно, поэтому
для будущего multi-slot loadout игроку приходится вручную собирать общее
состояние комплекта.

## Решение

1. Mobile считает equipped только accepted equipment slots, для которых
   существующая projection `isEquipped == true`, то есть
   `status == EQUIPPED`.
2. Total равен длине accepted equipment list.
3. Mobile не пересчитывает occupancy по inventory, item kind, compatibility,
   route requirements или собственным ownership rules.
4. Каждый non-empty equipment list получает exact RU/EN `equipped / total`
   guidance, включая zero-equipped state.
5. Visible guidance объявляется одной semantics node.
6. Equipment slot catalog, compatibility, route requirements и equipment
   command сохраняются без изменений; backend, Home API и persistence не
   меняются.

## Последствия

- состояние accepted loadout видно до просмотра каждой slot card;
- zero-equipped state остаётся явным и не обещает наличие совместимого item;
- equipment authority и command semantics остаются server-owned.

## Откат

Удалить derived count, RU/EN presentation, tests и documentation. Wire contract
и persisted data не затрагиваются.
