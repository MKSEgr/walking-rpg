# ADR 0062: authoritative weekly rhythm window range

- **Статус:** Accepted
- **Дата:** 2026-08-21
- **Связанная задача:** [issue #391](https://github.com/MKSEgr/walking-rpg/issues/391)

## Контекст

Trail из ADR 0059 авторитетно задаёт семь последовательных local dates, а ADR
0061 делает endpoint сегодняшним днём. Однако видимые markers называют только
weekday, поэтому игроку приходится самостоятельно восстанавливать exact lower
и upper dates rolling window. Device clock для этого использовать нельзя: он
может расходиться с уже принятым Home `localDate` и server-owned timezone.

## Решение

1. Mobile показывает range только при наличии уже валидированного полного
   `weeklyActivityRhythm.days`.
2. Lower и upper boundaries берутся буквально из `days.first.date` и
   `days.last.date`; новое window или future date не вычисляются.
3. Обе даты форматируются через Material locale и выводятся одной RU/EN line.
4. Range включается в единую weekly semantics summary ровно один раз, а
   visual child исключается из повторного объявления.
5. Legacy weekly object без trail не получает inferred range. Client clock,
   Health history, notifications, streak и economy не используются.

## Последствия

- игрок видит точные календарные границы уже принятого rolling window;
- lower boundary не подаётся как дедлайн, потеря или будущий reset;
- Home API, backend и persistence schema не меняются;
- compact layout получает одну короткую fluid line перед today status.

## Откат

Удалить range copy, localization, tests и documentation additions. API,
persisted data и migration rollback не затрагиваются.
