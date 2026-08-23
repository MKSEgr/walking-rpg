# ADR 0091: authoritative current-journey start time

- **Статус:** Accepted
- **Дата:** 2026-08-23
- **Связанная задача:** [issue #452](https://github.com/MKSEgr/walking-rpg/issues/452)

## Контекст

Backend уже хранит exact start каждого `journeyNumber` для completion duration,
но current Home snapshot не публикует его. Journal показывает decisions и их
resolution time, поэтому игрок не может отличить начало похода от времени
первого решения.

## Решение

1. Home публикует additive nullable `expedition.startedAt` из существующего
   `findJourneyStartedAt` exact текущего `journeyNumber`.
2. Backend не выводит start из `decisionLog`, content, client clock или Home
   response time.
3. Mobile проверяет ISO-8601 shape и показывает locale-aware RU/EN date/time.
4. Mobile не рассчитывает elapsed duration и не подставляет значение при
   отсутствии поля.
5. Persistence, rewards и event resolution не меняются.

## Последствия

- journal получает server-authoritative временной контекст текущего похода;
- completed recap duration и visible start используют один persisted source;
- legacy snapshots без поля сохраняют прежний UI.

## Откат

Удалить `startedAt` из Home projection, mobile model/UI, tests и documentation.
Persisted journey-start receipts и completion duration остаются без изменений.
